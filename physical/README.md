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

Full RTL-to-GDS qualification runs through GitHub Actions; local checkpoint
screens can reject unsuitable experiments before dispatch. Following the first
nine-corner extracted STA pass, the flow reads slew/capacitance violations from
that run's reports. It derives driver nets from the CI-produced ODB, selects
same-family stronger cells, inserts noninverting buffers on long branches, and
spatially splits overloaded clock-buffer branches. No checkpoint cell names are
hard-coded. Unsupported repairs fail with an explicit error.

After legalization, the flow unlocks affected nets plus wires within 20 micrometres
of the old/new changed-cell footprints and 5 micrometres of the original affected
routes. Whole selected nets are editable; the rest retain FIXED encoded paths.
The neighborhood is selected from actual DEF segments, not whole-net bounding
boxes. The current shared-tree experiment explicitly allows up to 65% of the
original routed-net count (including new ECO nets in the numerator); the selector
default remains 25%. This bound limits rerouting, not physical qualification.
Cells outside the ECO remain locked. Antenna repair is enabled in detailed routing.

Logical connectivity (tracing through added buffers) and exact normalized geometry
of protected nets are audited before and after routing. The flow repeats antenna,
routing DRC, disconnected-pin, filler, RC extraction and nine-corner STA stages.
Magic/KLayout/LVS and final timing/electrical gates then evaluate that repaired
artifact. Local-route global congestion may proceed to detailed-route diagnosis;
no final physical gate is relaxed. The normal initial global-route congestion gate
remains enabled. A shorted GDS cannot become a submission through a clean STA result.

Validation: fifteen pure helper tests cover report parsing, absent clean-report
sections, relative DEF coordinates, corridor/footprint neighborhood selection,
missing geometry, tree connectivity/fanout/segment bounds, and the actual
failed-CI sink geometry. Plugin loading and all 95 flow steps' configuration were
validated in the pinned container without running a local physical build. Full
backend validation and the actual experiment run in CI.

## Shared-tree repair experiment (2026-09-30)

CI run 36811470893 stopped before applying its ECO: independent per-sink chains
requested 874 buffers for 37 target nets, exceeding the 250-buffer limit. The new
planner recursively divides sinks along their widest spatial axis, shares branch
trunks, and removes redundant junctions while bounding planned Manhattan segments
to 90 micrometres and fanout to eight. Leaf groups span at most 80 micrometres.
Leaf buffers use buf_4 and repeaters/branch drivers use buf_8. Original drivers
still receive equivalent-family resizes; the existing clock split is unchanged.
These are geometric heuristics, not electrical proof. Legalization and routing
can increase distances, and only extracted timing determines success.

The exact failed-CI ODB produces 207 buffers and 36 resizes. Local application and
placement legality passed. Before routing, the audit verified 55,220 original
input-pin drivers and 8,950 exact protected routes. The checked-in geometry
fixture and tree tests reproduce the buffer-budget regression without OpenDB.
Planner diagnostics are retained even when the budget rejects a plan.

Keeping the 20/5 micrometre cell/route halos selects 12,505 editable nets against
21,248 original routed nets (58.85%, conservatively counting 207 new nets).
Cell halos alone touch 9,490 nets. Even 1/0.5 micrometre halos select 7,080 nets,
so the former 25% bound cannot accommodate this distributed repair. This trial
explicitly raises the routing budget to 65% while retaining the wide halos and
all final signoff gates. It does not claim to be a small local repair. Its risk is
that rerouted neighboring nets acquire new electrical violations.

The local screen uses the exact CI database and pinned LibreLane 3.0.14/OpenROAD
binary. Its linking Liberty comes from locally installed PDK 0fe599b2, whereas CI
uses 8afc8346; therefore local screening does not constitute timing qualification.
CI repeats the complete flow, including antenna repair and nine-corner extraction.

## Preserve wires during antenna repair (2026-10-01)

Run 36822832367 passed initial ECO routing, then lost 228 protected wire paths
across the antenna repair/reroute passes. Its zero router DRC and antenna counts
did not establish connectivity; the preservation audit correctly rejected it.
The separate local route without antenna repair retained every protected path.

`antenna_guard.tcl` wraps the pinned flow's antenna repair and detailed-route
commands. Before antenna repair it copies protected wire encodings into detached
OpenDB wires in the same block and records exact pin membership, cell master,
location/orientation, and top-port geometry. After repair, it first requires all
protected pin signatures to remain unchanged. It then reattaches missing saved
wires, retaining their FIXED encoding, before detailed routing sees the design.
An existing but altered protected path fails; it is not silently overwritten.
A new diode or moved pin on a protected net also fails and requires an explicit
change to the routing neighborhood. Unused backups are destroyed before saving.

This addresses the pinned GRT `updateDirtyNets` path that destroys dirty-net wires
before checking whether pin positions changed. The failure reproduces in the
routing/antenna sequence: a standalone repair process did not delete protected
wires, while the full sequence deleted 218 on its first repair pass. The guard
restored all 218 and verified all 8,950 protected paths before routing resumed.

Every detailed-route pass also checks protected pin signatures and exact encoded
paths. Per-antenna-pass counts, restored net names and an ODB checkpoint are saved
in the step artifacts. The final independent logical/DEF geometry audit, antenna,
DRC, disconnected-pin, extracted timing and LVS gates all remain required.
Before real routing, CI runs six fault-injection checks in a disposable OpenROAD
process using two protected nets from that run's own ODB: no-op/result forwarding,
deleted-wire recovery, altered-path rejection, pin-change rejection, propagation
of repair errors, and rejection of wire loss during detailed routing. No design
from these tests enters the flow. The ordinary 15 Python helper tests remain.

Local regression result: after that guarded repair pass inserted 227 diodes,
subsequent detailed routing reached zero router DRC. The independent post-route
audit passed all 8,950 protected routes and 55,220 original input-pin drivers.
This is a one-pass regression of the wire-loss defect; remaining antenna passes,
full LVS and nine-corner extracted timing are still CI qualification work. The
local linking Liberty is from PDK 0fe599b2, while CI uses 8afc8346.
