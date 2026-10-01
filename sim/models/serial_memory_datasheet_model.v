`timescale 1ns/1ps
// Strict mode-0 digital model of the commands used by this SoC. See
// docs/verification/datasheet-memory-models.md for sources and coverage limits.
// Time zero denotes stable VCC. No pad, PCB, refresh physics or voltage model.
module serial_memory_datasheet_model #(
    parameter IS_FLASH = 0,
    parameter integer MEM_BYTES = IS_FLASH ? 16777216 : 8388608,
    parameter realtime T_OUTPUT = 6.0,
    parameter realtime T_DISABLE = IS_FLASH ? 7.0 : 6.0,
    parameter realtime T_PROGRAM = 3000000.0,
    parameter realtime T_ERASE = 400000000.0,
    parameter realtime T_WRITE_POWERUP = 5000000.0
) (
    input wire cs_n, sck,
    input wire [3:0] io_in, host_oe,
    output reg [3:0] io_out = 0,
    output reg [3:0] io_oe = 0,
    output integer command_count = 0
);
    reg [7:0] memory [0:MEM_BYTES-1];
    reg [7:0] page [0:255];
    reg [255:0] page_valid = 0;
    reg [7:0] command = 0, shift = 0, status_latch = 0;
    reg [23:0] address = 0;
    reg wel = 0, busy = 0, reset_enabled = 0, reset_done = 0;
    reg ignored = 0;
    integer bits = 0, data_bytes = 0;
    integer i, offset, pending_address;
    reg pending_erase;
    event operation;
    realtime selected_at = 0, deselected_at = 0;
    realtime rise_at = -1000, fall_at = -1000;
    realtime lane_changed [0:3];
    reg [3:0] old_input = 0, sampled_mask = 0;
    realtime cs_gap = IS_FLASH ? 10.0 : 50.0;
    realtime period_min;
    reg [3:0] sample_mask;

    function integer index_at;
        input integer a;
        begin
            // Real parts ignore PSRAM A23 and wrap at their physical capacity.
            a = a & (IS_FLASH ? 24'hffffff : 24'h7fffff);
            if (a >= MEM_BYTES)
                $fatal(1, "%m MODEL_CAPACITY address=%h allocation=%0d", a, MEM_BYTES);
            index_at = a;
        end
    endfunction

    initial begin
        // PSRAM power-up contents are unspecified. Catch reads before writes.
        for (i = 0; i < MEM_BYTES; i = i + 1)
            memory[i] = IS_FLASH ? 8'hff : 8'hxx;
        for (i = 0; i < 4; i = i + 1) lane_changed[i] = -1000;
    end

    // Flash operations consume elapsed time, regardless of status polling.
    // Mutations become visible only after the self-timed operation completes.
    initial forever begin
        @operation;
        if (pending_erase) begin
            #(T_ERASE);
            for (integer j = 0; j < 4096; j = j + 1)
                memory[index_at(pending_address + j)] = 8'hff;
        end else begin
            #(T_PROGRAM);
            for (integer j = 0; j < 256; j = j + 1)
                if (page_valid[j])
                    memory[index_at(pending_address + j)] =
                        memory[index_at(pending_address + j)] & page[j];
        end
        busy = 0;
        wel = 0;
    end

    always @(io_in) begin
        for (integer k = 0; k < 4; k = k + 1) begin
            if (io_in[k] !== old_input[k]) begin
                if (!cs_n && sampled_mask[k] && $realtime - rise_at < 2.0)
                    $fatal(1, "%m DATA_HOLD lane=%0d", k);
                lane_changed[k] = $realtime;
            end
        end
        old_input = io_in;
    end

    // Shared clock/data must stay low during PSRAM power-up. Undriven
    // inputs stand for the board's specified external pull-downs.
    always @(sck or io_in or host_oe) begin
        if (!IS_FLASH && $realtime > 0 && $realtime < 150000.0 &&
            (sck === 1'b1 || (io_in & host_oe) != 0))
            $fatal(1, "%m POWERUP_PINS");
    end

    always @(negedge cs_n) begin
        if ($realtime < (IS_FLASH ? 20000.0 : 150000.0))
            $fatal(1, "%m POWERUP_WAIT");
        if ($realtime - deselected_at < cs_gap)
            $fatal(1, "%m CS_HIGH gap=%0.3f required=%0.3f", $realtime-deselected_at, cs_gap);
        if (sck !== 0) $fatal(1, "%m MODE0_CS_SETUP");
        selected_at = $realtime;
        bits = 0;
        command = 0;
        address = 0;
        shift = 0;
        data_bytes = 0;
        ignored = 0;
    end

    // Also catches a controller that hangs with CE# asserted and no clocks.
    initial forever begin
        #1000;
        if (!IS_FLASH && !cs_n && $realtime - selected_at > 8000.0)
            $fatal(1, "%m CS_LOW_REFRESH maximum=8000ns");
    end

    always @(posedge cs_n) begin
        if (bits != 0) begin
            if ($realtime - rise_at < (IS_FLASH ? 3.0 : 20.0))
                $fatal(1, "%m CS_HOLD");
            if (!IS_FLASH && $realtime - selected_at > 8000.0)
                $fatal(1, "%m CS_LOW_REFRESH maximum=8000ns");
            if (!ignored) begin
                if (!IS_FLASH && command == 8'h66 && bits == 8)
                    reset_enabled = 1;
                else if (!IS_FLASH && command == 8'h99 && bits == 8) begin
                    if (!reset_enabled) $fatal(1, "%m RESET_SEQUENCE");
                    reset_done = 1;
                    reset_enabled = 0;
                end else begin
                    if (!IS_FLASH) reset_enabled = 0;
                    if (IS_FLASH && command == 8'h06 && bits == 8) begin
                        if ($realtime < T_WRITE_POWERUP) $fatal(1, "%m WRITE_POWERUP_WAIT");
                        wel = 1;
                    end
                    if (IS_FLASH && command == 8'h04 && bits == 8) wel = 0;
                    if (IS_FLASH && wel && ((command == 8'h02 && bits >= 40 &&
                        (bits-32)%8 == 0) || (command == 8'h20 && bits == 32))) begin
                        if ($realtime < T_WRITE_POWERUP) $fatal(1, "%m WRITE_POWERUP_WAIT");
                        pending_erase = command == 8'h20;
                        pending_address = address & (pending_erase ? 24'hfff000 : 24'hffff00);
                        busy = 1;
                        -> operation;
                    end
                end
            end
            cs_gap = (!IS_FLASH || command == 8'h02 || command == 8'h20 ||
                       command == 8'h06 || command == 8'h04) ? 50.0 : 10.0;
        end
        deselected_at = $realtime;
        sampled_mask = 0;
        io_oe <= #(T_DISABLE) 0;
        io_out <= #(T_DISABLE) 0;
    end

    always @(posedge sck) if (!cs_n) begin
        if ($realtime - selected_at < (IS_FLASH ? 3.0 : 2.5))
            $fatal(1, "%m CS_SETUP");
        period_min = command == 8'h03 ? (IS_FLASH ? 20.0 : 30.304) :
                     (IS_FLASH ? 7.519 : 11.905); // PSRAM linear page crossing: 84MHz
        if (bits > 0 && $realtime - rise_at < period_min)
            $fatal(1, "%m CLOCK_PERIOD");
        if (bits > 0 && $realtime - fall_at < period_min * 0.45)
            $fatal(1, "%m CLOCK_LOW");
        sample_mask = 0;
        if (bits < 8) sample_mask = 4'b0001;
        else if (!IS_FLASH && (command == 8'heb || command == 8'h38)) begin
            if (bits < 14 || command == 8'h38) sample_mask = 4'b1111;
        end else if ((command == 8'h03 || command == 8'h0b || command == 8'h02 ||
                      command == 8'h20 || command == 8'h6b) && bits < 32)
            sample_mask = 4'b0001;
        else if (command == 8'h02) sample_mask = 4'b0001;
        for (integer k = 0; k < 4; k = k + 1) if (sample_mask[k]) begin
            if (host_oe[k] !== 1'b1 || (io_in[k] !== 0 && io_in[k] !== 1))
                $fatal(1, "%m INPUT_UNDRIVEN lane=%0d", k);
            if ($realtime - lane_changed[k] < (IS_FLASH ? 1.0 : 2.0))
                $fatal(1, "%m DATA_SETUP lane=%0d", k);
        end
        sampled_mask = sample_mask;
        rise_at = $realtime;
        if (bits < 8) begin
            shift = {shift[6:0], io_in[0]};
            if (bits == 7) begin
                command = shift;
                command_count = command_count + 1;
                ignored = IS_FLASH && busy && command != 8'h05 && command != 8'h35;
                if (!ignored) begin
                    if (IS_FLASH) begin
                        case (command)
                            8'h03,8'h0b,8'h6b,8'h05,8'h35,8'h06,8'h04,8'h02,8'h20: ;
                            default: $fatal(1, "%m UNSUPPORTED_COMMAND %h", command);
                        endcase
                        if (command == 8'h02) page_valid = 0;
                    end else begin
                        case (command)
                            8'h03,8'h0b,8'heb,8'h02,8'h38,8'h66,8'h99: ;
                            default: $fatal(1, "%m UNSUPPORTED_COMMAND %h", command);
                        endcase
                        if (!reset_done && command != 8'h66 && command != 8'h99)
                            $fatal(1, "%m RESET_REQUIRED");
                    end
                end
            end
        end else if (!ignored) begin
            if (!IS_FLASH && (command == 8'heb || command == 8'h38) && bits < 14)
                address = {address[19:0], io_in};
            else if ((command == 8'h03 || command == 8'h0b || command == 8'h02 ||
                      command == 8'h20 || command == 8'h6b) && bits < 32)
                address = {address[22:0], io_in[0]};
            else if (!IS_FLASH && command == 8'h38 && bits >= 14) begin
                shift = {shift[3:0], io_in};
                if ((bits-14)%2 == 1) memory[index_at(address+(bits-14)/2)] = shift;
            end else if (command == 8'h02 && bits >= 32) begin
                shift = {shift[6:0], io_in[0]};
                if ((bits-32)%8 == 7) begin
                    if (IS_FLASH && wel) begin
                        offset = (address + data_bytes) & 255;
                        page[offset] = shift;
                        page_valid[offset] = 1;
                    end else if (!IS_FLASH) memory[index_at(address+data_bytes)] = shift;
                    data_bytes = data_bytes + 1;
                end
            end
        end
        bits = bits + 1;
    end

    always @(negedge sck) begin
        fall_at = $realtime;
        if (!cs_n) begin
            if ($realtime - rise_at < period_min * 0.45)
                $fatal(1, "%m CLOCK_HIGH");
            if (!ignored) begin
                if (IS_FLASH && (command == 8'h05 || command == 8'h35) && bits >= 8) begin
                    if ((bits-8)%8 == 0)
                        status_latch = command == 8'h35 ? 8'h02 : {6'b0,wel,busy};
                    io_oe <= #(T_OUTPUT) 4'b0010;
                    io_out <= #(T_OUTPUT) {2'b0,status_latch[7-(bits-8)%8],1'b0};
                end else if ((command == 8'h03 && bits >= 32) ||
                             (command == 8'h0b && bits >= 40)) begin
                    offset = bits - (command == 8'h03 ? 32 : 40);
                    io_oe <= #(T_OUTPUT) 4'b0010;
                    io_out <= #(T_OUTPUT) {2'b0,memory[index_at(address+offset/8)][7-offset%8],1'b0};
                end else if ((!IS_FLASH && command == 8'heb && bits >= 20) ||
                             (IS_FLASH && command == 8'h6b && bits >= 40)) begin
                    offset = bits - (IS_FLASH ? 40 : 20);
                    io_oe <= #(T_OUTPUT) 4'b1111;
                    io_out <= #(T_OUTPUT) offset%2 == 0 ?
                        memory[index_at(address+offset/2)][7:4] : memory[index_at(address+offset/2)][3:0];
                end
            end
        end
    end
endmodule
