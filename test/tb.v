`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  wire [7:0] uio_in;
  reg corrupt_image = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Same external chip models in RTL and final gate-netlist simulation.
  // Small allocations deliberately fail on out-of-range access; the bridge
  // matrix separately allocates the actual 4 x 8MiB + 16MiB capacities.
  wire [4:0] cs = {uo_out[5], uo_out[6], uo_out[3:1]};
  wire [3:0] mo [0:4], me [0:4];
  wire [31:0] commands [0:4];
  wire [3:0] ram_bus = (mo[0]&me[0]) | (mo[1]&me[1]) |
                      (mo[2]&me[2]) | (mo[3]&me[3]);
  wire [3:0] ram_drive = me[0] | me[1] | me[2] | me[3];
  wire [3:0] flash_bus = mo[4]&me[4];
  wire [5:0] chip_drive = {me[4][3:2],ram_drive[3:2],ram_drive[1:0]|me[4][1:0]};
  assign uio_in = {2'b0, (uio_out[5:0]&uio_oe[5:0]) |
                        {flash_bus[3:2],ram_bus[3:2],flash_bus[1:0]|ram_bus[1:0]}};
  genvar g;
  generate for (g=0; g<5; g=g+1) begin: chips
    serial_memory_datasheet_model #(.IS_FLASH(g==4), .MEM_BYTES(8192)) model (
      .cs_n(cs[g]), .sck(uo_out[0]),
      .io_in(g==4 ? {uio_out[5:4],uio_out[1:0]} : uio_out[3:0]),
      .host_oe(g==4 ? {uio_oe[5:4],uio_oe[1:0]} : uio_oe[3:0]),
      .io_out(mo[g]), .io_oe(me[g]), .command_count(commands[g]));
  end endgenerate
  wire [31:0] signature = {chips[0].model.memory[4111],chips[0].model.memory[4110],
                           chips[0].model.memory[4109],chips[0].model.memory[4108]};
  reg [31:0] image [0:87];
  reg [31:0] checksum = 0;
  initial begin
    $readmemh("../sim/programs/rv32i_smoke.hex", image);
    #1;
    for (integer j=0; j<16; j=j+1) chips[4].model.memory[j] = 0;
    for (integer j=0; j<88; j=j+1) begin
      checksum = checksum + image[j];
      for (integer k=0; k<4; k=k+1)
        chips[4].model.memory[16+4*j+k] = image[j][8*k+:8];
    end
    chips[4].model.memory[0] = 8'h42;
    chips[4].model.memory[1] = 8'h53;
    chips[4].model.memory[2] = 8'h56;
    chips[4].model.memory[3] = 8'h52;
    chips[4].model.memory[4] = 88;
    for (integer k=0; k<4; k=k+1) chips[4].model.memory[8+k] = checksum[8*k+:8];
  end
  always @(posedge corrupt_image)
    chips[4].model.memory[8] = chips[4].model.memory[8] ^ 8'h01;

  always @(posedge uo_out[0]) if (rst_n) begin
    if (((~cs & 5'h1f) & ((~cs & 5'h1f)-5'd1)) != 0)
      $fatal(1,"multiple external memories selected");
    if ((uio_oe[5:0] & chip_drive) != 0)
      $fatal(1,"external memory bus contention");
  end

  always @(uio_oe or chip_drive) begin
    #0.001;
    if (rst_n && (uio_oe[5:0] & chip_drive) != 0)
      $fatal(1,"external memory overlap during bus turnaround");
  end

  tt_um_rv32_linux_soc user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
