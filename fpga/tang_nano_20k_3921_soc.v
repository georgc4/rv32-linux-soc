`timescale 1ns/1ps
// Sipeed Tang Nano 20K PCB 3921, schematic rev 1.30.
// clk_20m comes from the board MS5351 CLK0 after BL616 configuration.
// uart_rx/tx are the SoC UART pins, wired directly to the onboard BL616.
module tang_nano_20k_3921_soc (
    input wire clk_20m,
    input wire rst_n,
    input wire uart_rx,
    output wire uart_tx,
    output wire spi_sck,
    output wire [4:0] spi_cs_n,
    inout wire [5:0] spi_dq
);
    wire [5:0] spi_dq_out, spi_dq_oe;
    wire memory_initialized, cpu_halted, cpu_fault;
    wire [31:0] cpu_fault_pc;

    soc_top soc (
        .clk(clk_20m), .rst_n(rst_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_dq_in(spi_dq), .spi_dq_out(spi_dq_out),
        .spi_dq_oe(spi_dq_oe),
        .memory_initialized(memory_initialized),
        .cpu_halted(cpu_halted), .cpu_fault(cpu_fault),
        .cpu_fault_pc(cpu_fault_pc)
    );

    genvar lane;
    generate
        for (lane = 0; lane < 6; lane = lane + 1) begin : dq_pad
            assign spi_dq[lane] = spi_dq_oe[lane] ? spi_dq_out[lane] : 1'bz;
        end
    endgenerate

    wire unused_status = &{1'b0, memory_initialized, cpu_halted,
                           cpu_fault, cpu_fault_pc};
endmodule
