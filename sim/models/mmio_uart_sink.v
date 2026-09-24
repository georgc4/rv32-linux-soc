`timescale 1ns/1ps
// Simulation-only UART register sink. A byte store at offset 0 emits a byte.
module mmio_uart_sink (
    input wire clk, rst_n,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire req_write,
    input wire [31:0] req_wdata,
    input wire [3:0] req_wstrb,
    output wire resp_valid,
    input wire resp_ready,
    output wire [31:0] resp_rdata,
    output wire resp_err,
    output reg tx_valid,
    output reg [7:0] tx_data
);
    reg busy;
    reg error_hold;
    assign req_ready = !busy;
    assign resp_valid = busy;
    assign resp_rdata = 0;
    assign resp_err = error_hold;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            error_hold <= 0;
            tx_valid <= 0;
            tx_data <= 0;
        end else begin
            tx_valid <= 0;
            if (req_valid && req_ready) begin
                busy <= 1;
                error_hold <= req_addr != 0 || !req_write || !req_wstrb[0];
                if (req_addr == 0 && req_write && req_wstrb[0]) begin
                    tx_valid <= 1;
                    tx_data <= req_wdata[7:0];
                end
            end else if (resp_valid && resp_ready) busy <= 0;
        end
    end
endmodule
