`timescale 1ns/1ps
module linux_handoff_tb;
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
    reg [7:0] received [0:4];
    reg [7:0] sampled;
    integer cycles = 0, tx_count = 0, j;

    soc_top #(.PSRAM_POWERUP_CYCLES(4), .DIAGNOSTIC_MODE(0)) dut (
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
        serial_spi_model #(.MEM_BYTES(g == 0 ? 32'h00800000 :
                                     g == 4 ? 270336 : 4096),
                           .IS_FLASH(g == 4)) model (
            .cs_n(cs_n[g]), .sck(spi_sck),
            .io_in(g == 4 ? {dq_out[5:4], dq_out[1:0]} : dq_out[3:0]),
            .io_out(model_out[g]), .io_oe(model_oe[g]),
            .command_count()
        );
    end endgenerate

    always @(posedge clk) if (rst_n) cycles <= cycles + 1;
    initial forever begin
        @(negedge uart_tx);
        #2640;
        for (j = 0; j < 8; j = j + 1) begin
            sampled[j] = uart_tx;
            #1760;
        end
        if (tx_count < 5) received[tx_count] = sampled;
        tx_count = tx_count + 1;
    end

    initial begin
        #1;
        $readmemh("build/linux_handoff_stub.flash.hex", chips[4].model.memory);
        if ($test$plusargs("bad_dtb"))
            chips[4].model.memory['h40020] = chips[4].model.memory['h40020] ^ 8'h01;
        if ($test$plusargs("bad_kernel"))
            chips[4].model.memory['h41040] = chips[4].model.memory['h41040] ^ 8'h01;
        repeat (3) @(negedge clk);
        rst_n = 1;
        if ($test$plusargs("bad_dtb") || $test$plusargs("bad_kernel")) begin
            while (tx_count < 2 && cycles < 2000000) @(negedge clk);
            if (tx_count != 2 || received[0] !== "L" ||
                received[1] !== ($test$plusargs("bad_dtb") ? "D" : "K"))
                $fatal(1, "corrupt payload accepted or wrong error bytes=%0d %h %h",
                       tx_count, received[0], received[1]);
            $display("PASS Linux loader rejects corrupt %s", $test$plusargs("bad_dtb") ? "DTB" : "kernel");
            $finish;
        end
        while (tx_count < 5 && cycles < 2000000) @(negedge clk);
        if (tx_count != 5)
            $fatal(1, "handoff timeout cycles=%0d bytes=%0d fault=%b pc=%h core_pc=%h priv=%d mcause=%h mepc=%h mtval=%h",
                   cycles, tx_count, fault, fault_pc, dut.cpu.pc, dut.current_privilege,
                   dut.cpu.priv_unit.mcause, dut.cpu.priv_unit.mepc, dut.cpu.priv_unit.mtval);
        if (received[0] !== "L" || received[1] !== "B" ||
            received[2] !== "S" || received[3] !== "T" || received[4] !== "P")
            $fatal(1, "handoff UART bytes %h %h %h %h %h", received[0], received[1], received[2], received[3], received[4]);
        if (dut.current_privilege !== 2'd1 || fault || halted || !initialized)
            $fatal(1, "handoff state priv=%d fault=%b halted=%b init=%b", dut.current_privilege, fault, halted, initialized);
        if ({chips[0].model.memory['h3f0000], chips[0].model.memory['h3f0001],
             chips[0].model.memory['h3f0002], chips[0].model.memory['h3f0003]} !== 32'hd00dfeed)
            $fatal(1, "DTB was not copied into reserved PSRAM");
        $display("PASS Linux handoff stub: ROM, loader, DTB, M->S, SBI base/TIME, timer and PLIC traps (%0d cycles)", cycles);
        $finish;
    end
endmodule
