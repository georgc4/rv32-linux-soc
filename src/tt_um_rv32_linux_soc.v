`timescale 1ns/1ps
// Tiny Tapeout logical pin wrapper. Physical board wiring and 3.3 V level
// compatibility must be verified against the selected shuttle carrier.
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
        .uart_rx(ui_in[0]), .uart_tx(uart_tx),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_dq_in(uio_in[5:0]), .spi_dq_out(spi_dq_out),
        .spi_dq_oe(spi_dq_oe), .memory_initialized(initialized),
        .cpu_halted(halted), .cpu_fault(fault), .cpu_fault_pc(fault_pc)
    );
    assign uo_out = {initialized, uart_tx, spi_cs_n, spi_sck};
    assign uio_out = {2'b0, spi_dq_out};
    assign uio_oe = {2'b0, spi_dq_oe};
    wire unused_inputs = &{1'b0, ena, ui_in[7:1], uio_in[7:6], halted,
                           fault, fault_pc};
endmodule
