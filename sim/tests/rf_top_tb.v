`timescale 1ns/1ps
module rf_top_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg [31:0] wd = 0;
    reg [4:0] wa = 0, ra = 0, rb = 0;
    reg we = 0;
    wire [31:0] qa, qb;
    rf_top dut(.clk(clk), .w_data(wd), .w_addr(wa), .w_ena(we),
               .ra_addr(ra), .rb_addr(rb), .ra_data(qa), .rb_data(qb));
    initial begin
        @(negedge clk); we=1; wa=5; wd=32'h12345678; ra=5; rb=5;
        @(posedge clk); #1;
        if (qa !== wd || qb !== wd) $fatal(1,"both read ports must be write-first");
        @(negedge clk); wa=6; wd=32'h89abcdef; rb=6;
        @(posedge clk); #1;
        if (qa !== 32'h12345678 || qb !== wd) $fatal(1,"independent read/write ports");
        @(negedge clk); we=0; ra=6; rb=5;
        #1;
        if (qa !== 32'h12345678 || qb !== 32'h89abcdef) $fatal(1,"read outputs changed without clock");
        @(posedge clk); #1;
        if (qa !== 32'h89abcdef || qb !== 32'h12345678) $fatal(1,"clocked read latency");
        // The macro has storage at address zero. Architectural x0 masking is
        // the CPU wrapper's responsibility, exercised by the alias program.
        @(negedge clk); we=1; wa=0; wd=32'hfeedface; ra=0; rb=0;
        @(posedge clk); #1;
        if (qa !== wd || qb !== wd) $fatal(1,"raw macro address zero semantics");
        $display("PASS rf_top: write-first, two ports, clocked outputs, raw word zero");
        $finish;
    end
    initial begin #1000; $fatal(1,"RF test timeout"); end
endmodule
