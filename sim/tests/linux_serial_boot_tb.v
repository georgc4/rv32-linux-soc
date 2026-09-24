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
    wire [31:0] spi_commands [0:4];
    wire [5:0] model_bus;
    wire [3:0] ram_model_bus =
        (model_out[0] & model_oe[0]) | (model_out[1] & model_oe[1]) |
        (model_out[2] & model_oe[2]) | (model_out[3] & model_oe[3]);
    wire [3:0] flash_model_bus = model_out[4] & model_oe[4];
    longint unsigned cycles = 0;
    longint unsigned machine_timer_traps = 0;
    longint unsigned supervisor_timer_traps = 0;
    longint unsigned sbi_ecalls = 0;
    longint unsigned retired_instructions = 0;
    longint unsigned last_retired_report = 0;
    longint unsigned ram_requests = 0;
    longint unsigned flash_requests = 0;
    longint unsigned page_faults = 0;
    longint unsigned other_sync_traps = 0;
    longint unsigned cycle_limit = 64'd20000000000;
    longint unsigned next_report = 64'd10000000;
    longint unsigned report_step = 64'd10333333;
    longint unsigned watch_after = 0;
    reg [31:0] watch_pc_lo = 0, watch_pc_hi = 0, last_watch_ra = 0;
    reg last_watch_valid = 0;
    reg [31:0] watch_seen_ra [0:63];
    reg watch_ra_seen;
    integer watch_index;
    integer watch_lines = 0;
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
            .command_count(spi_commands[g])
        );
    end endgenerate

    initial begin
        #1;
        for (flash_byte = 0; flash_byte < 16777216; flash_byte = flash_byte + 1)
            chips[4].model.memory[flash_byte] = 8'hff;
        $readmemh("build/linux/flash.serial.hex", chips[4].model.memory);
        if ($value$plusargs("max_cycles=%d", cycle_limit)) begin end
        if ($value$plusargs("report_first=%d", next_report)) begin end
        if ($value$plusargs("report_step=%d", report_step)) begin end
        if ($value$plusargs("watch_pc_lo=%h", watch_pc_lo)) begin end
        if ($value$plusargs("watch_pc_hi=%h", watch_pc_hi)) begin end
        if ($value$plusargs("watch_after=%d", watch_after)) begin end
        if (report_step == 0 || next_report == 0)
            $fatal(1, "report interval and first report must be positive");
        repeat (3) @(negedge clk);
        rst_n = 1;
    end

    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (dut.retire_valid) retired_instructions <= retired_instructions + 1;
        if (dut.sv[0] && dut.sr[0]) ram_requests <= ram_requests + 1;
        if (dut.sv[1] && dut.sr[1]) flash_requests <= flash_requests + 1;
        if (dut.cpu.trap_commit) begin
            if (dut.cpu.trap_interrupt && dut.cpu.trap_cause == 7)
                machine_timer_traps <= machine_timer_traps + 1;
            if (dut.cpu.trap_interrupt && dut.cpu.trap_cause == 5)
                supervisor_timer_traps <= supervisor_timer_traps + 1;
            if (!dut.cpu.trap_interrupt && dut.cpu.trap_cause == 9)
                sbi_ecalls <= sbi_ecalls + 1;
            if (!dut.cpu.trap_interrupt &&
                (dut.cpu.trap_cause == 12 || dut.cpu.trap_cause == 13 ||
                 dut.cpu.trap_cause == 15))
                page_faults <= page_faults + 1;
            if (!dut.cpu.trap_interrupt && dut.cpu.trap_cause != 9 &&
                dut.cpu.trap_cause != 12 && dut.cpu.trap_cause != 13 &&
                dut.cpu.trap_cause != 15)
                other_sync_traps <= other_sync_traps + 1;
        end
        if (watch_pc_hi > watch_pc_lo && cycles >= watch_after &&
            dut.cpu.pc >= watch_pc_lo && dut.cpu.pc < watch_pc_hi &&
            (!last_watch_valid || dut.cpu.regs[1] != last_watch_ra)) begin
            last_watch_ra = dut.cpu.regs[1];
            last_watch_valid = 1;
            watch_ra_seen = 0;
            for (watch_index = 0; watch_index < watch_lines; watch_index = watch_index + 1)
                if (watch_seen_ra[watch_index] == dut.cpu.regs[1])
                    watch_ra_seen = 1;
            if (!watch_ra_seen && watch_lines < 64) begin
                watch_seen_ra[watch_lines] = dut.cpu.regs[1];
                $display("WATCH cycles=%0d pc=%h ra=%h sp=%h tp=%h a0=%h a1=%h a2=%h a3=%h sepc=%h scause=%h state=%0d", cycles,
                         dut.cpu.pc, dut.cpu.regs[1], dut.cpu.regs[2],
                         dut.cpu.regs[4], dut.cpu.regs[10], dut.cpu.regs[11],
                         dut.cpu.regs[12], dut.cpu.regs[13],
                         dut.cpu.priv_unit.sepc, dut.cpu.priv_unit.scause,
                         dut.cpu.state);
                $fflush;
                watch_lines = watch_lines + 1;
            end
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
            $display("PROGRESS cycles=%0d pc=%h priv=%d satp=%h mtimer=%0d stimer=%0d sbi=%0d retired=%0d retired_delta=%0d ram_req=%0d flash_req=%0d page_fault=%0d sync_trap=%0d spi_cmd=%0d,%0d,%0d,%0d,%0d uart_tail=%s", cycles,
                     dut.cpu.pc, dut.current_privilege, dut.current_satp,
                     machine_timer_traps, supervisor_timer_traps, sbi_ecalls,
                     retired_instructions, retired_instructions - last_retired_report,
                     ram_requests, flash_requests, page_faults, other_sync_traps,
                     spi_commands[0], spi_commands[1], spi_commands[2],
                     spi_commands[3], spi_commands[4], uart_line);
            $display("GUEST cycles=%0d pc=%h ra=%h sp=%h tp=%h a0=%h a1=%h a2=%h a3=%h t6=%h sepc=%h scause=%h mepc=%h mcause=%h instr=%h state=%0d", cycles,
                     dut.cpu.pc, dut.cpu.regs[1], dut.cpu.regs[2],
                     dut.cpu.regs[4], dut.cpu.regs[10], dut.cpu.regs[11],
                     dut.cpu.regs[12], dut.cpu.regs[13], dut.cpu.regs[31],
                     dut.cpu.priv_unit.sepc, dut.cpu.priv_unit.scause,
                     dut.cpu.priv_unit.mepc, dut.cpu.priv_unit.mcause,
                     dut.cpu.instr, dut.cpu.state);
            $fflush;
            last_retired_report = retired_instructions;
            next_report = next_report + report_step;
        end
        if (fault || halted) $fatal(1, "CPU fault/halt at cycle %0d pc=%h", cycles, fault_pc);
        if (cycles >= cycle_limit)
            $fatal(1, "boot timeout after %0d cycles pc=%h priv=%d satp=%h", cycles,
                   dut.cpu.pc, dut.current_privilege, dut.current_satp);
    end
endmodule
