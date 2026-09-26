`timescale 1ns/1ps
// RV32IM core with privileged trap handling and S-mode support.
// Diagnostic mode retains a simulation stop for faults and EBREAK.
module rv32i_core #(
    parameter [31:0] RESET_PC = 32'h8000_0000,
    parameter DIAGNOSTIC_MODE = 1
) (
    input wire clk, rst_n,
    input wire irq_timer, irq_software, irq_external,
    input wire irq_supervisor_external,
    input wire [63:0] time_value,
    output wire [1:0] current_privilege,
    output wire [31:0] current_satp,
    output wire [31:0] current_mstatus,
    output wire sfence_commit,
    output wire i_req_valid,
    input wire i_req_ready,
    output wire [31:0] i_req_addr,
    input wire i_resp_valid,
    output wire i_resp_ready,
    input wire [31:0] i_resp_data,
    input wire i_resp_err,
    input wire i_resp_page_fault,
    output wire d_req_valid,
    input wire d_req_ready,
    output wire [31:0] d_req_addr,
    output wire d_req_write,
    output wire [31:0] d_req_wdata,
    output wire [3:0] d_req_wstrb,
    input wire d_resp_valid,
    output wire d_resp_ready,
    input wire [31:0] d_resp_data,
    input wire d_resp_err,
    input wire d_resp_page_fault,
    output wire halted,
    output reg fault,
    output reg [31:0] fault_pc,
    output reg retire_valid,
    output reg [31:0] retire_pc
);
    localparam [3:0] FETCH_REQ = 4'd0, FETCH_RESP = 4'd1,
                     EXEC = 4'd2, DATA_REQ = 4'd3,
                     DATA_RESP = 4'd4, STOP = 4'd5,
                     AMO_WRITE_REQ = 4'd6, AMO_WRITE_RESP = 4'd7,
                     MDU_WAIT = 4'd8, READ_RS2 = 4'd9;
    reg [3:0] state;
    reg [31:0] pc, instr;
    // Four independently addressed eight-word banks leave x0 as a read bypass.
    // This partitions the 32:1 read selection and limits write-enable fanout.
    reg [31:0] regs_bank0 [0:7];
    reg [31:0] regs_bank1 [0:7];
    reg [31:0] regs_bank2 [0:7];
    reg [31:0] regs_bank3 [0:7];
    // Preserve the diagnostic testbench's logical-register hierarchy.
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] regs [0:31];
    /* verilator lint_on UNUSEDSIGNAL */
    genvar rf_index;
    generate for (rf_index = 0; rf_index < 32; rf_index = rf_index + 1) begin: rf_trace
        if (rf_index == 0) begin : zero
            assign regs[rf_index] = 32'b0;
        end else if (rf_index < 8) begin : bank0
            assign regs[rf_index] = regs_bank0[rf_index];
        end else if (rf_index < 16) begin : bank1
            assign regs[rf_index] = regs_bank1[rf_index-8];
        end else if (rf_index < 24) begin : bank2
            assign regs[rf_index] = regs_bank2[rf_index-16];
        end else begin : bank3
            assign regs[rf_index] = regs_bank3[rf_index-24];
        end
    end endgenerate
    reg [31:0] operand_a, operand_b;
    reg write_rd, access, store, illegal, stop_normal;
    wire [4:0] rd = instr[11:7];
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire [4:0] reg_read_index = state == FETCH_RESP ? i_resp_data[19:15] : rs2;
    wire [31:0] bank_read0 = regs_bank0[reg_read_index[2:0]];
    wire [31:0] bank_read1 = regs_bank1[reg_read_index[2:0]];
    wire [31:0] bank_read2 = regs_bank2[reg_read_index[2:0]];
    wire [31:0] bank_read3 = regs_bank3[reg_read_index[2:0]];
    wire [31:0] bank_read_data = reg_read_index[4:3] == 2'd0 ? bank_read0 :
                                 reg_read_index[4:3] == 2'd1 ? bank_read1 :
                                 reg_read_index[4:3] == 2'd2 ? bank_read2 : bank_read3;
    wire [31:0] reg_read_data = reg_read_index == 0 ? 32'b0 : bank_read_data;
    wire [31:0] a = operand_a;
    wire [31:0] b = operand_b;
    wire mdu_instruction = instr[6:0] == 7'b0110011 && funct7 == 7'b0000001;
    wire mdu_done;
    wire [31:0] mdu_result;
    rv32_mdu mdu (
        .clk(clk), .rst_n(rst_n),
        .start(state == EXEC && mdu_instruction && !illegal),
        .operation(funct3), .operand_a(a), .operand_b(b),
        .done(mdu_done), .result(mdu_result)
    );
    wire csr_instruction = instr[6:0] == 7'b1110011 && instr[14:12] != 0;
    wire [1:0] csr_op = !csr_instruction ? 2'd0 :
                        instr[13:12] == 2'b01 ? 2'd1 :
                        instr[13:12] == 2'b10 ? (rs1 == 0 ? 2'd0 : 2'd2) :
                        (rs1 == 0 ? 2'd0 : 2'd3);
    wire [31:0] csr_wdata = instr[14] ? {27'b0, rs1} : a;
    wire [31:0] csr_rdata, trap_vector, return_pc;
    wire csr_illegal, irq_pending;
    wire [4:0] irq_cause;
    wire mret_instruction = instr == 32'h3020_0073;
    wire sret_instruction = instr == 32'h1020_0073;
    wire ecall_instruction = instr == 32'h0000_0073;
    wire ebreak_instruction = instr == 32'h0010_0073;
    wire sfence_instruction = instr[31:25] == 7'b0001001 &&
                              instr[14:7] == 0 && instr[6:0] == 7'h73;
    wire csr_commit = state == EXEC && csr_instruction && !illegal && !csr_illegal;
    wire mret_commit = state == EXEC && mret_instruction && !illegal;
    wire sret_commit = state == EXEC && sret_instruction && !illegal;
    assign sfence_commit = state == EXEC && sfence_instruction && !illegal;
    reg trap_commit, trap_interrupt;
    reg [4:0] trap_cause;
    reg [31:0] trap_value;
    rv32_priv_unit priv_unit (
        .clk(clk), .rst_n(rst_n), .csr_addr(instr[31:20]),
        .csr_wdata(csr_wdata), .csr_op(csr_op), .csr_commit(csr_commit),
        .csr_rdata(csr_rdata), .csr_illegal(csr_illegal),
        .trap_commit(trap_commit), .trap_interrupt(trap_interrupt),
        .trap_cause(trap_cause), .trap_pc(pc), .trap_value(trap_value),
        .trap_vector(trap_vector),
        .mret_commit(mret_commit), .sret_commit(sret_commit),
        .return_pc(return_pc),
        .irq_timer(irq_timer), .irq_software(irq_software),
        .irq_external(irq_external), .time_value(time_value),
        .irq_supervisor_external(irq_supervisor_external),
        .irq_pending(irq_pending),
        .irq_cause(irq_cause), .privilege(current_privilege),
        .satp_value(current_satp), .mstatus_value(current_mstatus)
    );
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    // Reuse one datapath adder for base+offset, integer ADD/ADDI, and SUB.
    wire subtract = instr[6:0] == 7'b0110011 && funct3 == 3'b000 &&
                    funct7 == 7'b0100000;
    wire [31:0] add_rhs = instr[6:0] == 7'b0100011 ? imm_s :
                          (instr[6:0] == 7'b0000011 ||
                           instr[6:0] == 7'b1100111 ||
                           instr[6:0] == 7'b0010011) ? imm_i : b;
    wire [31:0] shared_add = a + (subtract ? ~add_rhs : add_rhs) + {31'b0, subtract};

    reg [31:0] next_pc, result, access_addr, store_data;
    reg [3:0] store_strb;
    reg [2:0] load_kind;
    reg [1:0] atomic_kind; // 0=ordinary, 1=LR, 2=SC, 3=AMO
    reg [1:0] atomic_kind_hold;
    reg [4:0] atomic_function_hold;
    reg [31:0] atomic_operand_hold, atomic_old, atomic_write_data;
    reg reservation_valid;
    reg [31:0] reservation_addr;
    reg branch_taken;
    reg [1:0] data_lane_hold;
    wire [7:0] selected_byte = d_resp_data[8*data_lane_hold +: 8];
    wire [15:0] selected_half = data_lane_hold[1] ? d_resp_data[31:16] : d_resp_data[15:0];
    reg [31:0] data_next_pc;
    reg [4:0] data_rd_hold;
    reg [2:0] data_load_kind;
    reg data_is_load;
    reg [31:0] access_addr_hold, store_data_hold;
    reg [3:0] store_strb_hold;

    assign i_req_valid = state == FETCH_REQ && rst_n &&
                         (DIAGNOSTIC_MODE || !irq_pending);
    assign i_req_addr = pc;
    assign i_resp_ready = state == FETCH_RESP;
    assign d_req_valid = state == DATA_REQ || state == AMO_WRITE_REQ;
    assign d_req_addr = access_addr_hold;
    assign d_req_write = state == AMO_WRITE_REQ || !data_is_load;
    assign d_req_wdata = state == AMO_WRITE_REQ ? atomic_write_data : store_data_hold;
    assign d_req_wstrb = state == AMO_WRITE_REQ ? 4'b1111 : store_strb_hold;
    assign d_resp_ready = state == DATA_RESP || state == AMO_WRITE_RESP;
    assign halted = state == STOP;

    always @* begin
        next_pc = pc + 32'd4;
        result = 0;
        write_rd = 0;
        access = 0;
        store = 0;
        illegal = 0;
        stop_normal = 0;
        access_addr = 0;
        store_data = 0;
        store_strb = 0;
        load_kind = funct3;
        atomic_kind = 0;
        branch_taken = 0;
        case (instr[6:0])
            7'b0110111: begin // LUI
                write_rd = 1;
                result = imm_u;
            end
            7'b0010111: begin // AUIPC
                write_rd = 1;
                result = pc + imm_u;
            end
            7'b1101111: begin // JAL
                write_rd = 1;
                result = pc + 32'd4;
                next_pc = pc + imm_j;
            end
            7'b1100111: begin // JALR
                if (funct3 != 0) illegal = 1;
                else begin
                    write_rd = 1;
                    result = pc + 32'd4;
                    next_pc = shared_add & 32'hffff_fffe;
                end
            end
            7'b1100011: begin // branches
                case (funct3)
                    3'b000: branch_taken = a == b;
                    3'b001: branch_taken = a != b;
                    3'b100: branch_taken = $signed(a) < $signed(b);
                    3'b101: branch_taken = $signed(a) >= $signed(b);
                    3'b110: branch_taken = a < b;
                    3'b111: branch_taken = a >= b;
                    default: illegal = 1;
                endcase
                if (branch_taken) next_pc = pc + imm_b;
            end
            7'b0000011: begin // loads
                access = 1;
                access_addr = shared_add;
                case (funct3)
                    3'b000, 3'b100: begin end // LB, LBU
                    3'b001, 3'b101: if (access_addr[0]) illegal = 1; // LH, LHU
                    3'b010: if (access_addr[1:0] != 0) illegal = 1; // LW
                    default: illegal = 1;
                endcase
            end
            7'b0100011: begin // stores
                access = 1;
                store = 1;
                access_addr = shared_add;
                case (funct3)
                    3'b000: store_strb = 4'b0001 << access_addr[1:0];
                    3'b001: begin
                        if (access_addr[0]) illegal = 1;
                        store_strb = 4'b0011 << access_addr[1:0];
                    end
                    3'b010: begin
                        if (access_addr[1:0] != 0) illegal = 1;
                        store_strb = 4'b1111;
                    end
                    default: illegal = 1;
                endcase
                store_data = b << {access_addr[1:0], 3'b000};
            end
            7'b0010011: begin // OP-IMM
                write_rd = 1;
                case (funct3)
                    3'b000: result = shared_add;
                    3'b010: result = $signed(a) < $signed(imm_i) ? 32'd1 : 32'd0;
                    3'b011: result = a < imm_i ? 32'd1 : 32'd0;
                    3'b100: result = a ^ imm_i;
                    3'b110: result = a | imm_i;
                    3'b111: result = a & imm_i;
                    3'b001: begin
                        if (funct7 != 0) illegal = 1;
                        result = a << instr[24:20];
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) result = a >> instr[24:20];
                        else if (funct7 == 7'b0100000) result = $signed(a) >>> instr[24:20];
                        else illegal = 1;
                    end
                endcase
            end
            7'b0110011: begin // OP
                write_rd = 1;
                if (funct7 == 7'b0000001) begin // RV32M
                    result = 0; // retired from the iterative MDU_WAIT state
                end else case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000 || funct7 == 7'b0100000)
                            result = shared_add;
                        else illegal = 1;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) result = a >> b[4:0];
                        else if (funct7 == 7'b0100000) result = $signed(a) >>> b[4:0];
                        else illegal = 1;
                    end
                    default: begin
                        if (funct7 != 0) illegal = 1;
                        case (funct3)
                            3'b001: result = a << b[4:0];
                            3'b010: result = $signed(a) < $signed(b) ? 32'd1 : 32'd0;
                            3'b011: result = a < b ? 32'd1 : 32'd0;
                            3'b100: result = a ^ b;
                            3'b110: result = a | b;
                            3'b111: result = a & b;
                            default: illegal = 1;
                        endcase
                    end
                endcase
            end
            7'b0101111: begin // RV32A word operations
                access = 1;
                access_addr = a;
                store_strb = 4'b1111;
                store_data = b;
                if (funct3 != 3'b010 || a[1:0] != 0) illegal = 1;
                case (instr[31:27])
                    5'b00010: begin // LR.W
                        atomic_kind = 1;
                        if (rs2 != 0) illegal = 1;
                    end
                    5'b00011: begin // SC.W
                        atomic_kind = 2;
                        store = 1;
                    end
                    5'b00000, 5'b00001, 5'b00100, 5'b01000,
                    5'b01100, 5'b10000, 5'b10100, 5'b11000,
                    5'b11100: begin
                        atomic_kind = 3;
                        store = 1;
                    end
                    default: illegal = 1;
                endcase
            end
            7'b0001111: begin // FENCE/FENCE.I; no instruction cache yet.
                if (funct3 != 3'b000 && funct3 != 3'b001) illegal = 1;
            end
            7'b1110011: begin
                if (csr_instruction) begin
                    if (funct3 == 3'b100 || csr_illegal) illegal = 1;
                    else begin
                        write_rd = 1;
                        result = csr_rdata;
                    end
                end else if (ebreak_instruction) begin
                    if (DIAGNOSTIC_MODE) stop_normal = 1;
                end else if (ecall_instruction || mret_instruction ||
                             sret_instruction || sfence_instruction ||
                             instr == 32'h1050_0073) begin
                    if (mret_instruction && current_privilege != 2'd3) illegal = 1;
                    if (sret_instruction && current_privilege == 2'd0) illegal = 1;
                    if (sret_instruction && current_privilege == 2'd1 && current_mstatus[22]) illegal = 1;
                    if (sfence_instruction && (current_privilege == 2'd0 ||
                        (current_privilege == 2'd1 && current_mstatus[20]))) illegal = 1;
                    if (instr == 32'h1050_0073 && current_privilege != 2'd3 && current_mstatus[21]) illegal = 1;
                end else illegal = 1;
            end
            default: illegal = 1;
        endcase
    end

    always @* begin
        trap_commit = state == STOP && !DIAGNOSTIC_MODE;
        trap_interrupt = 0;
        trap_cause = 0;
        trap_value = 0;
        if (!DIAGNOSTIC_MODE) begin
            if (state == FETCH_REQ && irq_pending) begin
                trap_commit = 1;
                trap_interrupt = 1;
                trap_cause = irq_cause;
            end else if (state == FETCH_RESP && i_resp_valid && i_resp_ready && i_resp_err) begin
                trap_commit = 1;
                trap_cause = i_resp_page_fault === 1'b1 ? 5'd12 : 5'd1;
                trap_value = pc;
            end else if (state == EXEC) begin
                if (illegal) begin
                    trap_commit = 1;
                    trap_cause = 5'd2;
                    trap_value = instr;
                    if (access && ((funct3 == 3'b010 && access_addr[1:0] != 0) ||
                                   ((funct3 == 3'b001 || funct3 == 3'b101) && access_addr[0]))) begin
                        trap_cause = store ? 5'd6 : 5'd4;
                        trap_value = access_addr;
                    end
                end else if (next_pc[1:0] != 0) begin
                    trap_commit = 1;
                    trap_cause = 5'd0;
                    trap_value = next_pc;
                end else if (ebreak_instruction) begin
                    trap_commit = 1;
                    trap_cause = 5'd3;
                end else if (ecall_instruction) begin
                    trap_commit = 1;
                    trap_cause = current_privilege == 2'd3 ? 5'd11 :
                                 current_privilege == 2'd1 ? 5'd9 : 5'd8;
                end
            end else if ((state == DATA_RESP || state == AMO_WRITE_RESP) &&
                         d_resp_valid && d_resp_ready && d_resp_err) begin
                trap_commit = 1;
                trap_cause = d_resp_page_fault === 1'b1 ?
                             (data_is_load && atomic_kind_hold != 3 ? 5'd13 : 5'd15) :
                             (data_is_load && atomic_kind_hold != 3 ? 5'd5 : 5'd7);
                trap_value = access_addr_hold;
            end
        end
    end

    reg reg_write_enable;
    reg [4:0] reg_write_index;
    reg [31:0] reg_write_data;
    always @* begin
        reg_write_enable = 0;
        reg_write_index = 0;
        reg_write_data = 0;
        if (state == EXEC && !illegal && next_pc[1:0] == 0 &&
            !trap_commit && !stop_normal) begin
            reg_write_index = rd;
            if (access && atomic_kind == 2 &&
                (!reservation_valid || reservation_addr != access_addr)) begin
                reg_write_enable = 1;
                reg_write_data = 1;
            end else if (!access && !mdu_instruction && write_rd) begin
                reg_write_enable = 1;
                reg_write_data = result;
            end
        end else if (state == DATA_RESP && d_resp_valid && d_resp_ready &&
                     !d_resp_err && atomic_kind_hold != 3) begin
            reg_write_index = data_rd_hold;
            if (atomic_kind_hold == 2) begin
                reg_write_enable = 1;
                reg_write_data = 0;
            end else if (data_is_load) begin
                reg_write_enable = 1;
                case (data_load_kind)
                    3'b000: reg_write_data = {{24{selected_byte[7]}}, selected_byte};
                    3'b001: reg_write_data = {{16{selected_half[15]}}, selected_half};
                    3'b010: reg_write_data = d_resp_data;
                    3'b100: reg_write_data = {24'b0, selected_byte};
                    3'b101: reg_write_data = {16'b0, selected_half};
                    default: reg_write_data = 0;
                endcase
            end
        end else if (state == AMO_WRITE_RESP && d_resp_valid &&
                     d_resp_ready && !d_resp_err) begin
            reg_write_enable = 1;
            reg_write_index = data_rd_hold;
            reg_write_data = atomic_old;
        end else if (state == MDU_WAIT && mdu_done) begin
            reg_write_enable = 1;
            reg_write_index = data_rd_hold;
            reg_write_data = mdu_result;
        end
    end
    always @(posedge clk) if (reg_write_enable && reg_write_index != 0)
        case (reg_write_index[4:3])
            2'd0: regs_bank0[reg_write_index[2:0]] <= reg_write_data;
            2'd1: regs_bank1[reg_write_index[2:0]] <= reg_write_data;
            2'd2: regs_bank2[reg_write_index[2:0]] <= reg_write_data;
            2'd3: regs_bank3[reg_write_index[2:0]] <= reg_write_data;
        endcase

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= FETCH_REQ;
            pc <= RESET_PC;
            instr <= 0;
            operand_a <= 0;
            operand_b <= 0;
            fault <= 0;
            fault_pc <= 0;
            retire_valid <= 0;
            retire_pc <= 0;
            access_addr_hold <= 0;
            store_data_hold <= 0;
            store_strb_hold <= 0;
            data_lane_hold <= 0;
            data_next_pc <= 0;
            data_rd_hold <= 0;
            data_load_kind <= 0;
            data_is_load <= 0;
            atomic_kind_hold <= 0;
            atomic_function_hold <= 0;
            atomic_operand_hold <= 0;
            atomic_old <= 0;
            atomic_write_data <= 0;
            reservation_valid <= 0;
            reservation_addr <= 0;
            // RISC-V does not define general-register contents after reset.
            // x0 is hardwired by the read bypass and never written.
        end else begin
            retire_valid <= 0;
            case (state)
                FETCH_REQ: if (trap_commit) begin
                    pc <= trap_vector;
                    state <= FETCH_REQ;
                end else if (i_req_valid && i_req_ready) state <= FETCH_RESP;
                FETCH_RESP: if (i_resp_valid && i_resp_ready) begin
                    if (i_resp_err) begin
                        if (DIAGNOSTIC_MODE) begin
                            fault <= 1;
                            fault_pc <= pc;
                            state <= STOP;
                        end else begin
                            pc <= trap_vector;
                            state <= FETCH_REQ;
                        end
                    end else begin
                        instr <= i_resp_data;
                        operand_a <= reg_read_data;
                        state <= READ_RS2;
                    end
                end
                READ_RS2: begin
                    operand_b <= reg_read_data;
                    state <= EXEC;
                end
                EXEC: begin
                    if (illegal || next_pc[1:0] != 0) begin
                        if (DIAGNOSTIC_MODE) begin
                            fault <= 1;
                            fault_pc <= pc;
                            state <= STOP;
                        end else begin
                            pc <= trap_vector;
                            state <= FETCH_REQ;
                        end
                    end else if (trap_commit) begin
                        pc <= trap_vector;
                        state <= FETCH_REQ;
                    end else if (stop_normal) begin
                        retire_valid <= 1;
                        retire_pc <= pc;
                        state <= STOP;
                    end else if (access && atomic_kind == 2 &&
                                 (!reservation_valid || reservation_addr != access_addr)) begin
                        reservation_valid <= 0;
                        retire_valid <= 1;
                        retire_pc <= pc;
                        pc <= next_pc;
                        state <= FETCH_REQ;
                    end else if (mdu_instruction) begin
                        data_rd_hold <= rd;
                        data_next_pc <= next_pc;
                        state <= MDU_WAIT;
                    end else if (access) begin
                        access_addr_hold <= access_addr;
                        store_data_hold <= store_data;
                        store_strb_hold <= store_strb;
                        data_lane_hold <= access_addr[1:0];
                        data_next_pc <= next_pc;
                        data_rd_hold <= rd;
                        data_load_kind <= load_kind;
                        data_is_load <= !store || atomic_kind == 3;
                        atomic_kind_hold <= atomic_kind;
                        atomic_function_hold <= instr[31:27];
                        atomic_operand_hold <= b;
                        if (store) reservation_valid <= 0;
                        state <= DATA_REQ;
                    end else begin
                        retire_valid <= 1;
                        retire_pc <= pc;
                        pc <= (mret_instruction || sret_instruction) ? return_pc : next_pc;
                        state <= FETCH_REQ;
                    end
                end
                DATA_REQ: if (d_req_valid && d_req_ready) state <= DATA_RESP;
                DATA_RESP: if (d_resp_valid && d_resp_ready) begin
                    if (d_resp_err) begin
                        if (DIAGNOSTIC_MODE) begin
                            fault <= 1;
                            fault_pc <= pc;
                            state <= STOP;
                        end else begin
                            pc <= trap_vector;
                            state <= FETCH_REQ;
                        end
                    end else begin
                        if (atomic_kind_hold == 1) begin
                            reservation_valid <= 1;
                            reservation_addr <= access_addr_hold;
                        end
                        if (atomic_kind_hold == 3) begin
                            atomic_old <= d_resp_data;
                            case (atomic_function_hold)
                                5'b00000: atomic_write_data <= d_resp_data + atomic_operand_hold;
                                5'b00001: atomic_write_data <= atomic_operand_hold;
                                5'b00100: atomic_write_data <= d_resp_data ^ atomic_operand_hold;
                                5'b01000: atomic_write_data <= d_resp_data | atomic_operand_hold;
                                5'b01100: atomic_write_data <= d_resp_data & atomic_operand_hold;
                                5'b10000: atomic_write_data <= $signed(d_resp_data) < $signed(atomic_operand_hold) ? d_resp_data : atomic_operand_hold;
                                5'b10100: atomic_write_data <= $signed(d_resp_data) > $signed(atomic_operand_hold) ? d_resp_data : atomic_operand_hold;
                                5'b11000: atomic_write_data <= d_resp_data < atomic_operand_hold ? d_resp_data : atomic_operand_hold;
                                5'b11100: atomic_write_data <= d_resp_data > atomic_operand_hold ? d_resp_data : atomic_operand_hold;
                                default: atomic_write_data <= d_resp_data;
                            endcase
                            state <= AMO_WRITE_REQ;
                        end else begin
                        retire_valid <= 1;
                        retire_pc <= pc;
                        pc <= data_next_pc;
                        state <= FETCH_REQ;
                        end
                    end
                end
                AMO_WRITE_REQ: if (d_req_valid && d_req_ready) state <= AMO_WRITE_RESP;
                AMO_WRITE_RESP: if (d_resp_valid && d_resp_ready) begin
                    if (d_resp_err) begin
                        if (DIAGNOSTIC_MODE) begin
                            fault <= 1;
                            fault_pc <= pc;
                            state <= STOP;
                        end else begin
                            pc <= trap_vector;
                            state <= FETCH_REQ;
                        end
                    end else begin
                        retire_valid <= 1;
                        retire_pc <= pc;
                        pc <= data_next_pc;
                        state <= FETCH_REQ;
                    end
                end
                MDU_WAIT: if (mdu_done) begin
                    retire_valid <= 1;
                    retire_pc <= pc;
                    pc <= data_next_pc;
                    state <= FETCH_REQ;
                end
                default: begin end
            endcase
        end
    end
endmodule
