# Building and qualifying a custom 8T bitcell

This is an engineering procedure for the exploratory 1R1W cell, not a claim that the present layout is qualified. The production RF remains standard cells. The electrical reference and starting sizes are [documented here](register-file-layout.md); the editable source and layout commands are in the [KLayout guide](../../experiments/register-file/layout/klayout/README.md).

## Schematic and device naming

Draw two inverters back to back: PQ/NQ drive Q with gate QB; PQB/NQB drive QB with gate Q. The write pair WAQ/WAQB connects BL to Q and BLB to QB when WWL is high. The read stack connects RBL to VSS through RN and RQ, with one gate RWL and the other Q. The SPICE subcircuit pin order is `VDD VSS BL BLB WWL RBL RWL`; avoid exchanging BL/BLB or Q/QB when matching the layout. Each four-terminal transistor has an explicit bulk terminal; the cell must provide continuous, DRC-compliant VDD well and VSS substrate ties. Name every repeated layout subcell distinctly by geometry, and name top-level pins by electrical net, not by transistor instance.

The initial geometric sizes are PMOS 0.42/0.15 µm, latch NMOS 0.65/0.15, write access NMOS 0.84/0.15, and read-stack NMOS 0.65/0.15. These sizes belong to ordinary `sky130_fd_pr__pfet_01v8`/`nfet_01v8` devices. The special small-rule SRAM transistors in the PDK are restricted hard-IP elements; a hand-made open bitcell cannot assume their design-rule exceptions. Check the exact pinned PDK before using a minimum width or channel length.

## Operation and sizing constraints

**Hold.** With WWL=0 and RWL=0, Q/QB must remain complementary despite leakage and noise. Estimate hold static noise margin by sweeping an injected differential disturbance or using cross-coupled inverter butterfly curves at slow/fast device corners and low supply. Check both stored polarities, hot leakage, and long idle time. Larger latch devices can improve restoring current but also increase area/capacitance.

**Write.** Pre-drive BL/BLB to opposite values, assert WWL, and require both Q and QB to cross their inverter trip points within the write pulse. Worst case is the access FET trying to pull down a high Q against the PMOS pullup, or pull up a low node through an NMOS pass gate. Sweep low supply, weak access/strong latch corner, wordline slew, bitline resistance/capacitance, and the shortest intended pulse. Check unselected cells sharing a bitline or selected wordline for half-select disturb. If writes fail, compare stronger WA with weaker PQ, then recheck hold and read energy.

**Read.** Precharge RBL, leave WWL low, assert RWL, and measure the voltage difference between storing the conducting and nonconducting polarity after the full-column sense time. Two series NMOS devices set discharge current; the column bitline, metal, vias, mux, and sense input set load. A fast isolated read path avoids direct storage-node disturb, but RWL coupling and leakage still matter. Size RN/RQ together with precharge and sense circuitry; a bare cell read delay is not an array timing number.

**Energy and leakage.** Include write bitline swing, read precharge/discharge, wordline drivers, decoder, and sense circuits. Measure standby current for both polarities and half-selected conditions. A wider device may reduce delay while increasing switched capacitance and leakage. For each candidate record W/L, cell pitch, extracted RC, write success window, read differential and time, hold margin, leakage, and operating voltage/corner. Do not select from transistor ratios alone.

## Layout sequence

1. Inspect the named PDK transistor cells in KLayout and the generated schematic. Position the eight instances to shorten Q/QB feedback, make BL/BLB and WWL/RWL regular, and plan power rails/tap pitch for a tiled row.
2. Route Q/QB locally first. Keep their parasitic asymmetry low; long cross-coupled wires add capacitance and can reduce stability. Route BL/BLB and RBL/RWL on repeatable tracks with legal via enclosure and spacing. Plan actual array boundary and mirrored-neighbor conditions, not just an isolated pretty cell.
3. Add PMOS n-well ties to VDD and NMOS substrate ties to VSS per the pinned SKY130 rules. Add pin labels on conductive geometry and a clear hierarchy. Check rail width, contact density, and well continuity at array edges and tap columns.
4. Run local DRC after each routing layer change. Export/extract and run Netgen LVS against `rf8t_reference.spice`; inspect both unmatched devices and parasitic-only differences. Re-extract after any geometry or sizing change. A positive LVS with DRC failures is not acceptable.
5. Tile a small array with real wordline drivers, write drivers, precharge, sense/read mux, row decode, taps, and boundary cells. Repeat DRC/LVS at array level; pitch/overlap errors may appear only when tiled. Extract column RC and run corner SPICE with realistic loads.
6. Produce LEF obstruction/pin shapes, GDS, black-box or transistor netlist, Liberty timing/power, and a behavioral model with the same latency. Integrate that model into the CPU, rerun directed tests/full Linux acceptance, and harden the top-level design with the macro. Compare routed area and timing against the standard-cell RF at the same constraints and image.

The earlier Magic prototype has matching LVS but DRC violations; the KLayout starter is only eight unconnected devices. Do not use either as a tapeout macro. The generated OpenRAM 32×32 comparison is larger than the standard-cell RF and independently fails DRC/LVS under the installed setup; it is a study, not an alternate signoff path.
