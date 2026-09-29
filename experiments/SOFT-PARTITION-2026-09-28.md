# Congestion prognosis and bounded placement screens

The 5x4 baseline has completed physical checks, and registered-decode RTL
f91a5e108ca57f257d740447d6e14c926b77360b has passed Linux acceptance at
13,877,255,869 cycles. Its run 13 has +11.527 ns setup slack at
max_ss_100C_1v60 after global routing; this is estimated, not final extracted
signoff. Physical feasibility and timing closure are not yet demonstrated
in the same completed candidate.

Run 13's global router reported 28,025 total overflow, with met1 at 100.90%
and met2 at 95.33% aggregate demand/resource usage. Run 17 reported 51,628
overflow, met1 at 111.55% and met2 at 108.03%. Aggregate use below 100% does
not rule out local overflow. These are router-adjusted resource budgets,
not a claim about absolute chip metal utilization. Run 17 was cancelled
with checkpoints preserved after detailed routing remained above 624,000
violations. Run 13 remains as a control; runs 07 and 11 continue on PS4.

The existing attractions form small disjoint clusters of 2–24 cells on
selected timer, operand, and cache nets. They are not whole-design physical
partitions. Hard fences or larger tight clusters could worsen pin access
and create congested boundaries.

## New screens

Both reuse run 13's exact pre-placement checkpoint and tool image:

1. `four-part-seed-60`: TritonPart connectivity partitioning into four parts,
   then area-proportional, overlapping initial placement windows. The window
   arrangement minimizes a coarse inter-partition/IO HPWL objective. All
   instances remain movable; no persistent region constraints, fences,
   blockages, or artificial nets are added. Initial placement is skipped so
   Nesterov placement starts from these coordinates.
2. `density-only-55`: unchanged initial-placement method at 55% rather than
   60% target density. This is an independent spreading comparison.

Clock remains 50 ns. Both retain timing-driven placement and TT/SS/FF
implementation corners. The seed script verifies complete movable-cell
coverage, unchanged connectivity, and unchanged fixed instances. Files,
configuration, source checkpoint, and image hashes are recorded per screen.
Initial seeds may be largely relaxed by global placement; this experiment
must not be described as persistent soft-region support.

`GRT_ALLOW_CONGESTION=false` makes overflow reject the screen. Execution
stops at global routing, so even a successful screen is not physical or
functional qualification. Compare overflow, per-layer hot spots, wire
length, repair-buffer growth, and slow-corner timing before promoting a
survivor to detailed routing and final extraction. Near-zero overflow that
still fails the strict gate can be investigated, but should not silently
advance. Next candidates, contingent on these results, are localized pin
padding and placement-feedback routing-resource adjustments; do not assume
extra metal layers are available in the shuttle.

Implementation: `experiments/seed_soft_partitions.py` and
`experiments/run_soft_partition_screens.py`. Live evidence is in
`build/experiments/soft-partition-screen/`; each screen has its own
`result.json`, `screen.log`, and LibreLane run directory. These screens are
separate from the frozen campaign's immutable result IDs.

## First results and router feedback

The four-part seed completed global routing with **zero overflow**, wire
length 1,408,462 um, and 55.42% aggregate adjusted routing-resource usage.
Run 13 had 28,025 overflow and 2,194,683 um of wire: the seeded result is
35.82% shorter. The density-only 55% screen failed its strict congestion
gate with 6,905 overflow and 1,894,698 um of wire. These results favor this
partition-based initial placement over the tested density reduction; they
do not isolate the partition topology from all effects of initial seeding.

The seed has 4,043 timing-repair buffers versus run 13's 4,231, and nearly
unchanged standard-cell area (263,155 versus 263,054 um2). Slow-corner setup
slack is +13.5997 ns and hold slack +0.705471 ns **after post-CTS repair**.
Those metrics are inherited into the global-routing state and must not be
misrepresented as newly computed post-route timing.

`experiments/run_route_feedback.py qualify-partition` resumes the zero-
overflow checkpoint at `OpenROAD.CheckAntennas`, through detailed routing,
extraction, and signoff checks. It explicitly enables KLayout DRC and all-
corner setup, hold, slew, and capacitance gates. This continuation has its
own directory, configuration hashes, and result record; qualification stays
false until final reports and artifacts are reviewed.

`experiments/run_route_feedback.py screen-grt-feedback` repeats the seeded
placement with the isolated plugin in `experiments/route_feedback/`.
The plugin adds `-routability_use_grt` to the pinned global placer, selecting
FastRoute feedback instead of the default RUDY congestion estimate. It
preserves timing-driven placement, the seed, density, clock, and corners,
then stops at the same strict global-routing gate. Both workers were
launched September 28 PDT (September 29 UTC).

This implements router-informed movement during placement. It does not
add arbitrary cell movement inside TritonRoute's detailed-route search.
Moving placed cells after routing needs legalization and regeneration of
affected routes, followed by timing and physical checks; wholesale moves
after CTS would also require clock-tree reconsideration. The current
experiment instead performs feedback before CTS and rebuilds downstream
implementation normally.

## Final extraction and electrical-signoff priority

The first partition continuation completed detailed routing, GDS output,
Magic/KLayout DRC (both zero), LVS (unique match), and antenna checks (zero).
Setup and hold passed all nine extracted corners. Worst setup slack was
+9.201824 ns at max_ss_100C_1v60; worst hold slack was +0.054048 ns at
min_ff_n40C_1v95. Final routed wire length was 1,005,384 um. It is **not
fully qualified**: worst-corner electrical checks reported 3,328 slew and
7 capacitance violations. The slew report covers 415 unique nets, rather
than 3,328 independent nets. Final signoff uses the existing 0.75 ns maximum
transition and 0.2 pF maximum-capacitance constraints, together with library
limits. External I/O constraints remain provisional.

Post-global-route electrical design repair was disabled in the original
candidate. Two continuations now enable it with 20% and 35% slew/capacitance
repair margins (`experiments/run_electrical_repair.py`). Neither changes
signoff limits. The 20% variant resized 9 cells; the 35% variant resized 26
and inserted 12 buffers. Both finished post-repair global routing with zero
overflow and advanced to detailed routing and full checks.

Estimated slow-corner slew violations were only 35 before detailed routing,
versus 3,328 after extraction. A third approach uses the matched final ODB
and all three extracted RC SPEFs to drive electrical repair, with clock-wire
repair and post-GRT setup/hold repair. Its first attempt retained detailed
wires, leaving them as routing-capacity consumers; antenna repair stopped
on congestion. That failed result is preserved in `electrical-extracted-20`.
The corrected `electrical-extracted-fullroute-20` trial removes old signal
and clock wires, initializes the routing-parasitic updater, loads the measured
SPEFs, performs repairs, legalizes placement, and rebuilds routing. It uses
`run_extracted_fullroute.py` and the isolated extracted-repair plugins.
All these trials require new extraction and all final physical checks;
repair-stage metrics alone never establish qualification.

Run 13 was cancelled in favor of these electrical-signoff trials. Its
source workspace is intentionally retained because the successful seed and
continuations reference its immutable source/checkpoint files. The dispatcher
was restarted to supervise the two remaining PS4 collectors; deferred runs
remain deferred. Main has not been updated.

The FastRoute-feedback placement experiment separately aborted with an
OpenROAD `dpl::Opendp::legalPt` assertion (signal 6). It is not a routing
comparison result and is not currently the signoff priority.

## Read-only constraint diagnostic

To distinguish implementation-target violations from library-limit violations,
the original partitioned candidate's extracted netlist/SPEFs were reanalyzed
without changing any production configuration or physical database. Direct
OpenSTA analysis reproduces the existing 0.75 ns slew and capacitance counts
at all nine corners. Replacing only the diagnostic design-wide transition
target gives these max_ss_100C_1v60 results:

| Diagnostic transition target | Slew violations | Capacitance violations |
| --- | ---: | ---: |
| 0.75 ns | 3328 | 7 |
| 1.0 ns | 765 | 7 |
| 1.5 ns | 20 | 7 |

The 0.75 ns target originates in the pinned sky130_fd_sc_hd OpenLane PDK
configuration. The pinned SS Liberty default maximum transition is 1.5 ns;
pin-specific stricter limits remain active in this diagnostic (for example,
1.496266 ns for a NOR output). At the 1.5 ns design target, all nine corners
have 20 or fewer slew violations. The 20 worst-corner pins belong to six
signal nets; the seven capacitance violations cover those six drivers plus
the root clock driver. The worst NOR output drives 0.247637 pF against its
0.086070 pF limit and has about 4.19 ns slew, so actual electrical problems
remain even under the less stringent diagnostic target.

Evidence is under `build/experiments/soft-partition-screen/constraint-diagnostic/`.
This is an analysis of a possible signoff-policy choice, not approval to
relax production constraints or a claim of qualification. The default
0.75 ns gates and all current repair trials remain unchanged. RC correlation
between global-routing estimates and extracted parasitics is a separate
unresolved question; the size of the count jump alone does not prove an
extraction bug or quantify per-net RC error.

## Authorized library-transition target and targeted ECO

The user subsequently authorized using the slow-corner library transition
target. `electrical-library15-targeted-v2` therefore explicitly sets
`MAX_TRANSITION_CONSTRAINT=1.5`; OpenSTA still enforces tighter pin-specific
Liberty limits. The 0.2 pF design capacitance limit, 50 ns clock, and all-nine-
corner setup, hold, slew and capacitance gates remain in place. This changes
the declared signoff target and must be visible in any qualification record.
It does not itself establish that the silicon or external-memory interface
will work.

The targeted ECO is generated from the original partition candidate's final
ODB, not the regressed broad-repair experiment. Six offending signal drivers
change from drive strength 2 to 4 within the same logic-cell family. Fifteen
non-inverting data buffers split long branches on these six nets into initial
Manhattan spans no longer than 80 um; two clock buffers divide the root clock
load into its four western and four eastern child buffers. Subsequent
legalization and routing can change these distances. All cells remain movable.

Old detailed signal/clock wires are discarded before rebuilding routing.
Post-GRT setup/hold repair is enabled with a 0.10 ns hold-repair margin, and
the complete extraction/physical-check sequence runs again. The first targeted
attempt stopped on EST-0104 because explicit `replace_cell` invalidated
parasitics before `insert_buffer` began its incremental update. The v2 Tcl
refreshes placement parasitics after each replacement before insertion; full
routing and extraction remain the source of final evidence.

Sources: `experiments/generate_library_limit_eco.py`,
`experiments/route_feedback/librelane_plugin_library_limit.py`, and
`experiments/run_library_limit_repair_v2.py`. Source ODB, configuration, ECO,
generator, plugin, worker and container image hashes are recorded. Original
failed attempts and the prior 0.75 ns baseline are retained for comparison.

The v2 attempt exposed another pinned-tool API detail: `insert_buffer` treats
the requested buffer name as a base and always appends a unique suffix. The
v3 Tcl captures the returned instance's actual name when chaining buffers.
The complete v3 ECO passed a standalone dry run. A static connectivity check
then compared 55,312 original input pins and top-level output drivers while
tracing through only the 17 added, non-inverting buffers; all original driver
connections were preserved, and exactly the six intended equivalent cell-
family resizes were present. This verifies logical connectivity, not timing
or physical signoff. Evidence lives in `library15-targeted-v3-inputs/`.
`run_library_limit_repair_v3.py` launched full requalification from the original
partition candidate with this validated ECO. v1/v2 failures remain recorded.
