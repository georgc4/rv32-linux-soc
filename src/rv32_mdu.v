`timescale 1ns/1ps
// 32-step RV32M multiply/divide unit. One 64-bit add path for multiplication
// and one 33-bit subtract/compare path for division keep area bounded.
module rv32_mdu (
    input wire clk, rst_n,
    input wire start,
    input wire [2:0] operation,
    input wire [31:0] operand_a, operand_b,
    output reg done,
    output reg [31:0] result
);
    reg active, division;
    reg [2:0] op;
    reg [5:0] count;
    reg [31:0] original_a, original_b;
    reg sign_a, sign_b;
    reg [63:0] accumulator, multiplicand;
    reg [31:0] multiplier;
    reg [31:0] quotient, divisor;
    reg [31:0] remainder;
    wire [63:0] mul_next = accumulator + (multiplier[0] ? multiplicand : 64'b0);
    wire [31:0] mul_high_ss = mul_next[63:32] -
                                (sign_a ? original_b : 32'b0) -
                                (sign_b ? original_a : 32'b0);
    wire [31:0] mul_high_su = mul_next[63:32] -
                                (sign_a ? original_b : 32'b0);
    wire [32:0] div_trial = {remainder, quotient[31]};
    wire div_ge = div_trial >= {1'b0, divisor};
    wire [32:0] div_remainder_full = div_ge ?
                                    div_trial - {1'b0, divisor} : div_trial;
    wire [31:0] div_remainder_next = div_remainder_full[31:0];
    wire unused_div_high = &{1'b0, div_remainder_full[32]};
    wire [31:0] div_quotient_next = {quotient[30:0], div_ge};
    wire [31:0] abs_a = (operation == 3'd4 || operation == 3'd6) && operand_a[31] ?
                        -operand_a : operand_a;
    wire [31:0] abs_b = (operation == 3'd4 || operation == 3'd6) && operand_b[31] ?
                        -operand_b : operand_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 0;
            division <= 0;
            op <= 0;
            count <= 0;
            original_a <= 0;
            original_b <= 0;
            sign_a <= 0;
            sign_b <= 0;
            accumulator <= 0;
            multiplicand <= 0;
            multiplier <= 0;
            quotient <= 0;
            divisor <= 0;
            remainder <= 0;
            done <= 0;
            result <= 0;
        end else begin
            done <= 0;
            if (start && !active) begin
                op <= operation;
                count <= 0;
                original_a <= operand_a;
                original_b <= operand_b;
                sign_a <= operand_a[31];
                sign_b <= operand_b[31];
                division <= operation[2];
                accumulator <= 0;
                multiplicand <= {32'b0, operand_a};
                multiplier <= operand_b;
                quotient <= abs_a;
                divisor <= abs_b;
                remainder <= 0;
                if (operation[2] && operand_b == 0) begin
                    result <= operation[1] ? operand_a : 32'hffff_ffff;
                    done <= 1;
                    active <= 0;
                end else active <= 1;
            end else if (active) begin
                count <= count + 1;
                if (division) begin
                    quotient <= div_quotient_next;
                    remainder <= div_remainder_next;
                    if (count == 6'd31) begin
                        result <= op[1] ?
                                  (op == 3'd6 && sign_a ? -div_remainder_next : div_remainder_next) :
                                  (op == 3'd4 && (sign_a ^ sign_b) ? -div_quotient_next : div_quotient_next);
                        active <= 0;
                        done <= 1;
                    end
                end else begin
                    accumulator <= mul_next;
                    multiplicand <= multiplicand << 1;
                    multiplier <= multiplier >> 1;
                    if (count == 6'd31) begin
                        case (op)
                            3'd0: result <= mul_next[31:0];
                            3'd1: result <= mul_high_ss;
                            3'd2: result <= mul_high_su;
                            3'd3: result <= mul_next[63:32];
                            default: result <= 0;
                        endcase
                        active <= 0;
                        done <= 1;
                    end
                end
            end
        end
    end
endmodule
