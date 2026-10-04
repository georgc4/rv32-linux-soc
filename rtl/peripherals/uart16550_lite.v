`timescale 1ns/1ps
// Single-byte, 16550 register subset with 32-bit-spaced byte registers.
// No FIFO, modem control, break generation, parity, or flow control.
module uart16550_lite #(
    parameter [15:0] RESET_DIVISOR = 16'd11
) (
    input wire clk, rst_n,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire req_write,
    input wire [31:0] req_wdata,
    input wire [3:0] req_wstrb,
    output wire resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_rdata,
    output reg resp_err,
    input wire rx_pin,
    output reg tx_pin,
    output wire irq
);
    reg pending;
    reg [7:0] ier, lcr, mcr, scr;
    reg [7:0] dll, dlm;
    reg [7:0] rx_data, rx_shift;
    reg rx_valid, rx_overrun;
    reg tx_irq_pending;
    reg [1:0] tx_state, rx_state;
    reg [7:0] tx_shift;
    reg [2:0] tx_bit, rx_bit;
    reg [19:0] tx_count, rx_count;
    reg rx_meta, rx_sync;
    wire [15:0] divisor = {dlm, dll} == 0 ? 16'd1 : {dlm, dll};
    wire [19:0] bit_ticks = {divisor, 4'b0};
    wire tx_busy = tx_state != 0;
    wire dlab = lcr[7];
    wire [2:0] regno = req_addr[4:2];
    wire unused_upper_data = &{1'b0, req_wdata[31:8]};
    wire access_ok = req_addr[31:5] == 0 && req_addr[1:0] == 0;
    wire write_thr = req_write && req_wstrb[0] && regno == 0 && !dlab;
    assign req_ready = !pending && !(req_valid && write_thr && tx_busy);
    assign resp_valid = pending;
    assign irq = (ier[0] && rx_valid) || (ier[1] && tx_irq_pending);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending <= 0;
            resp_rdata <= 0;
            resp_err <= 0;
            ier <= 0;
            lcr <= 8'h03; // 8 data bits, no parity, one stop bit
            mcr <= 0;
            scr <= 0;
            dll <= RESET_DIVISOR[7:0];
            dlm <= RESET_DIVISOR[15:8];
            rx_data <= 0;
            rx_shift <= 0;
            rx_valid <= 0;
            rx_overrun <= 0;
            tx_irq_pending <= 0;
            tx_state <= 0;
            tx_pin <= 1;
            tx_shift <= 0;
            tx_bit <= 0;
            tx_count <= 0;
            rx_state <= 0;
            rx_bit <= 0;
            rx_count <= 0;
            rx_meta <= 1;
            rx_sync <= 1;
        end else begin
            rx_meta <= rx_pin;
            rx_sync <= rx_meta;
            if (tx_state != 0) begin
                if (tx_count != 0) tx_count <= tx_count - 1;
                else case (tx_state)
                    2'd1: begin
                        tx_pin <= tx_shift[0];
                        tx_shift <= {1'b0, tx_shift[7:1]};
                        tx_bit <= 0;
                        tx_count <= bit_ticks - 1;
                        tx_state <= 2'd2;
                    end
                    2'd2: begin
                        tx_count <= bit_ticks - 1;
                        if (tx_bit == 3'd7) begin
                            tx_pin <= 1;
                            tx_state <= 2'd3;
                        end else begin
                            tx_bit <= tx_bit + 1;
                            tx_pin <= tx_shift[0];
                            tx_shift <= {1'b0, tx_shift[7:1]};
                        end
                    end
                    2'd3: begin
                        tx_pin <= 1;
                        tx_state <= 0;
                        if (ier[1]) tx_irq_pending <= 1;
                    end
                    default: tx_state <= 0;
                endcase
            end
            if (rx_state == 0) begin
                if (!rx_sync) begin
                    rx_count <= bit_ticks >> 1;
                    rx_state <= 2'd1;
                end
            end else if (rx_count != 0) rx_count <= rx_count - 1;
            else case (rx_state)
                2'd1: begin
                    if (!rx_sync) begin
                        rx_count <= bit_ticks - 1;
                        rx_bit <= 0;
                        rx_state <= 2'd2;
                    end else rx_state <= 0;
                end
                2'd2: begin
                    rx_shift <= {rx_sync, rx_shift[7:1]};
                    rx_count <= bit_ticks - 1;
                    if (rx_bit == 3'd7) rx_state <= 2'd3;
                    else rx_bit <= rx_bit + 1;
                end
                2'd3: begin
                    if (rx_sync) begin
                        if (rx_valid) rx_overrun <= 1;
                        rx_data <= rx_shift;
                        rx_valid <= 1;
                    end
                    rx_state <= 0;
                end
                default: rx_state <= 0;
            endcase
            if (req_valid && req_ready) begin
                pending <= 1;
                resp_rdata <= 0;
                resp_err <= !access_ok || (req_write && |req_wstrb[3:1]);
                if (access_ok && !(req_write && |req_wstrb[3:1])) begin
                    case (regno)
                        3'd0: begin
                            if (dlab) begin
                                resp_rdata <= {24'b0, dll};
                                if (req_write && req_wstrb[0]) dll <= req_wdata[7:0];
                            end else begin
                                resp_rdata <= {24'b0, rx_data};
                                if (req_write && req_wstrb[0]) begin
                                    tx_pin <= 0;
                                    tx_shift <= req_wdata[7:0];
                                    tx_count <= bit_ticks - 1;
                                    tx_state <= 2'd1;
                                    tx_irq_pending <= 0;
                                end else if (!req_write) rx_valid <= 0;
                            end
                        end
                        3'd1: begin
                            resp_rdata <= dlab ? {24'b0, dlm} : {24'b0, ier};
                            if (req_write && req_wstrb[0]) begin
                                if (dlab) dlm <= req_wdata[7:0];
                                else begin
                                    ier <= req_wdata[7:0] & 8'h03;
                                    if (!req_wdata[1]) tx_irq_pending <= 0;
                                    else if (!ier[1] && !tx_busy) tx_irq_pending <= 1;
                                end
                            end
                        end
                        3'd2: begin
                            resp_rdata <= ier[0] && rx_valid ? 32'h04 :
                                          ier[1] && tx_irq_pending ? 32'h02 : 32'h01;
                            if (!req_write && !(ier[0] && rx_valid) &&
                                ier[1] && tx_irq_pending)
                                tx_irq_pending <= 0;
                            if (req_write && req_wstrb[0] && req_wdata[1]) begin
                                rx_valid <= 0;
                                rx_overrun <= 0;
                            end
                        end
                        3'd3: begin
                            resp_rdata <= {24'b0, lcr};
                            if (req_write && req_wstrb[0]) lcr <= req_wdata[7:0];
                        end
                        3'd4: begin
                            resp_rdata <= {24'b0, mcr};
                            if (req_write && req_wstrb[0]) mcr <= req_wdata[7:0];
                        end
                        3'd5: begin
                            resp_rdata <= {24'b0, 1'b0, !tx_busy, !tx_busy,
                                           3'b0, rx_overrun, rx_valid};
                            if (!req_write) rx_overrun <= 0;
                        end
                        3'd6: resp_rdata <= 0;
                        3'd7: begin
                            resp_rdata <= {24'b0, scr};
                            if (req_write && req_wstrb[0]) scr <= req_wdata[7:0];
                        end
                    endcase
                end
            end else if (resp_valid && resp_ready) pending <= 0;
        end
    end
endmodule
