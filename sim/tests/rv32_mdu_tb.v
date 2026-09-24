`timescale 1ns/1ps
module rv32_mdu_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, start = 0;
    reg [2:0] operation = 0;
    reg [31:0] operand_a = 0, operand_b = 0;
    wire done;
    wire [31:0] result;
    reg [31:0] vectors [0:7];
    reg signed [63:0] signed_a, signed_b, positive_b;
    reg signed [63:0] product_ss, product_su;
    reg [63:0] product_uu;
    reg [31:0] expected, signed_quotient, signed_remainder;
    integer i, j, op, checks = 0, cycles;
    rv32_mdu dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .operation(operation), .operand_a(operand_a), .operand_b(operand_b),
        .done(done), .result(result)
    );
    task check;
        input [2:0] kind;
        input [31:0] a, b;
        begin
            signed_a = {{32{a[31]}}, a};
            signed_b = {{32{b[31]}}, b};
            positive_b = {32'b0, b};
            product_ss = signed_a * signed_b;
            product_su = signed_a * positive_b;
            product_uu = {32'b0, a} * {32'b0, b};
            signed_quotient = b == 0 ? 0 : $signed(a) / $signed(b);
            signed_remainder = b == 0 ? 0 : $signed(a) % $signed(b);
            if (b == 0) begin
                signed_quotient = 32'hffff_ffff;
                signed_remainder = a;
            end else if (a == 32'h8000_0000 && b == 32'hffff_ffff) begin
                signed_quotient = a;
                signed_remainder = 0;
            end
            case (kind)
                0: expected = product_uu[31:0];
                1: expected = product_ss[63:32];
                2: expected = product_su[63:32];
                3: expected = product_uu[63:32];
                4: expected = signed_quotient;
                5: expected = b == 0 ? 32'hffff_ffff : a / b;
                6: expected = signed_remainder;
                7: expected = b == 0 ? a : a % b;
            endcase
            @(negedge clk);
            operation = kind; operand_a = a; operand_b = b; start = 1;
            @(negedge clk); start = 0;
            cycles = 0;
            while (!done && cycles < 40) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (!done || result !== expected)
                $fatal(1, "MDU op=%d a=%h b=%h got=%h expected=%h cycles=%d",
                       kind, a, b, result, expected, cycles);
            checks = checks + 1;
        end
    endtask
    initial begin
        vectors[0] = 0;
        vectors[1] = 1;
        vectors[2] = 2;
        vectors[3] = 32'hffff_ffff;
        vectors[4] = 32'h8000_0000;
        vectors[5] = 32'h7fff_ffff;
        vectors[6] = 32'h1234_5678;
        vectors[7] = 32'hcafe_beef;
        repeat (3) @(negedge clk);
        rst_n = 1;
        for (op = 0; op < 8; op = op + 1)
            for (i = 0; i < 8; i = i + 1)
                for (j = 0; j < 8; j = j + 1)
                    check(op[2:0], vectors[i], vectors[j]);
        $display("PASS rv32_mdu: %0d edge/vector arithmetic checks", checks);
        $finish;
    end
endmodule
