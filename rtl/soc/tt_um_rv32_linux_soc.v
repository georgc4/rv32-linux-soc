`timescale 1ns/1ps
// Tiny Tapeout logical pin wrapper. UART uses a demoboard hardware-UART pair.
// External serial-memory wiring must follow the chip-select map below.
module tt_um_rv32_linux_soc (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena,
    input wire clk,
    input wire rst_n
);
    wire uart_tx, spi_sck, initialized, halted, fault;
    wire [31:0] fault_pc;
    wire [4:0] spi_cs_n;
    wire [5:0] spi_dq_out, spi_dq_oe;
    soc_top soc (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(ui_in[3]), .uart_tx(uart_tx),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_dq_in(uio_in[5:0]), .spi_dq_out(spi_dq_out),
        .spi_dq_oe(spi_dq_oe), .memory_initialized(initialized),
        .cpu_halted(halted), .cpu_fault(fault), .cpu_fault_pc(fault_pc)
    );
    assign uo_out[0] = spi_sck;
    assign uo_out[3:1] = spi_cs_n[2:0];
    assign uo_out[4] = uart_tx;
    assign uo_out[5] = spi_cs_n[4];
    assign uo_out[6] = spi_cs_n[3];
    assign uo_out[7] = initialized;
    assign uio_out = {2'b0, spi_dq_out};
    assign uio_oe = {2'b0, spi_dq_oe};
    wire unused_inputs = &{1'b0, ena, ui_in[7:4], ui_in[2:0],
                           uio_in[7:6], halted,
                           fault, fault_pc};
endmodule
