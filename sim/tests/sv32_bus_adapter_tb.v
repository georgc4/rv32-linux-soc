`timescale 1ns/1ps
module sv32_bus_adapter_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg [1:0] privilege = 2'd1;
    reg [31:0] satp = 32'h8000_0000, mstatus = 0;
    reg tlb_flush = 0;
    reg iv = 0, iy = 0, dv = 0, dy = 0, dw = 0;
    reg [31:0] ia = 0, da = 0, dd = 0;
    reg [3:0] ds = 0;
    wire ir, ix, ie, ipf, dr, dx, de, dpf;
    wire [31:0] id, dq;
    wire bv, br, bw, bx, by;
    wire [31:0] ba, bd;
    wire [3:0] bs;
    reg [31:0] bq = 0;
    reg busy = 0;
    reg [31:0] memory [0:8191];
    integer k, cycles = 0, walks = 0, updates = 0;
    assign br = !busy;
    assign bx = busy;
    sv32_bus_adapter dut (
        .clk(clk), .rst_n(rst_n), .privilege(privilege), .satp(satp), .mstatus(mstatus),
        .tlb_flush(tlb_flush),
        .i_req_valid(iv), .i_req_ready(ir), .i_req_addr(ia),
        .i_resp_valid(ix), .i_resp_ready(iy), .i_resp_data(id),
        .i_resp_err(ie), .i_resp_page_fault(ipf),
        .d_req_valid(dv), .d_req_ready(dr), .d_req_addr(da),
        .d_req_write(dw), .d_req_wdata(dd), .d_req_wstrb(ds),
        .d_resp_valid(dx), .d_resp_ready(dy), .d_resp_data(dq),
        .d_resp_err(de), .d_resp_page_fault(dpf),
        .bus_req_valid(bv), .bus_req_ready(br), .bus_req_addr(ba),
        .bus_req_write(bw), .bus_req_wdata(bd), .bus_req_wstrb(bs),
        .bus_resp_valid(bx), .bus_resp_ready(by),
        .bus_resp_data(bq), .bus_resp_err(1'b0)
    );
    always @(posedge clk) begin
        if (rst_n) cycles <= cycles + 1;
        if (!rst_n) busy <= 0;
        else if (bv && br) begin
            busy <= 1;
            bq <= memory[ba[14:2]];
            if (bw) begin
                if (bs[0]) memory[ba[14:2]][7:0] <= bd[7:0];
                if (bs[1]) memory[ba[14:2]][15:8] <= bd[15:8];
                if (bs[2]) memory[ba[14:2]][23:16] <= bd[23:16];
                if (bs[3]) memory[ba[14:2]][31:24] <= bd[31:24];
                if (ba == 32'h1004) updates <= updates + 1;
            end else if (ba == 32'h0400 || ba == 32'h1004) walks <= walks + 1;
        end else if (bx && by) busy <= 0;
    end
    task data_request;
        input [31:0] addr, data;
        input wr;
        input [31:0] expected;
        input expect_err, expect_page;
        begin
            @(negedge clk);
            da = addr; dd = data; dw = wr; ds = wr ? 4'hf : 4'h0; dv = 1; dy = 0;
            while (!dr) @(negedge clk);
            @(negedge clk); dv = 0;
            while (!dx) @(negedge clk);
            if (de !== expect_err || dpf !== expect_page || (!expect_err && !wr && dq !== expected))
                $fatal(1, "data addr=%h got=%h err=%b page=%b", addr, dq, de, dpf);
            dy = 1;
            @(negedge clk); dy = 0;
        end
    endtask
    task instruction_request;
        input [31:0] addr, expected;
        input expect_err, expect_page;
        begin
            @(negedge clk);
            ia = addr; iv = 1; iy = 0;
            while (!ir) @(negedge clk);
            @(negedge clk); iv = 0;
            while (!ix) @(negedge clk);
            if (ie !== expect_err || ipf !== expect_page || (!expect_err && id !== expected))
                $fatal(1, "fetch addr=%h got=%h err=%b page=%b", addr, id, ie, ipf);
            iy = 1;
            @(negedge clk); iy = 0;
        end
    endtask
    initial begin
        for (k = 0; k < 8192; k = k + 1) memory[k] = 0;
        memory[256] = 32'h0000_0401; // root -> level-zero table at 0x1000
        memory[1025] = 32'h0000_0807; // 4 KiB leaf -> 0x2000, R/W, A/D clear
        memory[2050] = 32'h1234_5678;
        memory[257] = 32'h0000_00cf; // 4 MiB R/W/X superpage at physical zero
        repeat (3) @(negedge clk);
        rst_n = 1;
        data_request(32'h4000_1008, 0, 0, 32'h1234_5678, 0, 0);
        if (memory[1025] !== 32'h0000_0847) $fatal(1, "A bit not set");
        data_request(32'h4000_1008, 32'haabb_ccdd, 1, 0, 0, 0);
        if (memory[1025] !== 32'h0000_08c7 || memory[2050] !== 32'haabb_ccdd)
            $fatal(1, "D bit or write failure");
        data_request(32'h4000_1008, 0, 0, 32'haabb_ccdd, 0, 0);
        if (walks != 4) $fatal(1, "TLB hit unexpectedly walked page tables");
        memory[1025] = 32'h0000_0cc7; // remap to 0x3000 with A/D set
        memory[3074] = 32'hfeed_beef;
        @(negedge clk); tlb_flush = 1;
        @(negedge clk); tlb_flush = 0;
        data_request(32'h4000_1008, 0, 0, 32'hfeed_beef, 0, 0);
        if (walks != 6) $fatal(1, "SFENCE did not force a new page walk");
        instruction_request(32'h4000_1008, 0, 1, 1); // no X permission
        instruction_request(32'h4040_2008, 32'haabb_ccdd, 0, 0);
        data_request(32'h4080_0000, 0, 0, 0, 1, 1); // invalid PTE
        privilege = 2'd3; // M-mode bypasses satp
        data_request(32'h0000_2008, 0, 0, 32'haabb_ccdd, 0, 0);
        if (walks != 6 || updates != 2) $fatal(1, "walk/update count %0d/%0d", walks, updates);
        memory[4352] = 32'h0000_1401; // second SATP root -> table at 0x5000
        memory[5121] = 32'h0000_18c7; // VA 0x40001008 -> PA 0x6008
        memory[6146] = 32'hdeca_fbad;
        privilege = 2'd1;
        satp = 32'h8000_0004;
        data_request(32'h4000_1008, 0, 0, 32'hdeca_fbad, 0, 0);
        satp = 32'h8000_0000;
        data_request(32'h4000_1008, 0, 0, 32'hfeed_beef, 0, 0);
        $display("PASS sv32: two-level walk, TLB hit/flush, SATP switch, superpage, permissions, A/D, bypass");
        $finish;
    end
    initial begin
        repeat (500) @(negedge clk);
        $fatal(1, "Sv32 timeout cycles=%0d", cycles);
    end
endmodule
