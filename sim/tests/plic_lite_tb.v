`timescale 1ns/1ps
module plic_lite_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, req_valid = 0, req_write = 0, resp_ready = 1, source_irq = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    reg [3:0] req_wstrb = 0;
    wire req_ready, resp_valid, resp_err, supervisor_irq;
    wire [31:0] resp_rdata;
    plic_lite dut (
        .clk(clk), .rst_n(rst_n), .req_valid(req_valid), .req_ready(req_ready),
        .req_addr(req_addr), .req_write(req_write), .req_wdata(req_wdata),
        .req_wstrb(req_wstrb), .resp_valid(resp_valid), .resp_ready(resp_ready),
        .resp_rdata(resp_rdata), .resp_err(resp_err),
        .source_irq(source_irq), .supervisor_irq(supervisor_irq)
    );
    task access(input [31:0] addr, input wr, input [31:0] data,
                input [31:0] expected);
        begin
            @(negedge clk);
            req_addr = addr; req_write = wr; req_wdata = data;
            req_wstrb = wr ? 4'hf : 4'h0; req_valid = 1;
            if (!req_ready) $fatal(1, "PLIC request stalled");
            @(negedge clk);
            req_valid = 0;
            if (!resp_valid || resp_err || resp_rdata !== expected)
                $fatal(1, "PLIC addr=%h write=%b got=%h expected=%h err=%b",
                       addr, wr, resp_rdata, expected, resp_err);
            @(negedge clk);
        end
    endtask
    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        source_irq = 1;
        if (supervisor_irq) $fatal(1, "unconfigured source asserted");
        access(32'h0004, 1, 1, 0);
        access(32'h2000, 1, 2, 0);
        if (!supervisor_irq) $fatal(1, "enabled source missing");
        access(32'h1000, 0, 0, 2);
        access(32'h200004, 0, 0, 1);
        if (supervisor_irq) $fatal(1, "claimed source still asserted");
        access(32'h1000, 0, 0, 0);
        access(32'h200004, 1, 1, 0);
        if (!supervisor_irq) $fatal(1, "level source did not reassert");
        source_irq = 0;
        #1;
        if (supervisor_irq) $fatal(1, "deasserted source still asserted");
        access(32'h200004, 0, 0, 0);
        $display("PASS PLIC priority, enable, pending, claim, complete, level reassert");
        $finish;
    end
endmodule
