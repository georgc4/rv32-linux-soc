`timescale 1ns/1ps
// Full-image experiment: real ROM, bridge, and quad-lane SPI transfers to all chips.
module linux_serial_boot_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    wire uart_tx, spi_sck, initialized, halted, fault;
    wire [31:0] fault_pc;
    wire [4:0] cs_n;
    wire [5:0] dq_in, dq_out, dq_oe;
    wire [3:0] model_out [0:4], model_oe [0:4];
    wire [5:0] model_bus;
    wire [3:0] ram_model_bus =
        (model_out[0] & model_oe[0]) | (model_out[1] & model_oe[1]) |
        (model_out[2] & model_oe[2]) | (model_out[3] & model_oe[3]);
    wire [3:0] flash_model_bus = model_out[4] & model_oe[4];
    longint unsigned cycles = 0;
    longint unsigned machine_timer_traps = 0;
    longint unsigned supervisor_timer_traps = 0;
    longint unsigned sbi_ecalls = 0;
    longint unsigned cycle_limit = 64'd20000000000;
    longint unsigned next_report = 64'd10000000;
    string uart_line = "";
    reg [7:0] uart_byte;
    integer flash_byte;

    soc_top #(.DIAGNOSTIC_MODE(0)) dut (
        .clk(clk), .rst_n(rst_n), .uart_rx(1'b1), .uart_tx(uart_tx),
        .spi_sck(spi_sck), .spi_cs_n(cs_n),
        .spi_dq_in(dq_in), .spi_dq_out(dq_out), .spi_dq_oe(dq_oe),
        .memory_initialized(initialized), .cpu_halted(halted),
        .cpu_fault(fault), .cpu_fault_pc(fault_pc)
    );
    assign model_bus = {flash_model_bus[3:2], ram_model_bus[3:2],
                        ram_model_bus[1:0] | flash_model_bus[1:0]};
    assign dq_in = (dq_out & dq_oe) | model_bus;
    genvar g;
    generate for (g = 0; g < 5; g = g + 1) begin: chips
        serial_spi_model #(.MEM_BYTES(g == 4 ? 16777216 : 8388608),
                           .IS_FLASH(g == 4)) model (
            .cs_n(cs_n[g]), .sck(spi_sck),
            .io_in(g == 4 ? {dq_out[5:4], dq_out[1:0]} : dq_out[3:0]),
            .io_out(model_out[g]), .io_oe(model_oe[g]),
            .command_count()
        );
    end endgenerate

    initial begin
        #1;
        for (flash_byte = 0; flash_byte < 16777216; flash_byte = flash_byte + 1)
            chips[4].model.memory[flash_byte] = 8'hff;
        $readmemh("build/linux/flash.serial.hex", chips[4].model.memory);
        if ($value$plusargs("max_cycles=%d", cycle_limit)) begin end
        repeat (3) @(negedge clk);
        rst_n = 1;
    end

    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (dut.cpu.trap_commit) begin
            if (dut.cpu.trap_interrupt && dut.cpu.trap_cause == 7)
                machine_timer_traps <= machine_timer_traps + 1;
            if (dut.cpu.trap_interrupt && dut.cpu.trap_cause == 5)
                supervisor_timer_traps <= supervisor_timer_traps + 1;
            if (!dut.cpu.trap_interrupt && dut.cpu.trap_cause == 9)
                sbi_ecalls <= sbi_ecalls + 1;
        end
        if (dut.sv[2] && dut.sr[2] && dut.vw && dut.va[4:2] == 0 &&
            dut.vs[0] && !dut.uart.dlab) begin
            uart_byte = dut.vd[7:0];
            if (uart_byte == 8'h0a) begin
                $display("UART %0d: %s", cycles, uart_line);
                $fflush;
                if (uart_line.len() >= 12 &&
                    uart_line.substr(0, 11) == "Kernel panic")
                    $fatal(1, "Linux kernel panic after %0d cycles", cycles);
                if (uart_line == "RV32 Linux userspace ready") begin
                    $display("PASS full Linux boot through serial ROM/NOR/PSRAM in %0d cycles", cycles);
                    $finish;
                end
                uart_line = "";
            end else if (uart_byte != 8'h0d) begin
                uart_line = {uart_line, uart_byte};
            end
        end
        if (cycles == next_report) begin
            $display("PROGRESS cycles=%0d pc=%h priv=%d satp=%h mtimer=%0d stimer=%0d sbi=%0d ram_dest=%h uart_tail=%s", cycles,
                     dut.cpu.pc, dut.current_privilege, dut.current_satp,
                     machine_timer_traps, supervisor_timer_traps, sbi_ecalls,
                     dut.cpu.regs[14], uart_line);
            $fflush;
            next_report = next_report + 64'd10000000;
        end
        if (fault || halted) $fatal(1, "CPU fault/halt at cycle %0d pc=%h", cycles, fault_pc);
        if (cycles >= cycle_limit)
            $fatal(1, "boot timeout after %0d cycles pc=%h priv=%d satp=%h", cycles,
                   dut.cpu.pc, dut.current_privilege, dut.current_satp);
    end
endmodule
