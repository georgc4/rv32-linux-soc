`timescale 1ns/1ps
// Single-hart CLINT-style mtime/mtimecmp/msip physical registers.
module clint_timer (
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
    output wire irq_timer,
    output wire irq_software
);
    reg [63:0] mtime, mtimecmp;
    reg msip;
    reg pending;
    function [31:0] merge_bytes;
        input [31:0] prior, data;
        input [3:0] mask;
        begin
            merge_bytes = prior;
            if (mask[0]) merge_bytes[7:0] = data[7:0];
            if (mask[1]) merge_bytes[15:8] = data[15:8];
            if (mask[2]) merge_bytes[23:16] = data[23:16];
            if (mask[3]) merge_bytes[31:24] = data[31:24];
        end
    endfunction
    assign req_ready = !pending;
    assign resp_valid = pending;
    assign irq_timer = mtime >= mtimecmp;
    assign irq_software = msip;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime <= 0;
            mtimecmp <= 64'hffff_ffff_ffff_ffff;
            msip <= 0;
            pending <= 0;
            resp_rdata <= 0;
            resp_err <= 0;
        end else begin
            mtime <= mtime + 64'd1;
            if (req_valid && req_ready) begin
                pending <= 1;
                resp_err <= 0;
                resp_rdata <= 0;
                case (req_addr)
                    32'h0000_0000: begin
                        resp_rdata <= {31'b0, msip};
                        if (req_write && req_wstrb[0]) msip <= req_wdata[0];
                    end
                    32'h0000_4000: begin
                        resp_rdata <= mtimecmp[31:0];
                        if (req_write) mtimecmp[31:0] <= merge_bytes(mtimecmp[31:0], req_wdata, req_wstrb);
                    end
                    32'h0000_4004: begin
                        resp_rdata <= mtimecmp[63:32];
                        if (req_write) mtimecmp[63:32] <= merge_bytes(mtimecmp[63:32], req_wdata, req_wstrb);
                    end
                    32'h0000_bff8: begin
                        resp_rdata <= mtime[31:0];
                        if (req_write) mtime[31:0] <= merge_bytes(mtime[31:0], req_wdata, req_wstrb);
                    end
                    32'h0000_bffc: begin
                        resp_rdata <= mtime[63:32];
                        if (req_write) mtime[63:32] <= merge_bytes(mtime[63:32], req_wdata, req_wstrb);
                    end
                    default: resp_err <= 1;
                endcase
            end else if (resp_valid && resp_ready) pending <= 0;
        end
    end
endmodule
