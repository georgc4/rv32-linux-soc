`timescale 1ns/1ps
module soc_boot_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    wire uart_tx, spi_sck, initialized, halted, fault;
    wire [31:0] fault_pc;
    wire [4:0] cs_n;
    wire [5:0] dq_in, dq_out, dq_oe;
    wire [4:0] model_so, model_oe;
    wire [31:0] counts [0:4];
    reg [31:0] image [0:87];
    reg [7:0] received [0:2];
    reg [7:0] sampled;
    integer n, j, cycles = 0, tx_count = 0;

    soc_top #(.PSRAM_POWERUP_CYCLES(4), .DIAGNOSTIC_MODE(1)) dut (
        .clk(clk), .rst_n(rst_n), .uart_rx(1'b1), .uart_tx(uart_tx),
        .spi_sck(spi_sck), .spi_cs_n(cs_n),
        .spi_dq_in(dq_in), .spi_dq_out(dq_out), .spi_dq_oe(dq_oe),
        .memory_initialized(initialized), .cpu_halted(halted),
        .cpu_fault(fault), .cpu_fault_pc(fault_pc)
    );
    assign dq_in[0] = dq_oe[0] ? dq_out[0] : 1'b0;
    assign dq_in[1] = |model_oe ?
        (model_so[0] & model_oe[0]) | (model_so[1] & model_oe[1]) |
        (model_so[2] & model_oe[2]) | (model_so[3] & model_oe[3]) |
        (model_so[4] & model_oe[4]) : 1'b0;
    assign dq_in[5:2] = dq_out[5:2];
    genvar g;
    generate for (g = 0; g < 5; g = g + 1) begin: chips
        serial_spi_model #(.MEM_BYTES(g == 4 ? 4096 : 8192),
                           .IS_FLASH(g == 4)) model (
            .cs_n(cs_n[g]), .sck(spi_sck), .si(dq_out[0]),
            .so(model_so[g]), .so_oe(model_oe[g]),
            .command_count(counts[g])
        );
    end endgenerate

    always @(posedge clk) if (rst_n) cycles <= cycles + 1;

    // Reset divisor 11 at clk=20 MHz: 176 core cycles per UART bit.
    initial forever begin
        @(negedge uart_tx);
        #2640;
        for (j = 0; j < 8; j = j + 1) begin
            sampled[j] = uart_tx;
            #1760;
        end
        if (tx_count < 3) received[tx_count] = sampled;
        tx_count = tx_count + 1;
    end

    initial begin
        $readmemh("sim/programs/rv32i_smoke.hex", image);
        #1;
        for (n = 0; n < 88; n = n + 1) begin
            chips[4].model.memory[4*n] = image[n][7:0];
            chips[4].model.memory[4*n+1] = image[n][15:8];
            chips[4].model.memory[4*n+2] = image[n][23:16];
            chips[4].model.memory[4*n+3] = image[n][31:24];
        end
        repeat (3) @(negedge clk);
        rst_n = 1;
        while (!halted && cycles < 100000) @(negedge clk);
        if (!halted) $fatal(1, "boot timeout cycles=%0d", cycles);
        if (fault) $fatal(1, "CPU fault at %h", fault_pc);
        while (tx_count < 3 && cycles < 110000) @(negedge clk);
        if (tx_count != 3 || received[0] !== "O" ||
            received[1] !== "K" || received[2] !== 8'h0a)
            $fatal(1, "UART bytes %0d: %h %h %h", tx_count,
                   received[0], received[1], received[2]);
        if ({chips[0].model.memory[4111], chips[0].model.memory[4110],
             chips[0].model.memory[4109], chips[0].model.memory[4108]} !== 32'h5a5a_a5a5)
            $fatal(1, "RAM signature mismatch");
        if (counts[4] < 88 || counts[0] < 88 || !initialized)
            $fatal(1, "memory activity flash=%0d ram=%0d", counts[4], counts[0]);
        $display("PASS soc_boot: ROM -> NOR -> PSRAM -> UART, %0d cycles", cycles);
        $finish;
    end
endmodule
