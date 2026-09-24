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
    integer bit_count;
    integer n;
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
    end
    always @(posedge sck or posedge cs_n) begin
        if (cs_n) begin
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
                end
            end else if (bit_count < 32) begin
                address_shift <= {address_shift[22:0], si};
                if (bit_count == 31) address <= {address_shift[22:0], si};
            end else if (command == 8'h02 && !IS_FLASH) begin
                data_shift <= {data_shift[6:0], si};
                if ((bit_count - 32) % 8 == 7)
                    memory[(address + ((bit_count - 32) / 8)) % MEM_BYTES] <= {data_shift[6:0], si};
            end
            bit_count <= bit_count + 1;
        end
    end
    always @(negedge sck or posedge cs_n) begin
        if (cs_n) begin
            so <= 0;
            so_oe <= 0;
        end else if (command == 8'h03 && bit_count >= 32) begin
            so_oe <= 1;
            so <= memory[(address + ((bit_count - 32) / 8)) % MEM_BYTES][7 - ((bit_count - 32) % 8)];
        end else begin
            so <= 0;
            so_oe <= 0;
        end
    end
endmodule
