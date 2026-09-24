`timescale 1ns/1ps
module rv32i_core_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    wire i_req_valid, i_req_ready, i_resp_valid, i_resp_ready, i_resp_err;
    wire [31:0] i_req_addr, i_resp_data;
    wire d_req_valid, d_req_ready, d_resp_valid, d_resp_ready, d_resp_err;
    wire [31:0] d_req_addr, d_req_wdata, d_resp_data;
    wire d_req_write;
    wire [3:0] d_req_wstrb;
    wire bus_req_valid, bus_req_ready, bus_resp_valid, bus_resp_ready, bus_resp_err;
    wire [31:0] bus_req_addr, bus_req_wdata, bus_resp_data;
    wire bus_req_write;
    wire [3:0] bus_req_wstrb;
    wire [31:0] dev_addr, dev_wdata;
    wire dev_write;
    wire [3:0] dev_wstrb;
    wire ram_req_valid, ram_req_ready, ram_resp_valid, ram_resp_ready, ram_resp_err;
    wire [31:0] ram_resp_data, ram_reads, ram_writes;
    wire flash_req_valid, flash_resp_ready;
    wire uart_req_valid, uart_req_ready, uart_resp_valid, uart_resp_ready, uart_resp_err;
    wire [31:0] uart_resp_data;
    wire tx_valid;
    wire [7:0] tx_data;
    wire halted, fault, retire_valid;
    wire [31:0] fault_pc, retire_pc;
    integer cycles = 0, retired = 0, stalls = 0, tx_count = 0;
    integer deadline;
    reg [7:0] tx_bytes [0:2];

    rv32i_core core (
        .clk(clk), .rst_n(rst_n),
        .i_req_valid(i_req_valid), .i_req_ready(i_req_ready), .i_req_addr(i_req_addr),
        .i_resp_valid(i_resp_valid), .i_resp_ready(i_resp_ready), .i_resp_data(i_resp_data), .i_resp_err(i_resp_err),
        .d_req_valid(d_req_valid), .d_req_ready(d_req_ready), .d_req_addr(d_req_addr),
        .d_req_write(d_req_write), .d_req_wdata(d_req_wdata), .d_req_wstrb(d_req_wstrb),
        .d_resp_valid(d_resp_valid), .d_resp_ready(d_resp_ready), .d_resp_data(d_resp_data), .d_resp_err(d_resp_err),
        .halted(halted), .fault(fault), .fault_pc(fault_pc), .retire_valid(retire_valid), .retire_pc(retire_pc)
    );
    cpu_bus_adapter adapter (
        .clk(clk), .rst_n(rst_n),
        .i_req_valid(i_req_valid), .i_req_ready(i_req_ready), .i_req_addr(i_req_addr),
        .i_resp_valid(i_resp_valid), .i_resp_ready(i_resp_ready), .i_resp_data(i_resp_data), .i_resp_err(i_resp_err),
        .d_req_valid(d_req_valid), .d_req_ready(d_req_ready), .d_req_addr(d_req_addr),
        .d_req_write(d_req_write), .d_req_wdata(d_req_wdata), .d_req_wstrb(d_req_wstrb),
        .d_resp_valid(d_resp_valid), .d_resp_ready(d_resp_ready), .d_resp_data(d_resp_data), .d_resp_err(d_resp_err),
        .bus_req_valid(bus_req_valid), .bus_req_ready(bus_req_ready), .bus_req_addr(bus_req_addr),
        .bus_req_write(bus_req_write), .bus_req_wdata(bus_req_wdata), .bus_req_wstrb(bus_req_wstrb),
        .bus_resp_valid(bus_resp_valid), .bus_resp_ready(bus_resp_ready),
        .bus_resp_data(bus_resp_data), .bus_resp_err(bus_resp_err)
    );
    physical_bus bus (
        .clk(clk), .rst_n(rst_n), .req_valid(bus_req_valid), .req_ready(bus_req_ready),
        .req_addr(bus_req_addr), .req_write(bus_req_write), .req_wdata(bus_req_wdata), .req_wstrb(bus_req_wstrb),
        .resp_valid(bus_resp_valid), .resp_ready(bus_resp_ready), .resp_rdata(bus_resp_data), .resp_err(bus_resp_err),
        .dev_addr(dev_addr), .dev_write(dev_write), .dev_wdata(dev_wdata), .dev_wstrb(dev_wstrb),
        .ram_req_valid(ram_req_valid), .ram_req_ready(ram_req_ready),
        .ram_resp_valid(ram_resp_valid), .ram_resp_ready(ram_resp_ready),
        .ram_resp_rdata(ram_resp_data), .ram_resp_err(ram_resp_err),
        .flash_req_valid(flash_req_valid), .flash_req_ready(1'b0),
        .flash_resp_valid(1'b0), .flash_resp_ready(flash_resp_ready),
        .flash_resp_rdata(32'b0), .flash_resp_err(1'b1),
        .uart_req_valid(uart_req_valid), .uart_req_ready(uart_req_ready),
        .uart_resp_valid(uart_resp_valid), .uart_resp_ready(uart_resp_ready),
        .uart_resp_rdata(uart_resp_data), .uart_resp_err(uart_resp_err),
        .rom_req_valid(), .rom_req_ready(1'b0), .rom_resp_valid(1'b0),
        .rom_resp_ready(), .rom_resp_rdata(32'b0), .rom_resp_err(1'b1),
        .timer_req_valid(), .timer_req_ready(1'b0), .timer_resp_valid(1'b0),
        .timer_resp_ready(), .timer_resp_rdata(32'b0), .timer_resp_err(1'b1)
    );
    word_ram ram (
        .clk(clk), .rst_n(rst_n), .req_valid(ram_req_valid), .req_ready(ram_req_ready),
        .req_addr(dev_addr), .req_write(dev_write), .req_wdata(dev_wdata), .req_wstrb(dev_wstrb),
        .resp_valid(ram_resp_valid), .resp_ready(ram_resp_ready),
        .resp_rdata(ram_resp_data), .resp_err(ram_resp_err),
        .read_count(ram_reads), .write_count(ram_writes)
    );
    mmio_uart_sink uart (
        .clk(clk), .rst_n(rst_n), .req_valid(uart_req_valid), .req_ready(uart_req_ready),
        .req_addr(dev_addr), .req_write(dev_write), .req_wdata(dev_wdata), .req_wstrb(dev_wstrb),
        .resp_valid(uart_resp_valid), .resp_ready(uart_resp_ready),
        .resp_rdata(uart_resp_data), .resp_err(uart_resp_err),
        .tx_valid(tx_valid), .tx_data(tx_data)
    );

    always @(posedge clk) begin
        if (rst_n) begin
            cycles <= cycles + 1;
            if (retire_valid) retired <= retired + 1;
            if (ram_req_valid && !ram_req_ready) stalls <= stalls + 1;
            if (tx_valid) begin
                if (tx_count >= 3) $fatal(1, "too many UART bytes");
                tx_bytes[tx_count] <= tx_data;
                tx_count <= tx_count + 1;
            end
        end
    end
    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        while (!halted && cycles < 2000) @(negedge clk);
        if (!halted) $fatal(1, "CPU timeout at cycle %0d", cycles);
        if (fault) $fatal(1, "CPU fault at PC %h", fault_pc);
        if (ram.words[1024] !== 32'h0000_0123) $fatal(1, "word store/load failed");
        if (ram.words[1025] !== 32'h0123_00ff) $fatal(1, "byte/halfword stores failed: %h", ram.words[1025]);
        if (ram.words[1026] < 32'h8000_0000 || ram.words[1026] > 32'h8000_0400)
            $fatal(1, "AUIPC/PC write failed: %h", ram.words[1026]);
        if (ram.words[1027] !== 32'h5a5a_a5a5) $fatal(1, "program signature failed: %h", ram.words[1027]);
        if (tx_count !== 3 || tx_bytes[0] !== "O" || tx_bytes[1] !== "K" || tx_bytes[2] !== 8'h0a)
            $fatal(1, "UART output failure count=%0d bytes=%h %h %h", tx_count, tx_bytes[0], tx_bytes[1], tx_bytes[2]);
        if (stalls == 0 || retired < 30 || ram_reads < 30 || ram_writes < 5)
            $fatal(1, "coverage failure stalls=%0d retired=%0d reads=%0d writes=%0d",
                   stalls, retired, ram_reads, ram_writes);
        $display("PASS rv32i_core: %0d cycles, %0d retired, %0d RAM stalls, UART OK", cycles, retired, stalls);

        // An illegal instruction must stop at its own PC, before any data access.
        rst_n = 0;
        ram.words[0] = 32'hffff_ffff;
        repeat (3) @(negedge clk);
        rst_n = 1;
        deadline = cycles + 30;
        while (!halted && cycles < deadline) @(negedge clk);
        if (!halted || !fault || fault_pc !== 32'h8000_0000)
            $fatal(1, "illegal instruction fault failure pc=%h", fault_pc);

        // A valid LW to an unmapped physical address must propagate bus error.
        rst_n = 0;
        ram.words[0] = 32'h4000_02b7; // lui t0,0x40000
        ram.words[1] = 32'h0002_a303; // lw t1,0(t0)
        repeat (3) @(negedge clk);
        rst_n = 1;
        deadline = cycles + 50;
        while (!halted && cycles < deadline) @(negedge clk);
        if (!halted || !fault || fault_pc !== 32'h8000_0004)
            $fatal(1, "bus-error fault failure pc=%h", fault_pc);

        // A misaligned LW must fault before issuing a memory request.
        rst_n = 0;
        ram.words[0] = 32'h8000_02b7; // lui t0,0x80000
        ram.words[1] = 32'h0012_a303; // lw t1,1(t0)
        repeat (3) @(negedge clk);
        rst_n = 1;
        deadline = cycles + 50;
        while (!halted && cycles < deadline) @(negedge clk);
        if (!halted || !fault || fault_pc !== 32'h8000_0004)
            $fatal(1, "misaligned-load fault failure pc=%h", fault_pc);
        $display("PASS rv32i_core faults: illegal, unmapped load, misaligned load");
        $finish;
    end
endmodule
