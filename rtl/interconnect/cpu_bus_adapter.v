`timescale 1ns/1ps
// Two CPU request ports to the single-outstanding physical bus.
// Data wins a simultaneous request; the current core never issues both.
module cpu_bus_adapter (
    input wire clk, rst_n,
    input wire i_req_valid,
    output wire i_req_ready,
    input wire [31:0] i_req_addr,
    output wire i_resp_valid,
    input wire i_resp_ready,
    output wire [31:0] i_resp_data,
    output wire i_resp_err,
    input wire d_req_valid,
    output wire d_req_ready,
    input wire [31:0] d_req_addr,
    input wire d_req_write,
    input wire [31:0] d_req_wdata,
    input wire [3:0] d_req_wstrb,
    output wire d_resp_valid,
    input wire d_resp_ready,
    output wire [31:0] d_resp_data,
    output wire d_resp_err,
    output wire bus_req_valid,
    input wire bus_req_ready,
    output wire [31:0] bus_req_addr,
    output wire bus_req_write,
    output wire [31:0] bus_req_wdata,
    output wire [3:0] bus_req_wstrb,
    input wire bus_resp_valid,
    output wire bus_resp_ready,
    input wire [31:0] bus_resp_data,
    input wire bus_resp_err
);
    localparam [1:0] IDLE = 2'd0, WAIT_I = 2'd1, WAIT_D = 2'd2;
    reg [1:0] state;
    wire choose_d = d_req_valid;
    assign bus_req_valid = state == IDLE && rst_n && (d_req_valid || i_req_valid);
    assign bus_req_addr = choose_d ? d_req_addr : i_req_addr;
    assign bus_req_write = choose_d && d_req_write;
    assign bus_req_wdata = choose_d ? d_req_wdata : 32'b0;
    assign bus_req_wstrb = choose_d ? d_req_wstrb : 4'b0;
    assign d_req_ready = state == IDLE && rst_n && d_req_valid && bus_req_ready;
    assign i_req_ready = state == IDLE && rst_n && !d_req_valid && i_req_valid && bus_req_ready;
    assign i_resp_valid = state == WAIT_I && bus_resp_valid;
    assign d_resp_valid = state == WAIT_D && bus_resp_valid;
    assign i_resp_data = bus_resp_data;
    assign d_resp_data = bus_resp_data;
    assign i_resp_err = bus_resp_err;
    assign d_resp_err = bus_resp_err;
    assign bus_resp_ready = (state == WAIT_I && i_resp_ready) ||
                            (state == WAIT_D && d_resp_ready);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else case (state)
            IDLE: if (bus_req_valid && bus_req_ready)
                state <= choose_d ? WAIT_D : WAIT_I;
            WAIT_I, WAIT_D: if (bus_resp_valid && bus_resp_ready) state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
