`timescale 1ns/1ps
module priv_mip_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg [11:0] csr_addr = 0;
    reg [31:0] csr_wdata = 0;
    reg [1:0] csr_op = 0;
    reg csr_commit = 0;
    reg external_irq = 0;
    wire [31:0] csr_rdata;
    wire csr_illegal;

    rv32_priv_unit dut (
        .clk(clk), .rst_n(rst_n), .csr_addr(csr_addr),
        .csr_wdata(csr_wdata), .csr_op(csr_op), .csr_commit(csr_commit),
        .csr_rdata(csr_rdata), .csr_illegal(csr_illegal),
        .trap_commit(1'b0), .trap_interrupt(1'b0), .trap_cause(5'b0),
        .trap_pc(32'b0), .trap_value(32'b0), .trap_vector(),
        .mret_commit(1'b0), .sret_commit(1'b0), .return_pc(),
        .irq_timer(1'b0), .irq_software(1'b0), .irq_external(1'b0),
        .irq_supervisor_external(external_irq), .time_value(64'b0),
        .irq_pending(), .irq_cause(), .privilege(), .satp_value(),
        .mstatus_value()
    );

    task automatic write_csr(input [11:0] address,
                             input [1:0] operation,
                             input [31:0] data);
        begin
            @(negedge clk);
            csr_addr = address;
            csr_op = operation;
            csr_wdata = data;
            csr_commit = 1;
            @(posedge clk);
            #1;
            csr_commit = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        external_irq = 1;

        // Firmware clears STIP through MIP while the external PLIC pin is high.
        // The live SEIP value must never be copied into the software latch.
        write_csr(12'h344, 2'd2, 32'h20);
        if (dut.software_mip !== 32'h20 || csr_rdata !== 32'h220)
            $fatal(1, "MIP set latched live SEIP: sw=%h mip=%h",
                   dut.software_mip, csr_rdata);
        write_csr(12'h344, 2'd3, 32'h20);
        if (dut.software_mip !== 0 || csr_rdata !== 32'h200)
            $fatal(1, "MIP clear latched live SEIP: sw=%h mip=%h",
                   dut.software_mip, csr_rdata);
        external_irq = 0;
        #1;
        if (csr_rdata !== 0) $fatal(1, "SEIP stayed pending after pin fell");

        // Exercise the delegated SIP alias through the same live-pin case.
        write_csr(12'h303, 2'd1, 32'h222);
        external_irq = 1;
        write_csr(12'h144, 2'd2, 32'h20);
        if (dut.software_mip !== 32'h20)
            $fatal(1, "SIP set latched live SEIP: sw=%h", dut.software_mip);
        write_csr(12'h144, 2'd3, 32'h20);
        if (dut.software_mip !== 0)
            $fatal(1, "SIP clear latched live SEIP: sw=%h", dut.software_mip);
        external_irq = 0;
        csr_addr = 12'h144;
        #1;
        if (csr_rdata !== 0) $fatal(1, "SIP SEIP stayed pending after pin fell");
        $display("PASS priv_mip: live external interrupt does not latch through CSR writes");
        $finish;
    end
endmodule
