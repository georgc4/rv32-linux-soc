`timescale 1ns/1ps
module soc_boot_tb;
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
    wire [31:0] counts [0:4];
    reg [31:0] image [0:87];
    reg [31:0] image_sum;
    reg [7:0] received [0:2];
    reg [7:0] sampled;
    integer n, j, cycles = 0, tx_count = 0;
    reg bad_image;

    soc_top #(.PSRAM_POWERUP_CYCLES(4), .DIAGNOSTIC_MODE(1)) dut (
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
        serial_spi_model #(.MEM_BYTES(g == 4 ? 4096 : 8192),
                           .IS_FLASH(g == 4)) model (
            .cs_n(cs_n[g]), .sck(spi_sck),
            .io_in(g == 4 ? {dq_out[5:4], dq_out[1:0]} : dq_out[3:0]),
            .io_out(model_out[g]), .io_oe(model_oe[g]),
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
        bad_image = $test$plusargs("bad_image");
        $readmemh("sim/programs/rv32i_smoke.hex", image);
        #1;
        image_sum = 0;
        for (n = 0; n < 88; n = n + 1) begin
            image_sum = image_sum + image[n];
            chips[4].model.memory[16+4*n] = image[n][7:0];
            chips[4].model.memory[17+4*n] = image[n][15:8];
            chips[4].model.memory[18+4*n] = image[n][23:16];
            chips[4].model.memory[19+4*n] = image[n][31:24];
        end
        chips[4].model.memory[0] = 8'h42;
        chips[4].model.memory[1] = 8'h53;
        chips[4].model.memory[2] = 8'h56;
        chips[4].model.memory[3] = 8'h52;
        chips[4].model.memory[4] = 8'd88;
        chips[4].model.memory[8] = image_sum[7:0];
        chips[4].model.memory[9] = image_sum[15:8];
        chips[4].model.memory[10] = image_sum[23:16];
        chips[4].model.memory[11] = image_sum[31:24];
        if (bad_image) chips[4].model.memory[8] = image_sum[7:0] ^ 8'h01;
        repeat (3) @(negedge clk);
        rst_n = 1;
        if (bad_image) begin
            while (tx_count < 1 && cycles < 100000) @(negedge clk);
            if (tx_count != 1 || received[0] !== "E" || fault)
                $fatal(1, "bad image did not signal failure: count=%0d byte=%h", tx_count, received[0]);
            $display("PASS soc_boot bad image: checksum rejected over UART");
            $finish;
        end
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
        if (counts[4] < 91 || counts[0] < 88 || !initialized)
            $fatal(1, "memory activity flash=%0d ram=%0d", counts[4], counts[0]);
        $display("PASS soc_boot: ROM -> NOR -> PSRAM -> UART, %0d cycles", cycles);
        $finish;
    end
endmodule
