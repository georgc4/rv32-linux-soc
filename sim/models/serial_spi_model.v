`timescale 1ns/1ps
// Bit/nibble-level mode-0 model of ESP-PSRAM64H or W25Q128JVSIQ commands.
// The SIQ flash's factory-fixed QE bit is represented by accepting 6Bh reads.
// This checks wire protocol, not analog setup/hold or program/erase latency.
module serial_spi_model #(
    parameter integer MEM_BYTES = 4096,
    parameter IS_FLASH = 0
) (
    input wire cs_n, sck,
    input wire [3:0] io_in,
    output reg [3:0] io_out,
    output reg [3:0] io_oe,
    output reg [31:0] command_count
);
    reg [7:0] memory [0:MEM_BYTES-1];
    reg [7:0] command, command_shift, data_shift;
    reg [23:0] address, address_shift;
    wire [31:0] address32 = {8'b0, address};
    reg write_enabled;
    reg [1:0] busy_polls;
    wire [7:0] status = {6'b0, write_enabled, busy_polls != 0};
    integer bit_count;
    integer n, erase_index;
    initial begin
        for (n = 0; n < MEM_BYTES; n = n + 1) memory[n] = 0;
        command_count = 0;
        command = 0;
        command_shift = 0;
        address = 0;
        address_shift = 0;
        data_shift = 0;
        bit_count = 0;
        io_out = 0;
        io_oe = 0;
        write_enabled = 0;
        busy_polls = 0;
    end
    always @(posedge sck or posedge cs_n) begin
        if (cs_n) begin
            if (IS_FLASH && (command == 8'h02 || command == 8'h20))
                write_enabled <= 0;
            if (IS_FLASH && command == 8'h05 && busy_polls != 0)
                busy_polls <= busy_polls - 1;
            bit_count <= 0;
            command <= 0;
            command_shift <= 0;
            address_shift <= 0;
            data_shift <= 0;
        end else begin
            if (bit_count < 8) begin
                command_shift <= {command_shift[6:0], io_in[0]};
                if (bit_count == 7) begin
                    command <= {command_shift[6:0], io_in[0]};
                    command_count <= command_count + 1;
                    if (IS_FLASH && {command_shift[6:0], io_in[0]} == 8'h06)
                        write_enabled <= 1;
                end
            end else if (!IS_FLASH && (command == 8'heb || command == 8'h38) &&
                         bit_count < 14) begin
                address_shift <= {address_shift[19:0], io_in};
                if (bit_count == 13) address <= {address_shift[19:0], io_in};
            end else if (bit_count < 32 &&
                         (IS_FLASH || (command != 8'heb && command != 8'h38))) begin
                address_shift <= {address_shift[22:0], io_in[0]};
                if (bit_count == 31) begin
                    address <= {address_shift[22:0], io_in[0]};
                    if (IS_FLASH && command == 8'h20 && write_enabled) begin
                        busy_polls <= 2;
                        for (erase_index = 0; erase_index < 4096; erase_index = erase_index + 1)
                            memory[(( {8'b0, address_shift[22:0], io_in[0]} & 32'h00fff000) + erase_index) % MEM_BYTES] <= 8'hff;
                    end
                end
            end else if (!IS_FLASH && command == 8'h38 && bit_count >= 14) begin
                if ((bit_count - 14) % 2 == 0)
                    data_shift[7:4] <= io_in;
                else memory[(address32 + ((bit_count - 14) / 2)) % MEM_BYTES] <=
                         {data_shift[7:4], io_in};
            end else if (command == 8'h02 && (!IS_FLASH || write_enabled) &&
                         bit_count >= 32) begin
                data_shift <= {data_shift[6:0], io_in[0]};
                if ((bit_count - 32) % 8 == 7) begin
                    memory[(address32 + ((bit_count - 32) / 8)) % MEM_BYTES] <=
                        IS_FLASH ? memory[(address32 + ((bit_count - 32) / 8)) % MEM_BYTES] &
                                   {data_shift[6:0], io_in[0]} : {data_shift[6:0], io_in[0]};
                    if (IS_FLASH) busy_polls <= 2;
                end
            end
            bit_count <= bit_count + 1;
        end
    end
    always @(negedge sck or posedge cs_n) begin
        if (cs_n) begin
            io_out <= 0;
            io_oe <= 0;
        end else if (IS_FLASH && command == 8'h05 && bit_count >= 8) begin
            io_oe <= 4'b0010;
            io_out <= {2'b0, status[7 - ((bit_count - 8) % 8)], 1'b0};
        end else if (command == 8'h03 && bit_count >= 32) begin
            io_oe <= 4'b0010;
            io_out <= {2'b0,
                       memory[(address32 + ((bit_count - 32) / 8)) % MEM_BYTES][7 - ((bit_count - 32) % 8)],
                       1'b0};
        end else if (!IS_FLASH && command == 8'heb && bit_count >= 20) begin
            io_oe <= 4'b1111;
            io_out <= (bit_count - 20) % 2 == 0 ?
                      memory[(address32 + ((bit_count - 20) / 2)) % MEM_BYTES][7:4] :
                      memory[(address32 + ((bit_count - 20) / 2)) % MEM_BYTES][3:0];
        end else if (IS_FLASH && command == 8'h6b && bit_count >= 40) begin
            io_oe <= 4'b1111;
            io_out <= (bit_count - 40) % 2 == 0 ?
                      memory[(address32 + ((bit_count - 40) / 2)) % MEM_BYTES][7:4] :
                      memory[(address32 + ((bit_count - 40) / 2)) % MEM_BYTES][3:0];
        end else begin
            io_out <= 0;
            io_oe <= 0;
        end
    end
endmodule
