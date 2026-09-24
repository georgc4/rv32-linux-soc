`timescale 1ns/1ps
// Conservative standard-SPI bridge for four ESP-PSRAM64H and one W25Q128JV.
// One transaction at a time. SCK is clk/2; clk must be fast enough that each
// PSRAM CS-low interval stays below the datasheet's 8 us maximum.
// DQ mapping: [0]=shared SI/IO0, [1]=shared SO/IO1,
// [3:2]=PSRAM SIO2/3, [5:4]=NOR /WP,/HOLD (IO2/3).
module serial_mem_bridge #(
    parameter integer POWERUP_CYCLES = 3000
) (
    input wire clk, rst_n,
    input wire ram_req_valid,
    output wire ram_req_ready,
    input wire [31:0] ram_req_addr,
    input wire ram_req_write,
    input wire [31:0] ram_req_wdata,
    input wire [3:0] ram_req_wstrb,
    output wire ram_resp_valid,
    input wire ram_resp_ready,
    output wire [31:0] ram_resp_rdata,
    output wire ram_resp_err,
    input wire flash_req_valid,
    output wire flash_req_ready,
    input wire [31:0] flash_req_addr,
    input wire flash_req_write,
    output wire flash_resp_valid,
    input wire flash_resp_ready,
    output wire [31:0] flash_resp_rdata,
    output wire flash_resp_err,
    output reg spi_sck,
    output reg [4:0] spi_cs_n,
    input wire [5:0] spi_dq_in,
    output wire [5:0] spi_dq_out,
    output wire [5:0] spi_dq_oe,
    output wire initialized
);
    localparam [2:0] POWER_WAIT = 3'd0, INIT_LAUNCH = 3'd1,
                     IDLE = 3'd2, SETUP = 3'd3, HIGH = 3'd4,
                     LOW = 3'd5, GAP = 3'd6, DONE = 3'd7;
    localparam [1:0] K_INIT = 2'd0, K_RAM_READ = 2'd1,
                     K_RAM_WRITE = 2'd2, K_FLASH_READ = 2'd3;
    localparam [1:0] AFTER_IDLE = 2'd0, AFTER_DONE = 2'd1,
                     AFTER_INIT = 2'd2, AFTER_WRITE = 2'd3;
    reg [2:0] state;
    reg [1:0] kind, after_gap;
    reg [31:0] power_count;
    reg [1:0] init_chip;
    reg init_reset_cmd;
    reg selected_flash;
    reg [2:0] selected_chip;
    reg [31:0] header;
    reg [6:0] bit_index, total_bits;
    reg mosi;
    reg [31:0] read_shift, response_data;
    reg response_error;
    reg [23:0] base_address;
    reg [31:0] write_word;
    reg [3:0] pending_strb;
    reg [1:0] lane;
    reg [7:0] write_byte;
    reg [1:0] gap_count;
    reg init_complete;
    wire unused_spi_inputs = &{1'b0, spi_dq_in[5:2], spi_dq_in[0]};
    wire [3:0] remaining_strb = pending_strb & ~(4'b0001 << lane);

    function [1:0] first_lane;
        input [3:0] mask;
        begin
            if (mask[0]) first_lane = 2'd0;
            else if (mask[1]) first_lane = 2'd1;
            else if (mask[2]) first_lane = 2'd2;
            else if (mask[3]) first_lane = 2'd3;
            else first_lane = 2'd0;
        end
    endfunction

    assign initialized = init_complete;
    assign spi_dq_out = {2'b11, 2'b00, 1'b0, mosi};
    assign spi_dq_oe = rst_n ? 6'b111101 : 6'b000000;
    assign ram_req_ready = state == IDLE;
    assign flash_req_ready = state == IDLE && !ram_req_valid;
    assign ram_resp_valid = state == DONE && !selected_flash;
    assign flash_resp_valid = state == DONE && selected_flash;
    assign ram_resp_rdata = response_data;
    assign flash_resp_rdata = response_data;
    assign ram_resp_err = response_error;
    assign flash_resp_err = response_error;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= POWER_WAIT;
            power_count <= 0;
            init_chip <= 0;
            init_reset_cmd <= 0;
            init_complete <= 0;
            spi_sck <= 0;
            spi_cs_n <= 5'b11111;
            mosi <= 0;
            kind <= K_INIT;
            after_gap <= AFTER_IDLE;
            selected_flash <= 0;
            selected_chip <= 0;
            header <= 0;
            bit_index <= 0;
            total_bits <= 0;
            read_shift <= 0;
            response_data <= 0;
            response_error <= 0;
            base_address <= 0;
            write_word <= 0;
            pending_strb <= 0;
            lane <= 0;
            write_byte <= 0;
            gap_count <= 0;
        end else case (state)
            POWER_WAIT: begin
                spi_cs_n <= 5'b11111;
                spi_sck <= 0;
                mosi <= 0;
                if (power_count == POWERUP_CYCLES - 1) state <= INIT_LAUNCH;
                else power_count <= power_count + 1;
            end
            INIT_LAUNCH: begin
                kind <= K_INIT;
                selected_chip <= {1'b0, init_chip};
                header <= {init_reset_cmd ? 8'h99 : 8'h66, 24'b0};
                total_bits <= 7'd8;
                bit_index <= 0;
                mosi <= init_reset_cmd ? 1'b1 : 1'b0;
                spi_cs_n <= ~(5'b00001 << init_chip);
                spi_sck <= 0;
                state <= SETUP;
            end
            IDLE: begin
                spi_cs_n <= 5'b11111;
                spi_sck <= 0;
                if (ram_req_valid) begin
                    selected_flash <= 0;
                    selected_chip <= {1'b0, ram_req_addr[24:23]};
                    base_address <= {1'b0, ram_req_addr[22:0]} & 24'hfffffc;
                    write_word <= ram_req_wdata;
                    pending_strb <= ram_req_wstrb;
                    response_data <= 0;
                    response_error <= ram_req_addr[31:25] != 0;
                    if (ram_req_addr[31:25] != 0 || (ram_req_write && ram_req_wstrb == 0)) state <= DONE;
                    else begin
                        kind <= ram_req_write ? K_RAM_WRITE : K_RAM_READ;
                        lane <= first_lane(ram_req_wstrb);
                        write_byte <= ram_req_wdata[8*first_lane(ram_req_wstrb) +: 8];
                        header <= {ram_req_write ? 8'h02 : 8'h03,
                                   ({1'b0, ram_req_addr[22:0]} & 24'hfffffc) +
                                   (ram_req_write ? {22'b0, first_lane(ram_req_wstrb)} : 24'b0)};
                        total_bits <= ram_req_write ? 7'd40 : 7'd64;
                        bit_index <= 0;
                        read_shift <= 0;
                        mosi <= 0;
                        spi_cs_n <= ~(5'b00001 << ram_req_addr[24:23]);
                        state <= SETUP;
                    end
                end else if (flash_req_valid) begin
                    selected_flash <= 1;
                    selected_chip <= 3'd4;
                    response_data <= 0;
                    response_error <= flash_req_write || flash_req_addr[31:24] != 0;
                    if (flash_req_write || flash_req_addr[31:24] != 0) state <= DONE;
                    else begin
                        kind <= K_FLASH_READ;
                        header <= {8'h03, flash_req_addr[23:0] & 24'hfffffc};
                        total_bits <= 7'd64;
                        bit_index <= 0;
                        read_shift <= 0;
                        mosi <= 0;
                        spi_cs_n <= 5'b01111;
                        state <= SETUP;
                    end
                end
            end
            SETUP: state <= HIGH;
            HIGH: begin
                spi_sck <= 1;
                if (bit_index >= 7'd32 && kind != K_INIT && kind != K_RAM_WRITE)
                    read_shift <= {read_shift[30:0], spi_dq_in[1]};
                state <= LOW;
            end
            LOW: begin
                spi_sck <= 0;
                if (bit_index + 7'd1 == total_bits) begin
                    spi_cs_n <= 5'b11111;
                    mosi <= 0;
                    gap_count <= 2'd2;
                    if (kind == K_INIT) begin
                        if (!init_reset_cmd) begin
                            init_reset_cmd <= 1;
                            after_gap <= AFTER_INIT;
                        end else if (init_chip != 2'd3) begin
                            init_chip <= init_chip + 1;
                            init_reset_cmd <= 0;
                            after_gap <= AFTER_INIT;
                        end else begin
                            init_complete <= 1;
                            after_gap <= AFTER_IDLE;
                        end
                    end else if (kind == K_RAM_WRITE) begin
                        pending_strb <= remaining_strb;
                        if (remaining_strb != 0) begin
                            lane <= first_lane(remaining_strb);
                            after_gap <= AFTER_WRITE;
                        end else after_gap <= AFTER_DONE;
                    end else begin
                        response_data <= {read_shift[7:0], read_shift[15:8],
                                          read_shift[23:16], read_shift[31:24]};
                        after_gap <= AFTER_DONE;
                    end
                    state <= GAP;
                end else begin
                    bit_index <= bit_index + 1;
                    if (bit_index < 7'd31) mosi <= header[30 - bit_index];
                    else if (kind == K_RAM_WRITE)
                        mosi <= write_byte[7 - (bit_index - 7'd31)];
                    else mosi <= 0;
                    state <= HIGH;
                end
            end
            GAP: begin
                if (gap_count != 0) gap_count <= gap_count - 1;
                else case (after_gap)
                    AFTER_IDLE: state <= IDLE;
                    AFTER_DONE: state <= DONE;
                    AFTER_INIT: state <= INIT_LAUNCH;
                    AFTER_WRITE: begin
                        write_byte <= write_word[8*lane +: 8];
                        header <= {8'h02, base_address + {22'b0, lane}};
                        total_bits <= 7'd40;
                        bit_index <= 0;
                        mosi <= 0;
                        spi_cs_n <= ~(5'b00001 << selected_chip);
                        state <= SETUP;
                    end
                endcase
            end
            DONE: if ((!selected_flash && ram_resp_ready) ||
                      (selected_flash && flash_resp_ready)) state <= IDLE;
            default: state <= POWER_WAIT;
        endcase
    end
endmodule
