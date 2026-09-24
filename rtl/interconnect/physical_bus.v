`timescale 1ns/1ps
// Single-outstanding physical request router. Addresses are byte addresses.
// A slave must answer an accepted request no earlier than the following cycle.
module physical_bus #(
    parameter [31:0] RAM_BASE   = 32'h8000_0000,
    parameter [31:0] RAM_SIZE   = 32'h0200_0000,
    parameter [31:0] FLASH_BASE = 32'h2000_0000,
    parameter [31:0] FLASH_SIZE = 32'h0100_0000,
    parameter [31:0] UART_BASE  = 32'h1000_0000,
    parameter [31:0] UART_SIZE  = 32'h0000_1000,
    parameter [31:0] ROM_BASE   = 32'h0000_0000,
    parameter [31:0] ROM_SIZE   = 32'h0000_1000,
    parameter [31:0] TIMER_BASE = 32'h0200_0000,
    parameter [31:0] TIMER_SIZE = 32'h0001_0000,
    parameter [31:0] CTRL_BASE = 32'h1000_1000,
    parameter [31:0] CTRL_SIZE = 32'h0000_1000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req_valid,
    output reg         req_ready,
    input  wire [31:0] req_addr,
    input  wire        req_write,
    input  wire [31:0] req_wdata,
    input  wire [3:0]  req_wstrb,
    output reg         resp_valid,
    input  wire        resp_ready,
    output reg  [31:0] resp_rdata,
    output reg         resp_err,
    output wire [31:0] dev_addr,
    output wire        dev_write,
    output wire [31:0] dev_wdata,
    output wire [3:0]  dev_wstrb,
    output wire        ram_req_valid,
    input  wire        ram_req_ready,
    input  wire        ram_resp_valid,
    output wire        ram_resp_ready,
    input  wire [31:0] ram_resp_rdata,
    input  wire        ram_resp_err,
    output wire        flash_req_valid,
    input  wire        flash_req_ready,
    input  wire        flash_resp_valid,
    output wire        flash_resp_ready,
    input  wire [31:0] flash_resp_rdata,
    input  wire        flash_resp_err,
    output wire        uart_req_valid,
    input  wire        uart_req_ready,
    input  wire        uart_resp_valid,
    output wire        uart_resp_ready,
    input  wire [31:0] uart_resp_rdata,
    input  wire        uart_resp_err,
    output wire        rom_req_valid,
    input  wire        rom_req_ready,
    input  wire        rom_resp_valid,
    output wire        rom_resp_ready,
    input  wire [31:0] rom_resp_rdata,
    input  wire        rom_resp_err,
    output wire        timer_req_valid,
    input  wire        timer_req_ready,
    input  wire        timer_resp_valid,
    output wire        timer_resp_ready,
    input  wire [31:0] timer_resp_rdata,
    input  wire        timer_resp_err,
    output wire        ctrl_req_valid,
    input  wire        ctrl_req_ready,
    input  wire        ctrl_resp_valid,
    output wire        ctrl_resp_ready,
    input  wire [31:0] ctrl_resp_rdata,
    input  wire        ctrl_resp_err
);
    localparam [2:0] IDLE = 3'd0, RAM = 3'd1, FLASH = 3'd2,
                     UART = 3'd3, ROM = 3'd4, TIMER = 3'd5,
                     MISS = 3'd6, CTRL = 3'd7;
    reg [2:0] state;
    reg [2:0] target;
    reg [31:0] offset;

    // Window sizes must be powers of two and bases aligned to their sizes.
    always @* begin
        target = MISS;
        offset = 32'b0;
        if ((req_addr & ~(RAM_SIZE - 32'd1)) == RAM_BASE) begin
            target = RAM;
            offset = req_addr & (RAM_SIZE - 32'd1);
        end else if ((req_addr & ~(FLASH_SIZE - 32'd1)) == FLASH_BASE) begin
            target = FLASH;
            offset = req_addr & (FLASH_SIZE - 32'd1);
        end else if ((req_addr & ~(UART_SIZE - 32'd1)) == UART_BASE) begin
            target = UART;
            offset = req_addr & (UART_SIZE - 32'd1);
        end else if ((req_addr & ~(ROM_SIZE - 32'd1)) == ROM_BASE) begin
            target = ROM;
            offset = req_addr & (ROM_SIZE - 32'd1);
        end else if ((req_addr & ~(TIMER_SIZE - 32'd1)) == TIMER_BASE) begin
            target = TIMER;
            offset = req_addr & (TIMER_SIZE - 32'd1);
        end else if ((req_addr & ~(CTRL_SIZE - 32'd1)) == CTRL_BASE) begin
            target = CTRL;
            offset = req_addr & (CTRL_SIZE - 32'd1);
        end
    end

    assign dev_addr = offset;
    assign dev_write = req_write;
    assign dev_wdata = req_wdata;
    assign dev_wstrb = req_wstrb;
    assign ram_req_valid = state == IDLE && req_valid && target == RAM;
    assign flash_req_valid = state == IDLE && req_valid && target == FLASH;
    assign uart_req_valid = state == IDLE && req_valid && target == UART;
    assign rom_req_valid = state == IDLE && req_valid && target == ROM;
    assign timer_req_valid = state == IDLE && req_valid && target == TIMER;
    assign ctrl_req_valid = state == IDLE && req_valid && target == CTRL;
    assign ram_resp_ready = state == RAM && resp_ready;
    assign flash_resp_ready = state == FLASH && resp_ready;
    assign uart_resp_ready = state == UART && resp_ready;
    assign rom_resp_ready = state == ROM && resp_ready;
    assign timer_resp_ready = state == TIMER && resp_ready;
    assign ctrl_resp_ready = state == CTRL && resp_ready;

    always @* begin
        req_ready = 1'b0;
        resp_valid = 1'b0;
        resp_rdata = 32'b0;
        resp_err = 1'b0;
        case (state)
            IDLE: case (target)
                RAM: req_ready = ram_req_ready;
                FLASH: req_ready = flash_req_ready;
                UART: req_ready = uart_req_ready;
                ROM: req_ready = rom_req_ready;
                TIMER: req_ready = timer_req_ready;
                CTRL: req_ready = ctrl_req_ready;
                default: req_ready = 1'b1;
            endcase
            RAM: begin
                resp_valid = ram_resp_valid;
                resp_rdata = ram_resp_rdata;
                resp_err = ram_resp_err;
            end
            FLASH: begin
                resp_valid = flash_resp_valid;
                resp_rdata = flash_resp_rdata;
                resp_err = flash_resp_err;
            end
            UART: begin
                resp_valid = uart_resp_valid;
                resp_rdata = uart_resp_rdata;
                resp_err = uart_resp_err;
            end
            ROM: begin
                resp_valid = rom_resp_valid;
                resp_rdata = rom_resp_rdata;
                resp_err = rom_resp_err;
            end
            TIMER: begin
                resp_valid = timer_resp_valid;
                resp_rdata = timer_resp_rdata;
                resp_err = timer_resp_err;
            end
            CTRL: begin
                resp_valid = ctrl_resp_valid;
                resp_rdata = ctrl_resp_rdata;
                resp_err = ctrl_resp_err;
            end
            MISS: begin
                resp_valid = 1'b1;
                resp_err = 1'b1;
            end
            default: begin end
        endcase
        if (state == IDLE && !rst_n) req_ready = 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else case (state)
            IDLE: if (req_valid && req_ready) state <= target;
            RAM, FLASH, UART, ROM, TIMER, CTRL, MISS: if (resp_valid && resp_ready) state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
