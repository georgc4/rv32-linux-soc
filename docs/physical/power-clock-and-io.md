# Power delivery, clock, reset, and external electrical interface

**Scope:** implementation boundary and required measurements. There is no chip power signoff or measured silicon current in this repository. Supply nets, standard-cell taps, PDN straps, and shuttle interfaces come from the pinned Tiny Tapeout/LibreLane physical configuration, not `soc_top` RTL.

## Power domains and delivery path

The SKY130 standard-cell mapping uses 1.8 V core cells. The Tiny Tapeout wrapper exposes only logical project signals; the physical flow integrates the project into a shuttle power/pad framework. Its staged `src/config.json` inherits the template PDN configuration, including `FP_PDN_VPITCH=38.87` and `FP_PDN_MULTILAYER=0` in the current local stage. These are flow inputs, not proof of acceptable IR drop or current density. The actual grid, taps, vias, rails, source pads, and connection to shuttle metal must be inspected in the final DEF/GDS and template documentation for the selected run.

The external PSRAM/NOR and FPGA/demoboard IO use their own board-side supplies and level requirements. The provisional Tang Nano 20K 3921 UART path is 3.3 V LVCMOS; Tiny Tapeout external UART wiring uses a 3.3 V signal-level adapter in the documented fallback. Do not apply a 5 V RS-232 swing. The memory part numbers, IO voltage, pull resistors, decoupling, and voltage compatibility must be confirmed against the actual purchased chips and selected shuttle carrier. A logical RTL `spi_dq_oe` bit only describes drive intent; pad strength and turn-around timing are physical constraints.

## How to produce a real power budget

Dynamic power is approximately `α C V² f` summed over internal nets and pad loads; leakage depends on library/process/temperature. The core's large banked register file and 64-bit MDU work register contribute clocked capacitance, while off-chip SCK/DQ and five selects contribute pad and board capacitance. The uncached serial architecture reduces parallel activity but keeps the core and SPI active for a long boot. For a defensible estimate: use representative switching activity from full boot and shell traces, map it to the exact routed netlist and extracted capacitances, run power at relevant process/voltage/temperature corners, then check current delivery with PDN resistance and IR drop. Also review electromigration limits, simultaneous switching noise, reset/power-up transient, and decoupling with the actual board. None of those analyses is represented by a Yosys cell-area number.

## Clock and reset

The SoC expects one 20 MHz input clock. The nominal physical constraint is 50 ns, but silicon frequency needs routed path timing plus IO timing. The FPGA wrapper requires the Tang Nano's MS5351 CLK0 to be explicitly set to 20 MHz; programming USB alone does not establish the SoC clock. The Tiny Tapeout demoboard project clock is user-configurable, so its final setting must be measured or confirmed. SCK changes in the serial bridge and has an approximate half-rate transfer cadence. The Linux DTB, timer base, UART divisor, and firmware assumptions all use 20 MHz; changing the clock requires auditing all four.

`rst_n` is active low and asynchronous in many RTL state elements. Deassertion timing, metastability, external supply ramp, and synchronization at the physical pin need review. The UART RX path has two synchronization flops; SPI inputs are sampled relative to the generated SCK phase and depend on board/device timing. The current physical docs note generic fallback constraints and missing dedicated reset/IO treatment. Before final signoff, classify asynchronous paths correctly, define external input/output delay and load, constrain generated/internal clocks if the flow requires it, and inspect unconstrained endpoints. An optimistic positive WNS with missing constraints is not an operating-frequency guarantee.

## Board validation checklist as an engineering procedure

On the actual board: verify supply rails and grounds first, keep reset asserted, measure 20 MHz at its source and the FPGA/project clock input, confirm all CS# idle high and DQ pads released, then release reset and observe PSRAM reset commands. Check SCK/DQ timing and CS-low width on a logic analyzer, then exchange bytes through the **SoC UART RTL** and inspect Linux boot. Repeat at the intended board voltage and temperature range. These observations will establish facts that digital simulation cannot.
