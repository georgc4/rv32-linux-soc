`timescale 1ns/1ps
// Single-hart machine/supervisor CSR and trap state. satp is stored here;
// address translation is a separate, unfinished stage of the CPU.
module rv32_priv_unit (
    input wire clk, rst_n,
    input wire [11:0] csr_addr,
    input wire [31:0] csr_wdata,
    input wire [1:0] csr_op, // 1=write, 2=set, 3=clear
    input wire csr_commit,
    output reg [31:0] csr_rdata,
    output reg csr_illegal,
    input wire trap_commit,
    input wire trap_interrupt,
    input wire [4:0] trap_cause,
    input wire [31:0] trap_pc,
    input wire [31:0] trap_value,
    output wire [31:0] trap_vector,
    input wire mret_commit,
    input wire sret_commit,
    output wire [31:0] return_pc,
    input wire irq_timer,
    input wire irq_software,
    input wire irq_external,
    input wire irq_supervisor_external,
    input wire [63:0] time_value,
    output reg irq_pending,
    output reg [4:0] irq_cause,
    output wire [1:0] privilege,
    output wire [31:0] satp_value,
    output wire [31:0] mstatus_value
);
    localparam [1:0] U = 2'd0, S = 2'd1, M = 2'd3;
    reg [1:0] priv;
    reg [31:0] mstatus, mie, medeleg, mideleg, software_mip;
    reg [31:0] mcounteren, scounteren;
    reg [31:0] mtvec, mscratch, mepc, mcause, mtval;
    reg [31:0] stvec, sscratch, sepc, scause, stval, satp;
    wire [31:0] mip = software_mip |
                      (irq_external === 1'b1 ? 32'h0000_0800 : 32'b0) |
                      (irq_supervisor_external === 1'b1 ? 32'h0000_0200 : 32'b0) |
                      (irq_timer === 1'b1 ? 32'h0000_0080 : 32'b0) |
                      (irq_software === 1'b1 ? 32'h0000_0008 : 32'b0);
    wire [31:0] sstatus_mask = 32'h000c_6122;
    wire [31:0] writable_mstatus = 32'h007e_19aa;
    wire [31:0] writable_mie = 32'h0000_0aaa;
    wire [31:0] pending_enabled = mip & mie;
    wire delegate_trap = priv != M &&
                         (trap_interrupt ? mideleg[trap_cause] : medeleg[trap_cause]);
    wire [31:0] selected_tvec = delegate_trap ? stvec : mtvec;
    wire unused_fields = &{1'b0, trap_pc[1:0], selected_tvec[1],
                           pending_enabled[31:12], pending_enabled[10],
                           pending_enabled[8], pending_enabled[6],
                           pending_enabled[4], pending_enabled[2], pending_enabled[0]};
    wire [31:0] selected_base = {selected_tvec[31:2], 2'b0};
    wire [31:0] modified_csr = csr_op == 2'd1 ? csr_wdata :
                               csr_op == 2'd2 ? csr_rdata | csr_wdata :
                               csr_rdata & ~csr_wdata;
    assign privilege = priv;
    assign satp_value = satp;
    assign mstatus_value = mstatus;
    assign return_pc = mret_commit ? mepc : sepc;
    assign trap_vector = selected_base +
                         ((trap_interrupt && selected_tvec[0]) ? {25'b0, trap_cause, 2'b0} : 32'b0);

    always @* begin
        csr_rdata = 0;
        csr_illegal = 0;
        if (priv < csr_addr[9:8]) csr_illegal = 1;
        if (csr_op != 0 && csr_addr[11:10] == 2'b11)
            csr_illegal = 1;
        case (csr_addr)
            12'h100: csr_rdata = mstatus & sstatus_mask; // sstatus
            12'h106: csr_rdata = scounteren;
            12'h104: csr_rdata = mie & mideleg; // sie
            12'h105: csr_rdata = stvec;
            12'h140: csr_rdata = sscratch;
            12'h141: csr_rdata = sepc;
            12'h142: csr_rdata = scause;
            12'h143: csr_rdata = stval;
            12'h144: csr_rdata = mip & mideleg; // sip
            12'h180: csr_rdata = satp;
            12'h300: csr_rdata = mstatus;
            12'h301: csr_rdata = 32'h4014_1101; // RV32IMA with S and U
            12'h302: csr_rdata = medeleg;
            12'h303: csr_rdata = mideleg;
            12'h304: csr_rdata = mie;
            12'h305: csr_rdata = mtvec;
            12'h306: csr_rdata = mcounteren;
            12'h340: csr_rdata = mscratch;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            12'h343: csr_rdata = mtval;
            12'h344: csr_rdata = mip;
            12'hc01: csr_rdata = time_value[31:0];
            12'hc81: csr_rdata = time_value[63:32];
            12'hf11, 12'hf12, 12'hf13, 12'hf14: csr_rdata = 0;
            default: csr_illegal = 1;
        endcase
        if (csr_addr == 12'h180 && priv == S && mstatus[20]) csr_illegal = 1;
        if ((csr_addr == 12'hc01 || csr_addr == 12'hc81) &&
            priv != M && (!mcounteren[1] || (priv == U && !scounteren[1])))
            csr_illegal = 1;
    end

    always @* begin
        irq_pending = 0;
        irq_cause = 0;
        // Machine interrupts have priority; delegated S interrupts are taken
        // only while running below machine mode.
        if (pending_enabled[11] && !mideleg[11] && (priv != M || mstatus[3])) begin
            irq_pending = 1;
            irq_cause = 5'd11;
        end else if (pending_enabled[3] && !mideleg[3] && (priv != M || mstatus[3])) begin
            irq_pending = 1;
            irq_cause = 5'd3;
        end else if (pending_enabled[7] && !mideleg[7] && (priv != M || mstatus[3])) begin
            irq_pending = 1;
            irq_cause = 5'd7;
        end else if (pending_enabled[9] && mideleg[9] &&
                     (priv == U || (priv == S && mstatus[1]))) begin
            irq_pending = 1;
            irq_cause = 5'd9;
        end else if (pending_enabled[1] && mideleg[1] &&
                     (priv == U || (priv == S && mstatus[1]))) begin
            irq_pending = 1;
            irq_cause = 5'd1;
        end else if (pending_enabled[5] && mideleg[5] &&
                     (priv == U || (priv == S && mstatus[1]))) begin
            irq_pending = 1;
            irq_cause = 5'd5;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priv <= M;
            mstatus <= 0;
            mie <= 0;
            medeleg <= 0;
            mideleg <= 0;
            software_mip <= 0;
            mcounteren <= 0;
            scounteren <= 0;
            mtvec <= 0;
            mscratch <= 0;
            mepc <= 0;
            mcause <= 0;
            mtval <= 0;
            stvec <= 0;
            sscratch <= 0;
            sepc <= 0;
            scause <= 0;
            stval <= 0;
            satp <= 0;
        end else if (trap_commit) begin
            if (delegate_trap) begin
                sepc <= {trap_pc[31:2], 2'b0};
                scause <= {trap_interrupt, 26'b0, trap_cause};
                stval <= trap_value;
                mstatus[5] <= mstatus[1];
                mstatus[1] <= 0;
                mstatus[8] <= priv == S;
                priv <= S;
            end else begin
                mepc <= {trap_pc[31:2], 2'b0};
                mcause <= {trap_interrupt, 26'b0, trap_cause};
                mtval <= trap_value;
                mstatus[7] <= mstatus[3];
                mstatus[3] <= 0;
                mstatus[12:11] <= priv;
                priv <= M;
            end
        end else if (mret_commit) begin
            priv <= mstatus[12:11];
            mstatus[3] <= mstatus[7];
            mstatus[7] <= 1;
            mstatus[12:11] <= U;
            mstatus[17] <= 0;
        end else if (sret_commit) begin
            priv <= mstatus[8] ? S : U;
            mstatus[1] <= mstatus[5];
            mstatus[5] <= 1;
            mstatus[8] <= 0;
        end else if (csr_commit && !csr_illegal && csr_op != 0) begin
            case (csr_addr)
                12'h100: mstatus <= (mstatus & ~sstatus_mask) | (modified_csr & sstatus_mask);
                12'h104: mie <= (mie & ~mideleg) | (modified_csr & mideleg);
                12'h106: scounteren <= modified_csr & 32'h0000_0002;
                12'h144: software_mip <= (software_mip & ~mideleg) |
                                            (modified_csr & mideleg & 32'h0000_0222);
                12'h105: stvec <= {modified_csr[31:2], 1'b0, modified_csr[0]};
                12'h140: sscratch <= modified_csr;
                12'h141: sepc <= {modified_csr[31:2], 2'b0};
                12'h142: scause <= modified_csr;
                12'h143: stval <= modified_csr;
                12'h180: satp <= modified_csr & 32'h803f_ffff;
                12'h300: mstatus <= (mstatus & ~writable_mstatus) |
                                       (modified_csr & writable_mstatus);
                12'h302: medeleg <= modified_csr & 32'h0000_b3ff;
                12'h303: mideleg <= modified_csr & 32'h0000_0222;
                12'h304: mie <= modified_csr & writable_mie;
                12'h306: mcounteren <= modified_csr & 32'h0000_0002;
                12'h344: software_mip <= modified_csr & 32'h0000_0222;
                12'h305: mtvec <= {modified_csr[31:2], 1'b0, modified_csr[0]};
                12'h340: mscratch <= modified_csr;
                12'h341: mepc <= {modified_csr[31:2], 2'b0};
                12'h342: mcause <= modified_csr;
                12'h343: mtval <= modified_csr;
                default: begin end
            endcase
        end
    end
endmodule
