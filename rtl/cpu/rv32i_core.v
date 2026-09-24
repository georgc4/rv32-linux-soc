`timescale 1ns/1ps
// Original RV32IM diagnostic core. Privilege/MMU are still in progress.
// Faults and EBREAK stop the core for simulation; architectural traps follow later.
module rv32i_core #(
    parameter [31:0] RESET_PC = 32'h8000_0000
) (
    input wire clk, rst_n,
    output wire i_req_valid,
    input wire i_req_ready,
    output wire [31:0] i_req_addr,
    input wire i_resp_valid,
    output wire i_resp_ready,
    input wire [31:0] i_resp_data,
    input wire i_resp_err,
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
    output wire halted,
    output reg fault,
    output reg [31:0] fault_pc,
    output reg retire_valid,
    output reg [31:0] retire_pc
);
    localparam [2:0] FETCH_REQ = 3'd0, FETCH_RESP = 3'd1,
                     EXEC = 3'd2, DATA_REQ = 3'd3,
                     DATA_RESP = 3'd4, STOP = 3'd5;
    reg [2:0] state;
    reg [31:0] pc, instr;
    reg [31:0] regs [0:31];
    wire [4:0] rd = instr[11:7];
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire [31:0] a = rs1 == 0 ? 32'b0 : regs[rs1];
    wire [31:0] b = rs2 == 0 ? 32'b0 : regs[rs2];
    wire signed [63:0] signed_a = {{32{a[31]}}, a};
    wire signed [63:0] signed_b = {{32{b[31]}}, b};
    wire signed [63:0] unsigned_b_signed = {32'b0, b};
    wire signed [63:0] product_ss = signed_a * signed_b;
    wire signed [63:0] product_su = signed_a * unsigned_b_signed;
    wire [63:0] product_uu = {32'b0, a} * {32'b0, b};
    wire unused_products = &{1'b0, product_ss[31:0], product_su[31:0]};
    wire [31:0] signed_quotient = $signed(a) / $signed(b);
    wire [31:0] signed_remainder = $signed(a) % $signed(b);
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    reg [31:0] next_pc, result, access_addr, store_data;
    reg [3:0] store_strb;
    reg write_rd, access, store, illegal, stop_normal;
    reg [2:0] load_kind;
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

    assign i_req_valid = state == FETCH_REQ && rst_n;
    assign i_req_addr = pc;
    assign i_resp_ready = state == FETCH_RESP;
    assign d_req_valid = state == DATA_REQ;
    assign d_req_addr = access_addr_hold;
    assign d_req_write = !data_is_load;
    assign d_req_wdata = store_data_hold;
    assign d_req_wstrb = store_strb_hold;
    assign d_resp_ready = state == DATA_RESP;
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
                    next_pc = (a + imm_i) & 32'hffff_fffe;
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
                access_addr = a + imm_i;
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
                access_addr = a + imm_s;
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
                    3'b000: result = a + imm_i;
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
                    case (funct3)
                        3'b000: result = product_uu[31:0];
                        3'b001: result = product_ss[63:32];
                        3'b010: result = product_su[63:32];
                        3'b011: result = product_uu[63:32];
                        3'b100: result = b == 0 ? 32'hffff_ffff :
                            (a == 32'h8000_0000 && b == 32'hffff_ffff) ? a :
                            signed_quotient;
                        3'b101: result = b == 0 ? 32'hffff_ffff : a / b;
                        3'b110: result = b == 0 ? a :
                            (a == 32'h8000_0000 && b == 32'hffff_ffff) ? 32'b0 :
                            signed_remainder;
                        3'b111: result = b == 0 ? a : a % b;
                    endcase
                end else case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) result = a + b;
                        else if (funct7 == 7'b0100000) result = a - b;
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
            7'b0001111: begin // FENCE; serialized bus makes this a no-op.
                if (funct3 != 3'b000) illegal = 1;
            end
            7'b1110011: begin // Diagnostic EBREAK only.
                if (instr == 32'h0010_0073) stop_normal = 1;
                else illegal = 1;
            end
            default: illegal = 1;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= FETCH_REQ;
            pc <= RESET_PC;
            instr <= 0;
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
            // RISC-V does not define general-register contents after reset.
            // x0 is hardwired by the read bypass and never written.
        end else begin
            retire_valid <= 0;
            case (state)
                FETCH_REQ: if (i_req_valid && i_req_ready) state <= FETCH_RESP;
                FETCH_RESP: if (i_resp_valid && i_resp_ready) begin
                    if (i_resp_err) begin
                        fault <= 1;
                        fault_pc <= pc;
                        state <= STOP;
                    end else begin
                        instr <= i_resp_data;
                        state <= EXEC;
                    end
                end
                EXEC: begin
                    if (illegal || next_pc[1:0] != 0) begin
                        fault <= 1;
                        fault_pc <= pc;
                        state <= STOP;
                    end else if (stop_normal) begin
                        retire_valid <= 1;
                        retire_pc <= pc;
                        state <= STOP;
                    end else if (access) begin
                        access_addr_hold <= access_addr;
                        store_data_hold <= store_data;
                        store_strb_hold <= store_strb;
                        data_lane_hold <= access_addr[1:0];
                        data_next_pc <= next_pc;
                        data_rd_hold <= rd;
                        data_load_kind <= load_kind;
                        data_is_load <= !store;
                        state <= DATA_REQ;
                    end else begin
                        if (write_rd && rd != 0) regs[rd] <= result;
                        retire_valid <= 1;
                        retire_pc <= pc;
                        pc <= next_pc;
                        state <= FETCH_REQ;
                    end
                end
                DATA_REQ: if (d_req_valid && d_req_ready) state <= DATA_RESP;
                DATA_RESP: if (d_resp_valid && d_resp_ready) begin
                    if (d_resp_err) begin
                        fault <= 1;
                        fault_pc <= pc;
                        state <= STOP;
                    end else begin
                        if (data_is_load && data_rd_hold != 0) begin
                            case (data_load_kind)
                                3'b000: regs[data_rd_hold] <= {{24{selected_byte[7]}}, selected_byte};
                                3'b001: regs[data_rd_hold] <= {{16{selected_half[15]}}, selected_half};
                                3'b010: regs[data_rd_hold] <= d_resp_data;
                                3'b100: regs[data_rd_hold] <= {24'b0, selected_byte};
                                3'b101: regs[data_rd_hold] <= {16'b0, selected_half};
                                default: regs[data_rd_hold] <= 0;
                            endcase
                        end
                        retire_valid <= 1;
                        retire_pc <= pc;
                        pc <= data_next_pc;
                        state <= FETCH_REQ;
                    end
                end
                default: begin end
            endcase
        end
    end
endmodule
