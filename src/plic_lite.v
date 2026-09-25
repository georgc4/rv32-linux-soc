`timescale 1ns/1ps
// One level-triggered UART source, supervisor context 0, SiFive PLIC offsets.
module plic_lite (
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
    input wire source_irq,
    output wire supervisor_irq
);
    localparam [31:0] PRIORITY1 = 32'h0000_0004;
    localparam [31:0] PENDING0  = 32'h0000_1000;
    localparam [31:0] ENABLE0   = 32'h0000_2000;
    localparam [31:0] THRESHOLD = 32'h0020_0000;
    localparam [31:0] CLAIM     = 32'h0020_0004;
    reg response_pending;
    reg [2:0] irq_priority, threshold;
    reg enabled, in_service;
    wire source_pending = source_irq && !in_service;
    wire claimable = source_pending && enabled && irq_priority > threshold;
    wire unused_wstrb = &{1'b0, req_wstrb[3:1]};
    assign supervisor_irq = claimable;
    assign req_ready = !response_pending;
    assign resp_valid = response_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            response_pending <= 0;
            resp_rdata <= 0;
            resp_err <= 0;
            irq_priority <= 0;
            threshold <= 0;
            enabled <= 0;
            in_service <= 0;
        end else if (req_valid && req_ready) begin
            response_pending <= 1;
            resp_rdata <= 0;
            resp_err <= req_addr[1:0] != 0;
            if (req_addr[1:0] == 0) begin
                case (req_addr)
                    PRIORITY1: begin
                        resp_rdata <= {29'b0, irq_priority};
                        if (req_write && req_wstrb[0]) irq_priority <= req_wdata[2:0];
                    end
                    PENDING0: begin
                        resp_rdata <= {30'b0, source_pending, 1'b0};
                        if (req_write) resp_err <= 1;
                    end
                    ENABLE0: begin
                        resp_rdata <= {30'b0, enabled, 1'b0};
                        if (req_write && req_wstrb[0]) enabled <= req_wdata[1];
                    end
                    THRESHOLD: begin
                        resp_rdata <= {29'b0, threshold};
                        if (req_write && req_wstrb[0]) threshold <= req_wdata[2:0];
                    end
                    CLAIM: begin
                        resp_rdata <= claimable ? 32'd1 : 32'd0;
                        if (req_write) begin
                            if (req_wstrb[0] && req_wdata == 32'd1) in_service <= 0;
                        end else if (claimable) in_service <= 1;
                    end
                    default: resp_err <= 1;
                endcase
            end
        end else if (resp_valid && resp_ready) response_pending <= 0;
    end
endmodule
