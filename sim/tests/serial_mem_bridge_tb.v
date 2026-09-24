`timescale 1ns/1ps
module serial_mem_bridge_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg ram_req_valid = 0, ram_req_write = 0;
    reg [31:0] ram_req_addr = 0, ram_req_wdata = 0;
    reg [3:0] ram_req_wstrb = 0;
    wire ram_req_ready, ram_resp_valid, ram_resp_err;
    reg ram_resp_ready = 0;
    wire [31:0] ram_resp_rdata;
    reg flash_req_valid = 0, flash_req_write = 0;
    reg [31:0] flash_req_addr = 0;
    wire flash_req_ready, flash_resp_valid, flash_resp_err;
    reg flash_resp_ready = 0;
    wire [31:0] flash_resp_rdata;
    reg ctrl_req_valid = 0, ctrl_req_write = 0, ctrl_resp_ready = 0;
    reg [31:0] ctrl_req_addr = 0, ctrl_req_wdata = 0;
    reg [3:0] ctrl_req_wstrb = 0;
    wire ctrl_req_ready, ctrl_resp_valid, ctrl_resp_err;
    wire [31:0] ctrl_resp_rdata;
    wire spi_sck, initialized;
    wire [4:0] spi_cs_n;
    wire [5:0] spi_dq_out, spi_dq_oe, spi_dq_in;
    wire [4:0] so, so_oe;
    wire [31:0] commands [0:4];
    wire miso = (so[0] & so_oe[0]) | (so[1] & so_oe[1]) |
                (so[2] & so_oe[2]) | (so[3] & so_oe[3]) |
                (so[4] & so_oe[4]);
    assign spi_dq_in = {4'b0, miso, spi_dq_out[0]};
    integer cycles;

    serial_mem_bridge #(.POWERUP_CYCLES(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .ram_req_valid(ram_req_valid), .ram_req_ready(ram_req_ready),
        .ram_req_addr(ram_req_addr), .ram_req_write(ram_req_write),
        .ram_req_wdata(ram_req_wdata), .ram_req_wstrb(ram_req_wstrb),
        .ram_resp_valid(ram_resp_valid), .ram_resp_ready(ram_resp_ready),
        .ram_resp_rdata(ram_resp_rdata), .ram_resp_err(ram_resp_err),
        .flash_req_valid(flash_req_valid), .flash_req_ready(flash_req_ready),
        .flash_req_addr(flash_req_addr), .flash_req_write(flash_req_write),
        .flash_resp_valid(flash_resp_valid), .flash_resp_ready(flash_resp_ready),
        .flash_resp_rdata(flash_resp_rdata), .flash_resp_err(flash_resp_err),
        .ctrl_req_valid(ctrl_req_valid), .ctrl_req_ready(ctrl_req_ready),
        .ctrl_req_addr(ctrl_req_addr), .ctrl_req_write(ctrl_req_write),
        .ctrl_req_wdata(ctrl_req_wdata), .ctrl_req_wstrb(ctrl_req_wstrb),
        .ctrl_resp_valid(ctrl_resp_valid), .ctrl_resp_ready(ctrl_resp_ready),
        .ctrl_resp_rdata(ctrl_resp_rdata), .ctrl_resp_err(ctrl_resp_err),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_dq_in(spi_dq_in), .spi_dq_out(spi_dq_out), .spi_dq_oe(spi_dq_oe),
        .initialized(initialized)
    );
    genvar g;
    generate for (g = 0; g < 4; g = g + 1) begin: rams
        serial_spi_model ram (
            .cs_n(spi_cs_n[g]), .sck(spi_sck), .si(spi_dq_out[0]),
            .so(so[g]), .so_oe(so_oe[g]), .command_count(commands[g])
        );
    end endgenerate
    serial_spi_model #(.IS_FLASH(1)) flash (
        .cs_n(spi_cs_n[4]), .sck(spi_sck), .si(spi_dq_out[0]),
        .so(so[4]), .so_oe(so_oe[4]), .command_count(commands[4])
    );

    task ram_request;
        input [31:0] addr, wdata;
        input write_enable;
        input [3:0] strb;
        begin
            @(negedge clk);
            ram_req_addr = addr;
            ram_req_wdata = wdata;
            ram_req_write = write_enable;
            ram_req_wstrb = strb;
            ram_req_valid = 1;
            cycles = 0;
            do begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 300) $fatal(1, "RAM request timeout");
            end while (!ram_req_ready);
            @(negedge clk);
            ram_req_valid = 0;
        end
    endtask

    task control_request;
        input [31:0] addr, data, expected;
        input write_enable;
        input [3:0] strb;
        input expected_error;
        begin
            @(negedge clk);
            ctrl_req_addr = addr;
            ctrl_req_wdata = data;
            ctrl_req_write = write_enable;
            ctrl_req_wstrb = strb;
            ctrl_req_valid = 1;
            cycles = 0;
            do begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 300) $fatal(1, "control request timeout");
            end while (!ctrl_req_ready);
            @(negedge clk);
            ctrl_req_valid = 0;
            cycles = 0;
            while (!ctrl_resp_valid) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 3000) $fatal(1, "control response timeout");
            end
            if (ctrl_resp_err !== expected_error ||
                (!expected_error && ctrl_resp_rdata !== expected))
                $fatal(1, "control response addr=%h data=%h err=%b expected=%h err=%b",
                       addr, ctrl_resp_rdata, ctrl_resp_err, expected, expected_error);
            ctrl_resp_ready = 1;
            @(posedge clk);
            @(negedge clk);
            ctrl_resp_ready = 0;
        end
    endtask
    task ram_response;
        input [31:0] expected;
        input expected_error;
        begin
            cycles = 0;
            while (!ram_resp_valid) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 1500) $fatal(1, "RAM response timeout");
            end
            if (ram_resp_rdata !== expected || ram_resp_err !== expected_error)
                $fatal(1, "RAM response %h err=%b expected %h err=%b", ram_resp_rdata, ram_resp_err, expected, expected_error);
            repeat (3) begin
                @(negedge clk);
                if (!ram_resp_valid || ram_resp_rdata !== expected) $fatal(1, "RAM response not held");
            end
            ram_resp_ready = 1;
            @(posedge clk);
            @(negedge clk);
            ram_resp_ready = 0;
        end
    endtask
    task flash_request;
        input [31:0] addr;
        input write_enable;
        begin
            @(negedge clk);
            flash_req_addr = addr;
            flash_req_write = write_enable;
            flash_req_valid = 1;
            cycles = 0;
            do begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 300) $fatal(1, "flash request timeout");
            end while (!flash_req_ready);
            @(negedge clk);
            flash_req_valid = 0;
        end
    endtask
    task flash_response;
        input [31:0] expected;
        input expected_error;
        begin
            cycles = 0;
            while (!flash_resp_valid) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 300) $fatal(1, "flash response timeout");
            end
            if (flash_resp_rdata !== expected || flash_resp_err !== expected_error)
                $fatal(1, "flash response %h err=%b expected %h err=%b", flash_resp_rdata, flash_resp_err, expected, expected_error);
            flash_resp_ready = 1;
            @(posedge clk);
            @(negedge clk);
            flash_resp_ready = 0;
        end
    endtask

    initial begin
        flash.memory[0] = 8'h78;
        flash.memory[1] = 8'h56;
        flash.memory[2] = 8'h34;
        flash.memory[3] = 8'h12;
        repeat (3) @(negedge clk);
        rst_n = 1;
        cycles = 0;
        while (!initialized && cycles < 250) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (!initialized) $fatal(1, "PSRAM initialization timeout");
        if (commands[0] != 2 || commands[1] != 2 || commands[2] != 2 || commands[3] != 2)
            $fatal(1, "PSRAM reset sequence missing");
        if (spi_dq_oe !== 6'b111101 || spi_dq_out[5:2] !== 4'b1100)
            $fatal(1, "DQ2/3 startup levels incorrect");
        ram_request(32'h0000_0000, 32'haabb_ccdd, 1, 4'b1111);
        ram_response(0, 0);
        ram_request(32'h0000_0000, 0, 0, 0);
        ram_response(32'haabb_ccdd, 0);
        ram_request(32'h0180_0000, 32'h0000_5a00, 1, 4'b0010); // fourth chip, lane 1
        ram_response(0, 0);
        ram_request(32'h0180_0000, 0, 0, 0);
        ram_response(32'h0000_5a00, 0);
        flash_request(0, 0);
        flash_response(32'h1234_5678, 0);
        flash_request(0, 1);
        flash_response(0, 1);
        control_request(0, 0, 0, 1, 4'hf, 0); // sector address
        control_request(8, 2, 0, 1, 4'h1, 0); // WREN + 4 KiB erase + poll
        if (flash.memory[0] !== 8'hff || flash.memory[4095] !== 8'hff)
            $fatal(1, "flash erase failed");
        control_request(0, 16, 0, 1, 4'hf, 0);
        control_request(4, 32'ha5, 0, 1, 4'h1, 0);
        control_request(8, 1, 0, 1, 4'h1, 0); // WREN + one-byte program + poll
        flash_request(16, 0);
        flash_response(32'hffff_ffa5, 0);
        control_request(8, 3, 0, 1, 4'h1, 0); // status read
        control_request(8, 2, 0, 1, 4'h1, 1); // unaligned erase rejected
        if (commands[4] < 8 || (|so_oe && (so_oe & (so_oe - 5'd1)) != 0))
            $fatal(1, "flash command count or MISO contention");
        $display("PASS serial_mem_bridge: reset, four-bank RAM, flash read/program/erase/status");
        $finish;
    end
endmodule
