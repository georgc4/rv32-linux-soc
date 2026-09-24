`timescale 1ns/1ps
// Standard SPI mode-0 behavioral model for bridge tests, not a timing model.
module serial_spi_model #(
    parameter integer MEM_BYTES = 4096,
    parameter IS_FLASH = 0
) (
    input wire cs_n, sck, si,
    output reg so,
    output reg so_oe,
    output reg [31:0] command_count
);
    reg [7:0] memory [0:MEM_BYTES-1];
    reg [7:0] command, command_shift, data_shift;
    reg [23:0] address, address_shift;
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
        so = 0;
        so_oe = 0;
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
                command_shift <= {command_shift[6:0], si};
                if (bit_count == 7) begin
                    command <= {command_shift[6:0], si};
                    command_count <= command_count + 1;
                    if (IS_FLASH && {command_shift[6:0], si} == 8'h06)
                        write_enabled <= 1;
                end
            end else if (bit_count < 32) begin
                address_shift <= {address_shift[22:0], si};
                if (bit_count == 31) begin
                    address <= {address_shift[22:0], si};
                    if (IS_FLASH && command == 8'h20 && write_enabled) begin
                        busy_polls <= 2;
                        for (erase_index = 0; erase_index < 4096; erase_index = erase_index + 1)
                            memory[(( {address_shift[22:0], si} & 24'hfff000) + erase_index) % MEM_BYTES] <= 8'hff;
                    end
                end
            end else if (command == 8'h02 && (!IS_FLASH || write_enabled)) begin
                data_shift <= {data_shift[6:0], si};
                if ((bit_count - 32) % 8 == 7) begin
                    memory[(address + ((bit_count - 32) / 8)) % MEM_BYTES] <=
                        IS_FLASH ? memory[(address + ((bit_count - 32) / 8)) % MEM_BYTES] &
                                   {data_shift[6:0], si} : {data_shift[6:0], si};
                    if (IS_FLASH) busy_polls <= 2;
                end
            end
            bit_count <= bit_count + 1;
        end
    end
    always @(negedge sck or posedge cs_n) begin
        if (cs_n) begin
            so <= 0;
            so_oe <= 0;
        end else if (IS_FLASH && command == 8'h05 && bit_count >= 8) begin
            so_oe <= 1;
            so <= status[7 - ((bit_count - 8) % 8)];
        end else if (command == 8'h03 && bit_count >= 32) begin
            so_oe <= 1;
            so <= memory[(address + ((bit_count - 32) / 8)) % MEM_BYTES][7 - ((bit_count - 32) % 8)];
        end else begin
            so <= 0;
            so_oe <= 0;
        end
    end
endmodule
