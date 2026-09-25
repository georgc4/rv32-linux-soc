# RTL block diagrams and mapped area

The [core flow](core.svg) and [Sv32 adapter flow](sv32-adapter.svg) show the
present implementation at an architectural level. The [core area diagram](core-area.svg)
and [adapter area diagram](sv32-adapter-area.svg) show **nonoverlapping, measured
Sky130 standard-cell partitions**. PNG copies are included for quick preview.
The flow diagrams are not gate-level schematics: feedback, handshake, fault,
and control edges are simplified for readability.

Generate them with `make rtl-diagrams` from the repository root. The script
requires Yosys, Graphviz `dot`, and the Sky130A PDK Liberty file used by
`make synth-sky130` (under `$PDK_ROOT` or `~/.volare`). It checks the flow
diagrams against Yosys `proc; opt` RTLIL, then maps the **whole SoC** with
`synth -noabc; dfflibmap; abc` against
`sky130_fd_sc_hd__tt_025C_1v80.lib`. Counts and area come from that mapped
netlist and Liberty cell areas. The exact values and library hash are in
[`mapped-area.json`](mapped-area.json). Yosys JSON and logs are written under
`build/rtl-block-diagrams/` (ignored by Git); DOT, SVG, and PNG outputs are
kept here.

The core local module, MDU, and privilege unit have true synthesis hierarchy
boundaries. Within core-local logic, **register-file storage** is the mapped
flip-flops driving `regs[0:31]`; every other mapped cell is in **other
core-local logic**, including register-file read muxes and write control.
Within the adapter, **TLB storage** is the mapped flip-flops driving the named
TLB state; **other adapter logic** includes lookup muxes/comparators, walk,
A/D updates, bus control, and responses. Yosys prunes 80 unused cached-PTE
bits, leaving 1,280 mapped TLB storage flip-flops. The partitions sum to each
module total without double counting. The area is **pre-placement cell area**;
it excludes placement repair buffers, clock tree, and routing. The functional
boxes in the flow diagrams do not have independent mapped areas because they
share logic inside their parent module.

The core diagram includes the register file, integer execution, load/store
and atomic path, iterative MDU, and privilege/CSR submodule. The Sv32 diagram
shows the 16-entry TLB hit path and the miss path through page-table walk,
permission checks, optional A/D-bit update, and physical bus access. The
adapter's one-request state machine sequences these operations. A miss reads
PTEs through the same physical bus shown at the bottom of the diagram; that
feedback loop is described in the walk block instead of drawn as a crossing
arrow.

Source: [`rtl/cpu/rv32i_core.v`](../../rtl/cpu/rv32i_core.v),
[`rtl/cpu/rv32_mdu.v`](../../rtl/cpu/rv32_mdu.v),
[`rtl/cpu/rv32_priv_unit.v`](../../rtl/cpu/rv32_priv_unit.v), and
[`rtl/interconnect/sv32_bus_adapter.v`](../../rtl/interconnect/sv32_bus_adapter.v).
