`timescale 1ns/1ps
// Simulation-only little-endian word array with periodic request stalls.
module word_ram #(
    parameter integer WORDS = 4096,
    parameter integer INIT_WORDS = 88,
    parameter INIT_FILE = "sim/programs/rv32i_smoke.hex"
) (
    input wire clk, rst_n,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire req_write,
    input wire [31:0] req_wdata,
    input wire [3:0] req_wstrb,
    output wire resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_rdata,
    output reg resp_err,
    output reg [31:0] read_count,
    output reg [31:0] write_count
);
    reg [31:0] words [0:WORDS-1];
    reg [2:0] phase;
    reg busy;
    reg [1:0] delay_count;
    integer k;
    initial begin
        for (k = 0; k < WORDS; k = k + 1) words[k] = 0;
        $readmemh(INIT_FILE, words, 0, INIT_WORDS - 1);
    end
    assign req_ready = !busy && phase[1:0] != 0;
    assign resp_valid = busy && delay_count == 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0;
            busy <= 0;
            delay_count <= 0;
            resp_rdata <= 0;
            resp_err <= 0;
            read_count <= 0;
            write_count <= 0;
        end else begin
            phase <= phase + 1;
            if (req_valid && req_ready) begin
                busy <= 1;
                delay_count <= 2;
                resp_err <= req_addr >= WORDS * 4;
                resp_rdata <= req_addr >= WORDS * 4 ? 0 : words[req_addr[13:2]];
                if (req_write) begin
                    write_count <= write_count + 1;
                    if (req_addr < WORDS * 4) begin
                        if (req_wstrb[0]) words[req_addr[13:2]][7:0] <= req_wdata[7:0];
                        if (req_wstrb[1]) words[req_addr[13:2]][15:8] <= req_wdata[15:8];
                        if (req_wstrb[2]) words[req_addr[13:2]][23:16] <= req_wdata[23:16];
                        if (req_wstrb[3]) words[req_addr[13:2]][31:24] <= req_wdata[31:24];
                    end
                end else read_count <= read_count + 1;
            end else if (busy && delay_count != 0) delay_count <= delay_count - 1;
            else if (resp_valid && resp_ready) busy <= 0;
        end
    end
endmodule
