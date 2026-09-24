`timescale 1ns/1ps
module physical_bus_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, req_valid = 0, resp_ready = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    reg req_write = 0;
    reg [3:0] req_wstrb = 0;
    wire req_ready, resp_valid, resp_err;
    wire [31:0] resp_rdata, dev_addr, dev_wdata;
    wire dev_write;
    wire [3:0] dev_wstrb;
    wire [2:0] dreq, dready, dresp, drready, derr;
    wire [31:0] data_r, data_f, data_u;
    wire [31:0] count_r, count_f, count_u;
    wire [31:0] addr_r, addr_f, addr_u, wd_r, wd_f, wd_u;
    wire [3:0] st_r, st_f, st_u;
    wire wr_r, wr_f, wr_u;
    reg [2:0] allow_req = 3'b111;
    integer cycles;

    physical_bus dut (
        .clk(clk), .rst_n(rst_n), .req_valid(req_valid), .req_ready(req_ready),
        .req_addr(req_addr), .req_write(req_write), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .resp_valid(resp_valid), .resp_ready(resp_ready), .resp_rdata(resp_rdata), .resp_err(resp_err),
        .dev_addr(dev_addr), .dev_write(dev_write), .dev_wdata(dev_wdata), .dev_wstrb(dev_wstrb),
        .ram_req_valid(dreq[0]), .ram_req_ready(dready[0]),
        .ram_resp_valid(dresp[0]), .ram_resp_ready(drready[0]),
        .ram_resp_rdata(data_r), .ram_resp_err(derr[0]),
        .flash_req_valid(dreq[1]), .flash_req_ready(dready[1]),
        .flash_resp_valid(dresp[1]), .flash_resp_ready(drready[1]),
        .flash_resp_rdata(data_f), .flash_resp_err(derr[1]),
        .uart_req_valid(dreq[2]), .uart_req_ready(dready[2]),
        .uart_resp_valid(dresp[2]), .uart_resp_ready(drready[2]),
        .uart_resp_rdata(data_u), .uart_resp_err(derr[2])
    );
    latency_device #(.TAG(32'hA100_0000), .WAIT_CYCLES(2)) ram (
        .clk(clk), .rst_n(rst_n), .allow_req(allow_req[0]), .req_valid(dreq[0]), .req_ready(dready[0]),
        .req_addr(dev_addr), .req_write(dev_write), .req_wdata(dev_wdata), .req_wstrb(dev_wstrb),
        .resp_valid(dresp[0]), .resp_ready(drready[0]), .resp_rdata(data_r), .resp_err(derr[0]),
        .accepted_count(count_r), .last_addr(addr_r), .last_wdata(wd_r), .last_wstrb(st_r), .last_write(wr_r)
    );
    latency_device #(.TAG(32'hF100_0000), .WAIT_CYCLES(3)) flash (
        .clk(clk), .rst_n(rst_n), .allow_req(allow_req[1]), .req_valid(dreq[1]), .req_ready(dready[1]),
        .req_addr(dev_addr), .req_write(dev_write), .req_wdata(dev_wdata), .req_wstrb(dev_wstrb),
        .resp_valid(dresp[1]), .resp_ready(drready[1]), .resp_rdata(data_f), .resp_err(derr[1]),
        .accepted_count(count_f), .last_addr(addr_f), .last_wdata(wd_f), .last_wstrb(st_f), .last_write(wr_f)
    );
    latency_device #(.TAG(32'hC100_0000), .WAIT_CYCLES(1)) uart (
        .clk(clk), .rst_n(rst_n), .allow_req(allow_req[2]), .req_valid(dreq[2]), .req_ready(dready[2]),
        .req_addr(dev_addr), .req_write(dev_write), .req_wdata(dev_wdata), .req_wstrb(dev_wstrb),
        .resp_valid(dresp[2]), .resp_ready(drready[2]), .resp_rdata(data_u), .resp_err(derr[2]),
        .accepted_count(count_u), .last_addr(addr_u), .last_wdata(wd_u), .last_wstrb(st_u), .last_write(wr_u)
    );

    task request;
        input [31:0] address, wdata;
        input write_enable;
        input [3:0] strobes;
        begin
            @(negedge clk);
            req_addr = address;
            req_wdata = wdata;
            req_write = write_enable;
            req_wstrb = strobes;
            req_valid = 1;
            cycles = 0;
            do begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 20) $fatal(1, "request timeout at %h", address);
            end while (!req_ready);
            @(negedge clk);
            req_valid = 0;
        end
    endtask

    task response;
        input [31:0] expected_data;
        input expected_error;
        begin
            cycles = 0;
            while (!resp_valid) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 20) $fatal(1, "response timeout");
            end
            if (resp_rdata !== expected_data || resp_err !== expected_error)
                $fatal(1, "response got data=%h err=%b expected data=%h err=%b",
                       resp_rdata, resp_err, expected_data, expected_error);
            resp_ready = 1;
            @(posedge clk);
            @(negedge clk);
            resp_ready = 0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        // Backpressure on target only, with stable request and no accidental delivery.
        allow_req[0] = 0;
        @(negedge clk);
        req_addr = 32'h8000_0024;
        req_valid = 1;
        repeat (3) begin
            @(negedge clk);
            if (req_ready || dreq !== 3'b001 || count_r !== 0)
                $fatal(1, "RAM stall or routing failure");
        end
        allow_req[0] = 1;
        @(posedge clk);
        if (!req_ready) $fatal(1, "RAM did not accept request");
        @(negedge clk);
        req_valid = 0;
        // The master holds off consuming a completed response; data must remain stable.
        wait (resp_valid);
        repeat (3) begin
            @(negedge clk);
            if (!resp_valid || resp_rdata !== 32'hA100_0024 || req_ready)
                $fatal(1, "response backpressure failure");
        end
        response(32'hA100_0024, 0);
        if (count_r !== 1 || count_f !== 0 || count_u !== 0 || addr_r !== 32'h24)
            $fatal(1, "RAM decode/count failure");

        request(32'h20ff_fffc, 0, 0, 0);
        response(32'hF1ff_fffc, 0);
        if (count_f !== 1 || addr_f !== 32'h00ff_fffc) $fatal(1, "flash boundary failure");

        request(32'h1000_0004, 32'h1234_abcd, 1, 4'b0101);
        response(0, 0);
        if (count_u !== 1 || addr_u !== 4 || !wr_u || wd_u !== 32'h1234_abcd || st_u !== 4'b0101)
            $fatal(1, "UART write payload failure");

        request(32'h8200_0000, 0, 0, 0); // first byte past RAM
        response(0, 1);
        request(32'h20ff_ffff, 0, 0, 0); // last byte of flash
        response(32'hF1ff_ffff, 0);
        request(32'h2100_0000, 0, 0, 0); // first byte past flash
        response(0, 1);
        if (count_r !== 1 || count_f !== 2 || count_u !== 1)
            $fatal(1, "unexpected request on a device");
        $display("PASS physical_bus: decode, boundaries, stalls, response hold, writes, misses");
        $finish;
    end
endmodule
