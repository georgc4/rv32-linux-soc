`timescale 1ns/1ps
module sv32_supervisor_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg irq_supervisor_external = 0;
    wire iv, ir, ix, iy, ie, ipf;
    wire [31:0] ia, id;
    wire dv, dr, dx, dy, de, dpf, dw;
    wire [31:0] da, dd, dq;
    wire [3:0] ds;
    wire bv, br, bx, by, be, bw;
    wire [31:0] ba, bd, bq;
    wire [3:0] bs;
    wire halted, fault, retired;
    wire [31:0] fault_pc, retire_pc;
    wire [1:0] privilege;
    wire [31:0] satp, mstatus;
    wire sfence_commit;
    reg [31:0] memory [0:4095];
    reg busy = 0;
    reg [31:0] response = 0;
    integer cycles = 0, walks = 0, n;
    assign br = !busy;
    assign bx = busy;
    assign bq = response;
    assign be = 0;
    rv32i_core #(.DIAGNOSTIC_MODE(0)) core (
        .clk(clk), .rst_n(rst_n), .irq_timer(1'b0),
        .irq_software(1'b0), .irq_external(1'b0),
        .irq_supervisor_external(irq_supervisor_external),
        .time_value(64'b0),
        .current_privilege(privilege), .current_satp(satp),
        .current_mstatus(mstatus), .sfence_commit(sfence_commit),
        .i_req_valid(iv), .i_req_ready(ir), .i_req_addr(ia),
        .i_resp_valid(ix), .i_resp_ready(iy), .i_resp_data(id),
        .i_resp_err(ie), .i_resp_page_fault(ipf),
        .d_req_valid(dv), .d_req_ready(dr), .d_req_addr(da),
        .d_req_write(dw), .d_req_wdata(dd), .d_req_wstrb(ds),
        .d_resp_valid(dx), .d_resp_ready(dy), .d_resp_data(dq),
        .d_resp_err(de), .d_resp_page_fault(dpf),
        .halted(halted), .fault(fault), .fault_pc(fault_pc),
        .retire_valid(retired), .retire_pc(retire_pc)
    );
    sv32_bus_adapter adapter (
        .clk(clk), .rst_n(rst_n), .privilege(privilege),
        .satp(satp), .mstatus(mstatus), .tlb_flush(sfence_commit),
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
        .bus_resp_data(bq), .bus_resp_err(be)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            response <= 0;
        end else if (bv && br) begin
            busy <= 1;
            response <= memory[ba[13:2]];
            if (ba == 32'h8000_1400 || ba == 32'h8000_2000) walks <= walks + 1;
            if (bw) begin
                if (bs[0]) memory[ba[13:2]][7:0] <= bd[7:0];
                if (bs[1]) memory[ba[13:2]][15:8] <= bd[15:8];
                if (bs[2]) memory[ba[13:2]][23:16] <= bd[23:16];
                if (bs[3]) memory[ba[13:2]][31:24] <= bd[31:24];
            end
        end else if (bx && by) busy <= 0;
    end
    always @(posedge clk) if (rst_n) cycles <= cycles + 1;
    initial begin
        walks = 0;
        for (n = 0; n < 4096; n = n + 1) memory[n] = 0;
        $readmemh("sim/programs/sv32_supervisor.hex", memory, 0, 44);
        repeat (3) @(negedge clk);
        rst_n = 1;
        while (memory[64] != 42 && cycles < 400) @(negedge clk);
        if (memory[64] !== 42 || privilege !== 2'd1 || walks < 4 || fault || halted)
            $fatal(1, "supervisor Sv32 failed pc=%h marker=%h priv=%d walks=%d",
                   retire_pc, memory[64], privilege, walks);
        irq_supervisor_external = 1;
        while (memory[65] != 32'h8000_0009 && cycles < 800) @(negedge clk);
        if (memory[65] !== 32'h8000_0009 || privilege !== 2'd1 || fault || halted)
            $fatal(1, "S-mode external IRQ failed cause=%h priv=%d pc=%h",
                   memory[65], privilege, retire_pc);
        irq_supervisor_external = 0;
        $display("PASS sv32_supervisor: MRET, translated fetch/store, delegated S external IRQ");
        $finish;
    end
endmodule
