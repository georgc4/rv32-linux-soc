`timescale 1ns/1ps
// Iterative RV32M unit built around one 34-bit adder and one 65-bit
// {hi, lo} shift register.
//   Multiply: radix-2 signed/unsigned shift-add. lo holds the multiplier
//             and receives product bits as it shifts out; hi accumulates.
//             MULH's negative multiplier MSB is handled by subtracting on
//             the last step, so no post-correction is needed.
//   Divide:   restoring division on magnitudes. lo holds the dividend and
//             collects quotient bits; hi holds the partial remainder.
//             Operand magnitudes and result signs are applied by running
//             the same adder as 0 - x in optional pre/post steps.
// The result is read from hi/lo, so there is no separate result register.
module rv32_mdu (
    input wire clk, rst_n,
    input wire start,
    input wire [2:0] operation,
    input wire [31:0] operand_a, operand_b,
    output reg done,
    output wire [31:0] result
);
    localparam [2:0] IDLE = 3'd0, NEG_A = 3'd1, NEG_B = 3'd2,
                     ITER = 3'd3, NEG_Q = 3'd4, NEG_R = 3'd5;
    reg [2:0] phase;
    reg [2:0] op;
    reg [4:0] count;
    reg [32:0] hi;
    reg [31:0] lo, m;
    reg neg_quotient, neg_remainder;

    wire division = op[2];
    wire signed_div = !op[0];                   // DIV, REM
    wire m_signed = op == 3'd1 || op == 3'd2;   // MULH, MULHSU: rs1 signed
    wire last_iter = count == 5'd31;

    // Shared adder: x + (subtract ? ~y : y) + subtract, 34 bits wide.
    reg [33:0] add_x, add_y;
    reg subtract;
    always @* begin
        add_x = 34'b0;
        add_y = 34'b0;
        subtract = 1'b1;
        case (phase)
            NEG_A, NEG_Q: add_y = {2'b0, lo};
            NEG_B: add_y = {2'b0, m};
            NEG_R: add_y = {2'b0, hi[31:0]};
            default: if (division) begin
                add_x = {1'b0, hi[31:0], lo[31]};
                add_y = {2'b0, m};
            end else begin
                add_x = {hi[32], hi};
                add_y = lo[0] ? {{2{m_signed && m[31]}}, m} : 34'b0;
                subtract = lo[0] && last_iter && op == 3'd1;
            end
        endcase
    end
    wire [33:0] sum = add_x + (subtract ? ~add_y : add_y) + {33'b0, subtract};
    wire div_ge = !sum[33];

    assign result = division ? (op[1] ? hi[31:0] : lo) :
                    (op == 3'd0 ? lo : hi[31:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= IDLE;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (phase)
            IDLE: if (start) begin
                count <= 5'd0;
                op <= operation;
                hi <= 33'b0;
                m <= operand_a;
                lo <= operand_b;
                neg_quotient <= 1'b0;
                neg_remainder <= 1'b0;
                if (operation[2]) begin
                    // Dividend in lo, divisor in m.
                    m <= operand_b;
                    lo <= operand_a;
                    if (!operation[0]) begin
                        neg_quotient <= (operand_a[31] ^ operand_b[31]) &&
                                        operand_b != 32'b0;
                        neg_remainder <= operand_a[31];
                    end
                    phase <= !operation[0] && operand_a[31] ? NEG_A :
                             !operation[0] && operand_b[31] ? NEG_B : ITER;
                end else phase <= ITER;
            end
            NEG_A: begin
                lo <= sum[31:0];
                phase <= signed_div && m[31] ? NEG_B : ITER;
            end
            NEG_B: begin
                m <= sum[31:0];
                phase <= ITER;
            end
            ITER: begin
                count <= count + 5'd1;
                if (division) begin
                    hi <= {1'b0, div_ge ? sum[31:0] : add_x[31:0]};
                    lo <= {lo[30:0], div_ge};
                end else begin
                    hi <= sum[33:1];
                    lo <= {sum[0], lo[31:1]};
                end
                if (last_iter) begin
                    if (division && neg_quotient && !op[1]) phase <= NEG_Q;
                    else if (division && neg_remainder && op[1]) phase <= NEG_R;
                    else begin
                        phase <= IDLE;
                        done <= 1'b1;
                    end
                end
            end
            NEG_Q: begin
                lo <= sum[31:0];
                phase <= IDLE;
                done <= 1'b1;
            end
            NEG_R: begin
                hi <= {1'b0, sum[31:0]};
                phase <= IDLE;
                done <= 1'b1;
            end
            default: phase <= IDLE;
            endcase
        end
    end
endmodule
