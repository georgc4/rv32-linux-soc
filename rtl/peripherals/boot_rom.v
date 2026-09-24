`timescale 1ns/1ps
// Immutable boot words inferred as logic/ROM by synthesis.
module boot_rom #(
    parameter integer WORDS = 11,
    parameter INIT_FILE = "firmware/boot_rom.hex"
) (
    input wire clk, rst_n,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire req_write,
    output wire resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_rdata,
    output reg resp_err
);
    reg [31:0] image [0:WORDS-1];
    reg pending;
    localparam integer ADDR_BITS = $clog2(WORDS);
    initial $readmemh(INIT_FILE, image);
    assign req_ready = !pending;
    assign resp_valid = pending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending <= 0;
            resp_rdata <= 0;
            resp_err <= 0;
        end else if (req_valid && req_ready) begin
            pending <= 1;
            resp_err <= req_write || req_addr[1:0] != 0 || req_addr >= WORDS * 4;
            resp_rdata <= (req_write || req_addr[1:0] != 0 || req_addr >= WORDS * 4) ?
                          32'b0 : image[req_addr[ADDR_BITS+1:2]];
        end else if (resp_valid && resp_ready) pending <= 0;
    end
endmodule
