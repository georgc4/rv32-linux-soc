`timescale 1ns/1ps
// Pin-level test of both platform wrappers with the production UART RTL.
// This test-only soc_top drives the UART's MMIO bus; the serial bits still
// traverse the actual uart16550_lite RX/TX state machines and wrapper pins.
module soc_top #(
    parameter integer PSRAM_POWERUP_CYCLES = 3000,
    parameter DIAGNOSTIC_MODE = 0
) (
    input wire clk, rst_n, uart_rx,
    output wire uart_tx, spi_sck,
    output wire [4:0] spi_cs_n,
    input wire [5:0] spi_dq_in,
    output wire [5:0] spi_dq_out, spi_dq_oe,
    output wire memory_initialized, cpu_halted, cpu_fault,
    output wire [31:0] cpu_fault_pc
);
    reg req_valid = 0, req_write = 0, resp_ready = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    reg [3:0] req_wstrb = 0;
    wire req_ready, resp_valid, resp_err, irq;
    wire [31:0] resp_rdata;
    uart16550_lite uart (
        .clk(clk), .rst_n(rst_n), .req_valid(req_valid),
        .req_ready(req_ready), .req_addr(req_addr), .req_write(req_write),
        .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .resp_valid(resp_valid), .resp_ready(resp_ready),
        .resp_rdata(resp_rdata), .resp_err(resp_err),
        .rx_pin(uart_rx), .tx_pin(uart_tx), .irq(irq)
    );
    assign spi_sck = 1'b0;
    assign spi_cs_n = 5'b10101;
    assign spi_dq_out = 6'b000001;
    assign spi_dq_oe = 6'b000001;
    assign memory_initialized = 1'b1;
    assign cpu_halted = 1'b0;
    assign cpu_fault = 1'b0;
    assign cpu_fault_pc = 32'b0;
    wire unused_inputs = &{1'b0, spi_dq_in, irq};
endmodule

module physical_uart_paths_tb;
    localparam integer UART_BIT_TICKS = 176; // 20 MHz / (16 * reset divisor 11)
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    reg [7:0] ui_in = 8'hff;
    wire [7:0] uo_out, uio_out, uio_oe;
    wire [5:0] fpga_spi_dq;
    wire fpga_uart_tx, fpga_spi_sck;
    wire [4:0] fpga_spi_cs_n;
    reg fpga_uart_rx = 1;
    reg [7:0] captured_tt, captured_fpga;
    integer bit_index;

    tt_um_rv32_linux_soc tt (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(8'hff), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(1'b1), .clk(clk), .rst_n(rst_n)
    );
    tang_nano_20k_3921_soc fpga (
        .clk_20m(clk), .rst_n(rst_n),
        .uart_rx(fpga_uart_rx), .uart_tx(fpga_uart_tx),
        .spi_sck(fpga_spi_sck), .spi_cs_n(fpga_spi_cs_n),
        .spi_dq(fpga_spi_dq)
    );

    task write_thr;
        input [7:0] value;
        begin
            @(negedge clk);
            tt.soc.req_addr = 0;
            fpga.soc.req_addr = 0;
            tt.soc.req_wdata = value;
            fpga.soc.req_wdata = value;
            tt.soc.req_wstrb = 4'b0001;
            fpga.soc.req_wstrb = 4'b0001;
            tt.soc.req_write = 1;
            fpga.soc.req_write = 1;
            tt.soc.req_valid = 1;
            fpga.soc.req_valid = 1;
            @(negedge clk);
            if (!tt.soc.resp_valid || !fpga.soc.resp_valid ||
                tt.soc.resp_err || fpga.soc.resp_err)
                $fatal(1, "UART THR MMIO write failed");
            tt.soc.req_valid = 0;
            fpga.soc.req_valid = 0;
            tt.soc.resp_ready = 1;
            fpga.soc.resp_ready = 1;
            @(negedge clk);
            tt.soc.resp_ready = 0;
            fpga.soc.resp_ready = 0;
        end
    endtask

    task capture_tx;
        begin
            @(negedge uo_out[4]);
            if (fpga_uart_tx !== 1'b0) $fatal(1, "FPGA TX start bit absent");
            repeat (UART_BIT_TICKS + UART_BIT_TICKS / 2) @(posedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                captured_tt[bit_index] = uo_out[4];
                captured_fpga[bit_index] = fpga_uart_tx;
                repeat (UART_BIT_TICKS) @(posedge clk);
            end
            if (uo_out[4] !== 1'b1 || fpga_uart_tx !== 1'b1)
                $fatal(1, "UART stop bit absent");
        end
    endtask

    task send_rx;
        input [7:0] value;
        integer i;
        begin
            @(negedge clk);
            ui_in[3] = 0;
            fpga_uart_rx = 0;
            repeat (UART_BIT_TICKS) @(negedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                ui_in[3] = value[i];
                fpga_uart_rx = value[i];
                repeat (UART_BIT_TICKS) @(negedge clk);
            end
            ui_in[3] = 1;
            fpga_uart_rx = 1;
            repeat (UART_BIT_TICKS * 2) @(negedge clk);
        end
    endtask

    task read_rbr;
        input [7:0] expected;
        begin
            @(negedge clk);
            tt.soc.req_addr = 0;
            fpga.soc.req_addr = 0;
            tt.soc.req_write = 0;
            fpga.soc.req_write = 0;
            tt.soc.req_wstrb = 0;
            fpga.soc.req_wstrb = 0;
            tt.soc.req_valid = 1;
            fpga.soc.req_valid = 1;
            @(negedge clk);
            if (!tt.soc.resp_valid || !fpga.soc.resp_valid ||
                tt.soc.resp_rdata[7:0] !== expected ||
                fpga.soc.resp_rdata[7:0] !== expected)
                $fatal(1, "UART RX MMIO mismatch TT=%h FPGA=%h expected=%h",
                       tt.soc.resp_rdata[7:0], fpga.soc.resp_rdata[7:0], expected);
            tt.soc.req_valid = 0;
            fpga.soc.req_valid = 0;
            tt.soc.resp_ready = 1;
            fpga.soc.resp_ready = 1;
            @(negedge clk);
            tt.soc.resp_ready = 0;
            fpga.soc.resp_ready = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        if (uo_out[6] !== 1'b0 || uo_out[5] !== 1'b1 ||
            uo_out[3:1] !== 3'b101 || uo_out[0] !== 1'b0)
            $fatal(1, "Tiny Tapeout SPI output mapping changed");
        if (uio_oe[0] !== 1'b1 || uio_out[0] !== 1'b1 ||
            fpga_spi_dq[0] !== 1'b1 || fpga_spi_dq[1] !== 1'bz)
            $fatal(1, "SPI bidirectional pads changed");
        fork
            write_thr(8'h5a);
            capture_tx();
        join
        if (captured_tt !== 8'h5a || captured_fpga !== 8'h5a)
            $fatal(1, "UART TX mismatch TT=%h FPGA=%h", captured_tt, captured_fpga);
        send_rx(8'h41);
        read_rbr(8'h41);
        $display("PASS physical_uart_paths: TX and RX through both wrappers and UART RTL");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "physical UART path timeout");
    end
endmodule
