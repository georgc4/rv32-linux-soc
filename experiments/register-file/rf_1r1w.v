`timescale 1ns/1ps
// Functional contract for a prospective 31x32 custom RF macro.
// Read is asynchronous within the current CPU cycle. A write commits on the
// rising edge; a read of the same address then sees the newly stored value.
// Physical timing and read/write collision behavior still need characterization.
module rf_1r1w (
    input wire clk,
    input wire [4:0] raddr,
    output wire [31:0] rdata,
    input wire wen,
    input wire [4:0] waddr,
    input wire [31:0] wdata
);
    reg [31:0] words [1:31];
    assign rdata = raddr == 0 ? 32'b0 : words[raddr];
    always @(posedge clk)
        if (wen && waddr != 0)
            words[waddr] <= wdata;
endmodule
