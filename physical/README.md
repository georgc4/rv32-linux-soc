# Reproducible partitioned placement

`librelane_plugin_rv32.py` inserts two steps immediately before global placement in
LibreLane Classic. TritonPart builds four connectivity groups (seed 1, 5% balance,
ignore nets above 64 terminals). The Python wrapper tries all 24 group-to-quadrant
assignments, minimizes estimated intergroup/port wire length, and distributes cells
within overlapping, area-weighted windows. Global placement then starts from those
positions with timing and routability optimization enabled. Cells remain movable;
there are no persistent placement fences. The seed step asserts unchanged logical
connectivity and fixed-cell locations.

The normal Tiny Tapeout action uses our pinned support-tools fork. Its optional
`physical-flow.json` contract verifies these exact sources/configuration, executed
steps, and zero final signoff violations, then includes provenance and the project
GDS hash in the standard submission package. Changing a physical script requires
updating its manifest SHA-256. Never remove a gate to obtain a green build.

This branch is a CI integration candidate, not yet a qualified submission. It uses
the registered-decode RTL and the successful four-part placement technique, with
a 1.5 ns design transition ceiling (tighter library pin limits still apply), 0.2 pF
capacitance ceiling, and nine final PVT/RC corners. The expanded routed ECO below is an experiment in this CI branch and remains
unqualified until its fresh physical and timing checks pass. External I/O timing
is still provisional; a green internal flow does not settle board timing.

Local smoke validation with LibreLane 3.0.14 ran both custom steps: 16,983 movable
instances, 6,482 fixed instances unchanged, connectivity hash unchanged. The full
CI run must additionally validate the clean RTL-to-GDS path.

## Expanded routed ECO in CI (2026-09-30)

All full physical experiments now run through GitHub Actions. Following the first
nine-corner extracted STA pass, the flow reads slew/capacitance violations from
that run's reports. It derives driver nets from the CI-produced ODB, selects
same-family stronger cells, inserts noninverting buffers on long branches, and
spatially splits overloaded clock-buffer branches. No checkpoint cell names are
hard-coded. Unsupported repairs fail with an explicit error.

After legalization, the flow unlocks affected nets plus wires within 20 micrometres
of the old/new changed-cell footprints and 5 micrometres of the original affected
routes. Whole selected nets are editable; the rest retain FIXED encoded paths.
The neighborhood is selected from actual DEF segments, not whole-net bounding
boxes, and a 25% net-count ceiling prevents an accidental design-wide reroute.
Cells outside the ECO remain locked. Antenna repair is enabled in detailed routing.

Logical connectivity (tracing through added buffers) and exact normalized geometry
of protected nets are audited before and after routing. The flow repeats antenna,
routing DRC, disconnected-pin, filler, RC extraction and nine-corner STA stages.
Magic/KLayout/LVS and final timing/electrical gates then evaluate that repaired
artifact. Local-route global congestion may proceed to detailed-route diagnosis;
no final physical gate is relaxed. The normal initial global-route congestion gate
remains enabled. A shorted GDS cannot become a submission through a clean STA result.

Validation: nine pure helper tests cover report parsing, absent clean-report
sections, relative DEF coordinates, corridor/footprint neighborhood selection,
and missing geometry. Plugin loading and all 95 flow steps' configuration were
validated in the pinned container without running a local physical build. Full
backend validation and the actual experiment run in CI.
