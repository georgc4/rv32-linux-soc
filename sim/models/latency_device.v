`timescale 1ns/1ps
// Simulation-only one-request device. Read data is a deterministic address tag.
module latency_device #(
    parameter [31:0] TAG = 32'h0,
    parameter integer WAIT_CYCLES = 2
) (
    input wire clk, rst_n, allow_req,
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
    output reg [31:0] accepted_count,
    output reg [31:0] last_addr,
    output reg [31:0] last_wdata,
    output reg [3:0] last_wstrb,
    output reg last_write
);
    reg busy;
    integer remaining;
    reg [31:0] data_hold;
    assign req_ready = !busy && allow_req;
    assign resp_valid = busy && remaining == 0;
    assign resp_rdata = data_hold;
    assign resp_err = 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            remaining <= 0;
            accepted_count <= 0;
            last_addr <= 0;
            last_wdata <= 0;
            last_wstrb <= 0;
            last_write <= 0;
            data_hold <= 0;
        end else if (req_valid && req_ready) begin
            busy <= 1'b1;
            remaining <= WAIT_CYCLES;
            accepted_count <= accepted_count + 1;
            last_addr <= req_addr;
            last_wdata <= req_wdata;
            last_wstrb <= req_wstrb;
            last_write <= req_write;
            data_hold <= req_write ? 32'b0 : (req_addr ^ TAG);
        end else if (busy && remaining > 0) begin
            remaining <= remaining - 1;
        end else if (resp_valid && resp_ready) begin
            busy <= 1'b0;
        end
    end
endmodule
