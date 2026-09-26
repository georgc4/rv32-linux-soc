`timescale 1ns/1ps
module rf_1r1w_tb;
    reg clk = 0;
    reg [4:0] raddr = 0, waddr = 0;
    reg [31:0] wdata = 0;
    reg wen = 0;
    wire [31:0] rdata;
    reg [31:0] expected [1:31];
    integer i;
    rf_1r1w dut (.clk(clk), .raddr(raddr), .rdata(rdata),
                  .wen(wen), .waddr(waddr), .wdata(wdata));
    always #5 clk = ~clk;

    task write_word(input [4:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            wen = 1;
            waddr = addr;
            wdata = data;
            @(posedge clk);
            #1;
            wen = 0;
            if (addr != 0) expected[addr] = data;
        end
    endtask

    task check_word(input [4:0] addr, input [31:0] data);
        begin
            raddr = addr;
            #1;
            if (rdata !== data) $fatal(1, "x%0d got %h expected %h", addr, rdata, data);
        end
    endtask

    initial begin
        check_word(0, 0);
        for (i = 1; i < 32; i = i + 1)
            write_word(i[4:0], 32'h9e3779b9 ^ (i * 32'h01020305));
        write_word(0, 32'hffffffff);
        check_word(0, 0);
        for (i = 1; i < 32; i = i + 1)
            check_word(i[4:0], expected[i]);
        // Read the address being written: old value before, new after edge.
        @(negedge clk);
        raddr = 7;
        wen = 1;
        waddr = 7;
        wdata = 32'h12345678;
        #1;
        if (rdata !== expected[7]) $fatal(1, "collision old-data mismatch");
        @(posedge clk);
        #1;
        if (rdata !== 32'h12345678) $fatal(1, "collision new-data mismatch");
        $display("rf_1r1w contract PASS");
        $finish;
    end
endmodule
