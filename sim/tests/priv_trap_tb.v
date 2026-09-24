`timescale 1ns/1ps
module priv_trap_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    wire iv, ir, ix, iy, ie;
    wire [31:0] ia, id;
    wire dv, dr, dx, dy, de, dw;
    wire [31:0] da, dd, dq;
    wire [3:0] ds;
    wire halted, fault, retired;
    wire [31:0] fault_pc, retire_pc;
    reg [31:0] words [0:63];
    reg busy, target_data;
    reg [31:0] read_data;
    integer cycles = 0, n;
    assign ir = !busy && !dv;
    assign dr = !busy;
    assign ix = busy && !target_data;
    assign dx = busy && target_data;
    assign id = read_data;
    assign dq = read_data;
    assign ie = 0;
    assign de = 0;

    rv32i_core #(.DIAGNOSTIC_MODE(0)) core (
        .clk(clk), .rst_n(rst_n),
        .irq_timer(1'b0), .irq_software(1'b0), .irq_external(1'b0),
        .time_value(64'b0),
        .i_req_valid(iv), .i_req_ready(ir), .i_req_addr(ia),
        .i_resp_valid(ix), .i_resp_ready(iy), .i_resp_data(id), .i_resp_err(ie),
        .i_resp_page_fault(1'b0),
        .d_req_valid(dv), .d_req_ready(dr), .d_req_addr(da),
        .d_req_write(dw), .d_req_wdata(dd), .d_req_wstrb(ds),
        .d_resp_valid(dx), .d_resp_ready(dy), .d_resp_data(dq), .d_resp_err(de),
        .d_resp_page_fault(1'b0),
        .halted(halted), .fault(fault), .fault_pc(fault_pc),
        .retire_valid(retired), .retire_pc(retire_pc)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            target_data <= 0;
            read_data <= 0;
        end else if (!busy && (dv || iv)) begin
            busy <= 1;
            target_data <= dv;
            if (dv) begin
                read_data <= words[da[7:2]];
                if (dw) begin
                    if (ds[0]) words[da[7:2]][7:0] <= dd[7:0];
                    if (ds[1]) words[da[7:2]][15:8] <= dd[15:8];
                    if (ds[2]) words[da[7:2]][23:16] <= dd[23:16];
                    if (ds[3]) words[da[7:2]][31:24] <= dd[31:24];
                end
            end else read_data <= words[ia[7:2]];
        end else if ((ix && iy) || (dx && dy)) busy <= 0;
    end
    always @(posedge clk) if (rst_n) cycles <= cycles + 1;
    initial begin
        for (n = 0; n < 64; n = n + 1) words[n] = 0;
        $readmemh("sim/programs/priv_trap.hex", words, 0, 21);
        repeat (3) @(negedge clk);
        rst_n = 1;
        while (words[32] != 1 && cycles < 300) @(negedge clk);
        if (words[32] !== 1 || words[33] !== 11 || fault || halted)
            $fatal(1, "trap failed pc=%h marker=%h cause=%h", retire_pc, words[32], words[33]);
        $display("PASS priv_trap: ECALL, mcause, mepc, MRET");
        $finish;
    end
endmodule
