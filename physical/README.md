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
capacitance ceiling, and nine final PVT/RC corners. Targeted ECO experiments remain
separate until extracted timing and physical verification pass. External I/O timing
is still provisional; a green internal flow does not settle board timing.

Local smoke validation with LibreLane 3.0.14 ran both custom steps: 16,983 movable
instances, 6,482 fixed instances unchanged, connectivity hash unchanged. The full
CI run must additionally validate the clean RTL-to-GDS path.
