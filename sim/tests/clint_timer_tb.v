`timescale 1ns/1ps
module clint_timer_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, req_valid = 0, req_write = 0, resp_ready = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    reg [3:0] req_wstrb = 0;
    wire req_ready, resp_valid, resp_err, irq_timer, irq_software;
    wire [31:0] resp_rdata;
    wire [63:0] time_value;
    integer cycles = 0;
    clint_timer dut (
        .clk(clk), .rst_n(rst_n), .req_valid(req_valid), .req_ready(req_ready),
        .req_addr(req_addr), .req_write(req_write),
        .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .resp_valid(resp_valid), .resp_ready(resp_ready),
        .resp_rdata(resp_rdata), .resp_err(resp_err),
        .irq_timer(irq_timer), .irq_software(irq_software),
        .time_value(time_value)
    );
    task write_register;
        input [31:0] addr, data;
        begin
            @(negedge clk);
            req_addr = addr; req_wdata = data; req_wstrb = 4'hf;
            req_write = 1; req_valid = 1;
            while (!req_ready) @(negedge clk);
            @(negedge clk); req_valid = 0;
            while (!resp_valid) @(negedge clk);
            if (resp_err) $fatal(1, "CLINT write fault at %h", addr);
            resp_ready = 1;
            @(negedge clk); resp_ready = 0;
        end
    endtask
    always @(posedge clk) if (rst_n) cycles <= cycles + 1;
    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        if (irq_timer || irq_software) $fatal(1, "CLINT reset IRQ");
        write_register(32'h4004, 0);
        write_register(32'h4000, 30);
        while (!irq_timer && cycles < 50) @(negedge clk);
        if (!irq_timer || time_value < 30) $fatal(1, "timer compare failed");
        write_register(32'h4000, 32'hffff_ffff);
        write_register(32'h4004, 32'hffff_ffff);
        if (irq_timer) $fatal(1, "timer IRQ did not clear");
        write_register(0, 1);
        if (!irq_software) $fatal(1, "software IRQ missing");
        write_register(0, 0);
        if (irq_software) $fatal(1, "software IRQ did not clear");
        $display("PASS clint_timer: time, compare, software IRQ");
        $finish;
    end
endmodule
