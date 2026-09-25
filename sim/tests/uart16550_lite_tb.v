`timescale 1ns/1ps
module uart16550_lite_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, req_valid = 0, req_write = 0, resp_ready = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    reg [3:0] req_wstrb = 0;
    reg rx_pin = 1;
    wire req_ready, resp_valid, resp_err, tx_pin, irq;
    wire [31:0] resp_rdata;
    integer bit_index, count;
    uart16550_lite #(.RESET_DIVISOR(1)) dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_ready(req_ready), .req_addr(req_addr),
        .req_write(req_write), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .resp_valid(resp_valid), .resp_ready(resp_ready),
        .resp_rdata(resp_rdata), .resp_err(resp_err),
        .rx_pin(rx_pin), .tx_pin(tx_pin), .irq(irq)
    );
    task transaction;
        input [31:0] addr, data;
        input wr;
        output [31:0] read_back;
        begin
            @(negedge clk);
            req_addr = addr;
            req_wdata = data;
            req_write = wr;
            req_wstrb = wr ? 4'b0001 : 4'b0000;
            req_valid = 1;
            count = 0;
            while (!req_ready && count < 300) begin
                @(negedge clk);
                count = count + 1;
            end
            if (!req_ready) $fatal(1, "UART request timeout");
            @(negedge clk);
            req_valid = 0;
            while (!resp_valid && count < 300) begin
                @(negedge clk);
                count = count + 1;
            end
            if (!resp_valid || resp_err) $fatal(1, "UART response error");
            read_back = resp_rdata;
            resp_ready = 1;
            @(negedge clk);
            resp_ready = 0;
        end
    endtask
    reg [31:0] read_back;
    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        transaction(4, 1, 1, read_back); // IER: RX data interrupt
        @(negedge clk);
        rx_pin = 0;
        repeat (16) @(negedge clk);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            rx_pin = (8'h41 >> bit_index) & 1;
            repeat (16) @(negedge clk);
        end
        rx_pin = 1;
        repeat (28) @(negedge clk);
        if (!irq) $fatal(1, "UART RX interrupt missing");
        transaction(20, 0, 0, read_back); // LSR
        if (!read_back[0]) $fatal(1, "UART RX ready missing");
        transaction(0, 0, 0, read_back); // RBR clears RX ready
        if (read_back[7:0] !== 8'h41 || irq)
            $fatal(1, "UART RX mismatch byte=%h irq=%b", read_back[7:0], irq);

        transaction(4, 2, 1, read_back); // Enable THRE interrupt while idle
        if (!irq) $fatal(1, "UART initial THRE interrupt missing");
        transaction(8, 0, 0, read_back); // IIR reports and acknowledges THRE
        if (read_back[7:0] !== 8'h02 || irq)
            $fatal(1, "UART THRE IIR acknowledgement failed iir=%h irq=%b",
                   read_back[7:0], irq);
        transaction(8, 0, 0, read_back);
        if (read_back[7:0] !== 8'h01 || irq)
            $fatal(1, "UART THRE interrupt reasserted without a new event");
        transaction(0, 8'h5a, 1, read_back); // THR write starts a transmission
        if (irq) $fatal(1, "UART THRE interrupt asserted while transmitting");
        repeat (200) @(negedge clk);
        if (!irq) $fatal(1, "UART THRE interrupt missing after transmission");
        transaction(8, 0, 0, read_back);
        if (read_back[7:0] !== 8'h02 || irq)
            $fatal(1, "UART completed THRE interrupt did not clear");

        transaction(4, 0, 1, read_back); // Disabling IER clears pending THRE
        transaction(4, 2, 1, read_back);
        if (!irq) $fatal(1, "UART THRE interrupt missing after re-enable");
        transaction(0, 8'h33, 1, read_back); // THR write also acknowledges THRE
        if (irq) $fatal(1, "UART THR write did not clear THRE interrupt");
        $display("PASS uart16550_lite: serial RX and acknowledged THRE IRQ");
        $finish;
    end
endmodule
