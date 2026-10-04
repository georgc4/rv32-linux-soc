`timescale 1ns/1ps
module serial_memory_model_tb;
    reg cs = 1, sck = 0;
    reg [3:0] dout = 0, oe = 1;
    wire [3:0] din, drive;
    wire [31:0] count;
        wire [3:0] flash_out, flash_oe, ram_out, ram_oe;
    reg use_ram = 0;
    assign din = use_ram ? ram_out : flash_out;
    assign drive = use_ram ? ram_oe : flash_oe;
    serial_memory_datasheet_model #(.IS_FLASH(1), .MEM_BYTES(8192),
        .T_PROGRAM(10000), .T_ERASE(20000)) flash (
        .cs_n(use_ram ? 1'b1 : cs), .sck(sck), .io_in(dout), .host_oe(oe),
        .io_out(flash_out), .io_oe(flash_oe), .command_count(count));
    serial_memory_datasheet_model #(.MEM_BYTES(8192)) ram (
        .cs_n(use_ram ? cs : 1'b1), .sck(sck), .io_in(dout), .host_oe(oe),
        .io_out(ram_out), .io_oe(ram_oe), .command_count());
    task start;
        begin #100; cs = 0; #50; end
    endtask
    task stop;
        begin #50; cs = 1; #100; end
    endtask
    task send_bit(input reg b);
        begin dout = {3'b0,b}; oe = 1; #50; sck = 1; #50; sck = 0; end
    endtask
    task byte_out(input reg [7:0] b);
        for (integer n = 7; n >= 0; n = n-1) send_bit(b[n]);
    endtask
    task addr_out(input reg [23:0] a);
        begin byte_out(a[23:16]); byte_out(a[15:8]); byte_out(a[7:0]); end
    endtask
    task cmd(input reg [7:0] c);
        begin start; byte_out(c); stop; end
    endtask
    task status_read(output reg [7:0] b);
        begin
            start; byte_out(8'h05); oe = 0;
            for (integer n = 7; n >= 0; n = n-1) begin
                #50; sck = 1; b[n] = din[1];
                if (drive !== 2) $fatal(1,"status OE");
                #50; sck = 0;
            end
            stop;
        end
    endtask
    task program_byte(input reg [23:0] a, input reg [7:0] b);
        begin start; byte_out(2); addr_out(a); byte_out(b); stop; end
    endtask
    reg [7:0] status;
    string scenario;
    initial begin
        if (!$value$plusargs("case=%s", scenario)) scenario = "flash";
        if (scenario == "startup_pins") begin #100; sck=1; end
        else if (scenario == "powerup") begin #100; start; end
        else if (scenario == "write_powerup") begin
            #200000; cmd(6); program_byte(0, 0);
        end else begin
            #5000100;
            if (scenario == "flash") begin
                if (flash.memory[0] !== 255) $fatal(1,"erased initial array");
                program_byte(0, 0); // without WREN must not mutate
                #20000;
                if (flash.memory[0] !== 255 || flash.busy) $fatal(1,"missing WEL ignored");
                start; byte_out(6);
                if (flash.wel) $fatal(1,"WEL changed before CS rise");
                stop;
                if (!flash.wel) $fatal(1,"WREN failed");
                start; byte_out(2); addr_out(255); byte_out(8'h5a); byte_out(8'ha5);
                if (flash.busy || flash.memory[255] !== 255) $fatal(1,"program committed early");
                stop;
                if (!flash.busy || flash.memory[255] !== 255) $fatal(1,"program not deferred");
                status_read(status);
                if (!status[0]) $fatal(1,"BUSY not set");
                // Commands during BUSY must not clobber pending page contents.
                program_byte(255, 0);
                #11000;
                if (flash.busy || flash.wel || flash.memory[255] !== 8'h5a ||
                    flash.memory[0] !== 8'ha5 || flash.memory[256] !== 8'hff)
                    $fatal(1,"page wrap / elapsed BUSY / busy command ignore");
                cmd(6); program_byte(255, 8'h0f); #11000;
                if (flash.memory[255] !== 8'h0a) $fatal(1,"NOR must only clear bits");
                cmd(6); start; byte_out(2); addr_out(0); byte_out(0); send_bit(0); stop;
                #11000;
                if (flash.memory[0] !== 8'ha5 || flash.busy) $fatal(1,"partial-byte program not discarded");
                cmd(6); start; byte_out(8'h20); addr_out(129); stop;
                if (!flash.busy || flash.memory[255] !== 8'h0a) $fatal(1,"erase committed early");
                #21000;
                if (flash.busy || flash.memory[0] !== 255 || flash.memory[4095] !== 255)
                    $fatal(1,"sector erase / elapsed completion");
                cmd(6); cmd(4); status_read(status);
                if (status !== 0) $fatal(1,"WRDI/status");
            end else if (scenario == "output") begin
                flash.memory[0] = 8'h80;
                start; byte_out(8'h03); addr_out(0);
                #5; if (drive !== 0) $fatal(1,"output enabled before tCLQV");
                #2; if (drive !== 2 || din[1] !== 1) $fatal(1,"output late or wrong");
                #43; sck=1; #50; sck=0;
                #1; if (din[1] !== 1) $fatal(1,"output hold lost");
                #6; if (din[1] !== 0) $fatal(1,"next data bit missing");
                #50; cs=1;
                #1; if (drive !== 2) $fatal(1,"output disabled without tSHQZ delay");
                #7; if (drive !== 0) $fatal(1,"output not released");
            end else if (scenario == "ram") begin
                use_ram = 1; cmd(8'h66); cmd(8'h99);
                start; byte_out(2); addr_out(1023); byte_out(8'h5a); byte_out(8'ha5); stop;
                if (ram.memory[1023] !== 8'h5a || ram.memory[1024] !== 8'ha5)
                    $fatal(1,"linear page crossing");
                cmd(8'h66); cmd(8'h99);
                if (ram.memory[1023] !== 8'h5a) $fatal(1,"reset lost RAM data");
            end else if (scenario == "reset") begin use_ram = 1; cmd(8'h99); end
            else if (scenario == "reset_interrupted") begin
                use_ram=1; cmd(8'h66); cmd(8'h99); cmd(8'h66);
                start; byte_out(8'h03); addr_out(0); stop; cmd(8'h99);
            end
            else if (scenario == "no_reset") begin use_ram = 1; cmd(8'heb); end
            else if (scenario == "cs_low") begin use_ram = 1; start; #9000; end
            else if (scenario == "cs_high") begin
                use_ram = 1; cmd(8'h66); start; byte_out(8'h99); #50; cs=1; #10; cs=0;
            end else if (scenario == "setup") begin start; dout=1; #0.5; sck=1; end
            else if (scenario == "hold") begin start; send_bit(0); #50; sck=1; #1; dout=1; end
            else if (scenario == "undriven") begin start; oe=0; #50; sck=1; end
            else if (scenario == "unsupported") cmd(8'hff);
            else if (scenario == "capacity") begin
                start; byte_out(8'h03); addr_out(8192); #100;
            end else if (scenario == "clock") begin start; send_bit(0); #1; sck=1; end
            else $fatal(1,"unknown scenario");
        end
        #1; // let pin-edge monitors run before checking for a missed violation
        if (scenario != "flash" && scenario != "ram" && scenario != "output") $fatal(1,"EXPECTED_VIOLATION_NOT_DETECTED");
        $display("PASS datasheet model %s", scenario); $finish;
    end
endmodule
