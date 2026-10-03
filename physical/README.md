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

## Repair physical contacts and neighboring electrical violations (2026-10-02)

Run 36943817911 reached final signoff. The antenna wire guard preserved all
8,950 protected paths, but independent tools found 12 Magic DRC, four KLayout
DRC, and 13 LVS errors. Four logically separate nets were physically merged
near (490.59, 74.29) micrometres: protected `_11571_` and editable `net6472`,
`net6553`, and `soc.cpu.b[27]`. One contact preceded antenna repair. A local
fresh-process reroute alone retained that contact; process isolation is not a
complete repair.

Each detailed-route and antenna-repair pass now runs in a separate OpenROAD
process. After routing, an independent DEF centerline check detects same-layer
inter-net intersections and touches. This is a subset of short detection, not
width/spacing/via/cell-geometry signoff. Proven contacts explicitly promote the
involved protected nets into the editable set, rip up only contacting nets,
and regenerate their global routes before retrying detailed routing. At most
three contact retries are allowed per pass, under the unchanged 65% editable
budget. The original manifest and each promotion are retained; the final audit
uses the active manifest. Unrelated routes and logical drivers remain audited.

On the failed checkpoint, promoting one protected net and rerouting four nets
removed all detected contacts. The audit preserved 8,949 protected paths and
55,220 original input-pin drivers. A subsequent smoke run through the actual
nested LibreLane step completed with zero router DRC and zero antenna violations,
and passed its independent audit. The standalone antenna-repair child also
completed successfully on the repaired, antenna-clean database; this does not
exercise a complete nonzero-antenna repair loop. The six native guard fault tests
and all 21 Python helper tests pass.

The first ECO cleared its original 37 target nets, but extracted reports identified
208 failing pins on 29 different rerouted neighboring nets. A bounded second ECO
round now reads the first round's nine-corner extracted reports and repeats all
13 repair/check/extraction stages. The exact failed checkpoint requests 161
buffers and 29 equivalent-family resizes, within the unchanged 250-buffer limit.
Drivers selected for another resize are explicitly unlocked before legalization;
other instances remain locked. Only FILLER_* instances are removed so boundary
decaps survive the repeated operation.

Round two uses 5/1 micrometre cell/route margins: local legalization and pre-route
auditing pass with 12,016 editable nets (56.0%), 9,600 protected routes, and 55,677
original input-pin checks. The 20/5 margins selected 76.6% and were rejected by
the existing 65% limit. Tighter margins may constrain routing; final signoff is
required, and no gate is relaxed. The flow now has 108 top-level steps, with both
ECO rounds required by the hashed submission manifest.

These are local regression results using the failed CI geometry and pinned
LibreLane/OpenROAD binary. Linking Liberty remains local PDK 0fe599b2 rather than
CI PDK 8afc8346. Full physical DRC, LVS, and extracted nine-corner timing are still
pending in the next CI run. No local result constitutes a qualified GDS.

## Retain editable neighbor routes (2026-10-02)

Run 37028071522 passed final Magic/KLayout DRC, LVS (unique match), antenna,
setup and hold. It failed the unchanged slew/capacitance checks. After round
two, the nine-corner union was 315 failing pins on 45 nets; none of those nets
were targets of either ECO round. Max-RC slow-corner counts were 311 slew pins
and 44 capacitance pins. The buffers repaired their targets, while broad route
replacement introduced a different set of electrical failures. The 45 residual
nets grew from 18.21 mm to 54.70 mm of summed DEF centerline segments; one
net grew from 128.76 um to 1,657.38 um (12.87x).

Preparation previously destroyed every editable wire, even when its topology
and pin geometry had not changed. It now destroys only affected wires and keeps
other editable routes as the router's starting point. Global routing still builds guides for the full editable neighborhood;
neighboring wires remain ROUTED and may be adjusted by DRT where necessary. Protected wires remain FIXED and exactly audited. The routing
neighborhood, 65% ceiling, two ECO rounds, contact-repair mechanism and all final
signoff gates are unchanged. The manifest and metrics distinguish ripped nets
from retained editable neighbors.

On the exact first-round CI checkpoint, this preserves 12,179 editable neighbor
routes and 8,950 protected routes while ripping only 326 changed nets. All 12,179
retained routes compare exactly with the original DEF both after preparation and
after global routing. Final DRT may legitimately adjust them to resolve local
conflicts; retention is an initial-condition guarantee, not a claim of immutable
neighbor geometry or timing closure.

## Retry contacts within the editable set (2026-10-02)

Run 37076106240 stopped during the first ECO routing stage. The router ended
with 68 DRC violations, and the independent contact audit requested repair.
`expand_route_contacts.py` then rejected the request because none of the
contacting nets was protected. That guard confused membership expansion with
useful repair: existing editable wires still need explicit rip-up when they
physically contact one another.

The repair now accepts contacts wholly within the editable set. It removes
only the contacting wires and invokes the existing global/detail reroute path.
Protected members, when present, are still explicitly promoted. Empty reports,
self-contacts and nets outside the manifest are rejected. The existing three
contact retries per route pass, 65% editable-net budget, logical/geometry audit,
and final signoff gates are unchanged.

The local reproduction contains 43 contact records across 66 editable nets.
The revised command accepts it with zero protected-net promotions. Native
OpenDB/DEF regression checks verify that exactly those 66 routes are removed
and every other route remains unchanged; protected/editable membership is
unchanged. All 24 Python tests pass, including editable-only and mixed contact
selection and rejection of invalid repair requests. Routing the selected nets
and full signoff remain pending; this verifies the retry-path bug fix rather
than establishing that all 68 DRC violations are resolved.


## Repair router DRC markers before extraction (2026-10-03)

Run 37096880158 passed extracted nine-corner setup, hold, slew and capacitance,
antenna and LVS, but failed physical signoff: 14 router DRC after round one,
20 after round two, 79 Magic DRC and 11 KLayout DRC. The old centerline-contact
audit missed spacing to nearby wires, power shapes and cell obstructions.
Deferred router errors let the run spend over five hours reaching final failure.
Some first-round violations also became invisible to later router checks when
both signal routes were protected in the second round; final Magic still found
them. Each round must therefore finish clean before the next round is prepared.

The repair loop now parses the pinned router's DRC report, checks its record
count against the fresh router metric, and treats every marker as a repair
request, even when the centerline audit passes. Single-net violations are valid.
The first attempt reroutes editable signal wires around protected obstacles;
subsequent attempts may explicitly promote the other implicated signal wires.
Power/ground shapes and cell obstructions remain fixed. Unknown nets, instances,
source formats, invalid boxes and source-less repairs fail closed.

Each ECO detailed-route pass is bounded at 24 optimization iterations. There
are still at most three repair retries per antenna round; identical violations
after an expanded retry stop immediately. Unresolved router DRC now stops inside
the repair stage before extraction. The 65% editable-net budget, protected-route
and logical-connectivity audits, and all downstream signoff gates remain active.
No design or library electrical limit is relaxed.

Local reproduction uses the exact CI PDK 8afc8346a57fe1ab7934ba5a6056ea8b43078e71,
LibreLane 3.0.14 and OpenROAD dcf36133a369abc8f3c5e5738cd4d82e4903c0e0. Combining
both failed-round reports exposes 34 markers. A 22-net reroute clears router,
Magic and KLayout DRC, antenna, and LVS (unique match); all nine corners pass
setup/hold/slew. One max-RC slow-corner capacitance failure remains:
_23793_/Y measures 0.086360 pF against 0.086070 pF. Its own route geometry is
unchanged. An 18-net selection also clears router/Magic/KLayout DRC, antenna, LVS and
the independent audit, but retains that capacitance failure. These are diagnostic checkpoint repairs,
not qualified GDS. The production sequence is being tested with marker repair
before the second electrical ECO, so the latter consumes fresh extracted loads.

The final failed-CI DRC report is retained as a parser regression fixture.
All 29 Python helper tests pass, including actual single-net/cell/power records,
editable-first selection, explicit promotion and rejection of unknown sources.


The production-order replay clears both routing stages but exposes another
second-round regression: 11 slew pins and one capacitance failure on _12849_.
Its driver measures 1.931793 ns against a 1.496266 ns pin limit and 0.112786 pF
against 0.086070 pF. Setup/hold remain positive. A bounded third ECO round now
consumes round two's fresh reports using the same planner and 5/1 um routing
margins. Its initial resize-plus-buffer trial selected only that net, resized
its nor2_2 driver to nor2_4 and inserted two buffers. No checkpoint-specific names are added to
the flow. Required-stage provenance includes all third-round stages, and a
regression test verifies each round reads its own neighborhood and the previous
round's extracted STA. This resize-plus-buffer trial repairs _12849_ but creates six slew-pin failures
and one capacitance failure on the resized driver's input net _11694_. The final
cleanup therefore uses buffer-only planning: original driver cells retain their
master and placement, avoiding input-capacitance growth and input-pin rerouting.
The same checkpoint then requests only the two buffers. The resize trial
lengthened input net _11694_ from 115.96 um to 1,006.62 um; buffer-only repair
preserves that route and the other input route exactly. It replaces three routes,
keeps 21,025 routes protected, and clears router DRC and antenna. All nine corners
then pass setup, hold, slew and capacitance: worst setup +8.941967 ns, worst hold
+0.054556 ns. Magic DRC, KLayout DRC and LVS also pass with zero errors and a unique circuit
match. All 42 per-corner/physical metric gates in the submission contract pass
on this checkpoint replay. Clean RTL-to-GDS CI, Tiny Tapeout precheck and gate
simulation remain separate required qualifications.
