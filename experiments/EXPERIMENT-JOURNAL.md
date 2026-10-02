# From long routes to a partitioned Linux SoC

This is the source notebook for a future blog, not a claim of completed silicon
signoff. It records measured results, decisions, failed approaches, and open
questions. Dates below use UTC unless explicitly marked PDT. Notes written
during the work live in the linked review documents; this narrative and the
Git evidence snapshot were assembled afterward, on September 29 UTC. Git
commit times are preservation times, not reconstructed experiment timestamps.

## The starting question: fit, speed, and conspicuously long wires

The user saw long routes in the routed database and proposed placement
attractions. The initial choice was whether to pursue an 8×2 allocation or
finish a 5×4 implementation. The measured one-line-cache/four-TLB baseline
`7ebde5cec555-e811a35c1f2d` passed the physical and Linux acceptance gates then
in use, but its final area implied roughly 93% utilization in the smaller
8×2 core. No fully qualified 8×2 implementation had been demonstrated.

The review prioritized 5×4. It found a second problem: the dashboard was
collecting intermediate timing and could obscure a failing final corner.
The baseline's final slow-corner setup slack was **−9.4466 ns**, despite
positive typical-corner timing and clean DRC/LVS. The collector and dashboard
were changed to require explicit final setup, hold, slew, and capacitance
evidence at every required corner. This changed the meaning of “qualified.”
Earlier labels in immutable result records are historical, not current claims.

Source: [September 27 physical review](PHYSICAL-REVIEW-2026-09-27.md).

## Improve the logic without adding execution cycles

The critical path included instruction-legality decoding into writeback.
RTL commit `f91a5e108ca57f257d740447d6e14c926b77360b` registered legality in
the existing operand-read phase. It added no execution cycle. Full serial
Linux acceptance passed at **13,877,255,869 cycles**, matching the baseline.
This total includes boot and the acceptance sequence; it is not the latency
of one shell command.

The faster one-cache-line/eight-TLB architecture is separately pinned at
`246c244cbeacd2ec97082df21556b773fdbba616`; its measured full acceptance was
**9,856,801,148 cycles**. Its performance result must not be attributed to
the four-TLB registered-decode physical candidate.

## Run a controlled campaign, including a Linux PS4 worker

Experiments tested timing-driven placement, small connectivity attractions,
multiple implementation corners, mapping options, and alternate RTL. A Linux
PS4 ran additional builds and acceptance work through a persistent container
root filesystem; the Mac retained its own workers. Tool/image architecture
was recorded rather than assuming the machines produced identical results.
Resource pressure led to more VM memory/swap, removal of rebuildable files,
and cancellation of low-confidence runs with checkpoints retained. The exact
cause of the earlier VM exit was not established; do not describe it as a
proven out-of-memory crash.

Source: [locality campaign notes](locality/README.md) and the evidence ledger.

## The user's partitioning hypothesis becomes the turning point

The user explicitly pushed for partitioning to address congestion. We tested
that idea on the registered-decode RTL using the same pre-placement checkpoint,
5×4 core, 50 ns clock, and 60% target density as run 13.

TritonPart computed four connectivity groups. A custom wrapper assigned them
area-proportional initial rectangles, evaluated all 24 quadrant arrangements
against coarse inter-group/I/O wire length, and seeded movable cells within
overlapping windows. Nesterov placement started from those coordinates.
There were **no persistent fences or soft-region constraints**. TritonPart
provided group membership; the wrapper turned it into physical starting
positions. Connectivity and fixed-instance invariants were checked.

| Global-routing screen | Overflow | Estimated routed wire length |
| --- | ---: | ---: |
| Unpartitioned run 13 | 28,025 | 2,194,683 µm |
| Density reduced to 55% | 6,905 | 1,894,698 µm |
| Four-part seed, 60% density | **0** | **1,408,462 µm** |

The successful seed cut this global-route wire-length estimate by **35.82%**.
Its completed detailed route later measured **1,005,384 µm**; these are
different stages and should not be mixed in a percentage comparison.
Magic/KLayout DRC, LVS, and antenna passed. Final setup and hold passed all
nine corners: worst setup **+9.201824 ns**, worst hold **+0.054048 ns**.
It still failed electrical checks. This was a physical/timing milestone,
not full qualification or a silicon demonstration.

The comparison supports this seeded placement, but it does not isolate the
effect of graph partitioning from all other effects of changing the initial
coordinates. A separate FastRoute-feedback placement attempt aborted on an
OpenROAD legalization assertion, so it supplied no quality comparison.

Source: [partition implementation and results](SOFT-PARTITION-2026-09-28.md).

## Why clean routing and positive slack were not the end

The successful partition candidate still had **3,328 slew violations and
7 capacitance violations** at the worst corner. The slew count represented
pins on **415 nets**, not 3,328 separate nets. Estimated global-route timing
had shown only 35 slew violations. The estimation/extraction gap remains a
correlation question; it is not proof of an extraction-tool bug.

Post-global-route electrical repair had been disabled. Enabling it with
20% and 35% margins did not close the original 0.75 ns transition target:

| Completed trial | Slow-corner slew / cap | Slow-corner setup | Other outcome |
| --- | --- | ---: | --- |
| 20% margin | 3,327 / 7 | +8.974603 ns | Setup/hold passed; 2 antenna nets remained |
| 35% margin | 3,152 / 9 | +9.274832 ns | Setup/hold and physical checks passed |
| Broad extracted-RC repair | 3,102 / 44 | +6.406431 ns | Introduced fast-corner hold failure, worst −54.87 ps |

The broad repair was a regression. It was not promoted. A prior extracted-RC
attempt also failed because old detailed wires consumed routing capacity;
the next attempt discarded those wires and rebuilt routes. Failed attempts
remain part of the record.

## A constraint-policy decision, documented explicitly

A read-only reanalysis of the original partitioned design reproduced the
existing counts and separated the flow's **0.75 ns** transition target from
the library's **1.5 ns default**, retaining tighter pin-specific limits:

| Diagnostic target | Worst-corner slew violations | Capacitance violations |
| --- | ---: | ---: |
| 0.75 ns | 3,328 | 7 |
| 1.0 ns | 765 | 7 |
| 1.5 ns | 20 | 7 |

At 1.5 ns, every evaluated corner had 20 or fewer slew violations. The
remaining worst-corner pins belonged to six signal nets, with capacitance
violations on those six drivers plus the root clock. One NOR output drove
0.247637 pF against a 0.086070 pF limit and had roughly 4.19 ns slew: genuine
electrical repairs were still required.

The user then authorized the **1.5 ns library-based transition target**.
The 50 ns clock, tighter library pin limits, 0.2 pF design capacitance target,
and all-corner gates were retained. This is a declared target change, not a
3,308-violation physical improvement or an unchanged-constraint comparison.

## Current experiment: a small, targeted ECO

Starting from the original successful partition candidate, the targeted ECO
upgrades six drivers from strength 2 to 4 and inserts 15 data buffers plus
two clock buffers. Two early attempts exposed pinned-tool API details:
resizing invalidated the incremental parasitic state; buffer names received
automatic unique suffixes. The v3 script refreshes parasitics and uses the
actual returned buffer names.

A dry run and static connectivity comparison verified 55,312 original input
pins and top-level output drivers, tracing through the added non-inverting
buffers. That is logical connectivity evidence, not timing signoff.
`electrical-library15-targeted-v3` was still running at the initial journal
checkpoint. It finished at **2026-09-29 07:06:15 UTC** and failed electrical
signoff: **197 slew / 27 capacitance violations** at max-SS under the 1.5 ns
target. Setup and hold passed all nine corners (worst setup **+5.129248 ns**,
worst hold **+0.079761 ns**); routing/Magic/KLayout DRC, LVS, and antenna were
clean. This was worse than the original candidate's 20/7 diagnostic under
the same target, so it was not promoted.

The downstream post-global-route timing repair increased instance count from
28,631 to 29,786: a net addition of **1,155 instances** beyond the manual ECO
and preceding antenna repair. This confounds attribution to the small ECO.
A follow-up, `electrical-library15-targeted-only`, uses the same original
checkpoint and verified ECO, with that broad timing-repair stage disabled.
It still rebuilds routes and runs the final all-corner and physical checks;
it is not an incremental-route-only experiment.

That follow-up finished at **2026-09-29 08:44:07 UTC**. It improved on v3 but
still failed electrical signoff: worst-corner **121 slew / 20 capacitance**
violations at the same 1.5 ns target. Setup and hold passed all nine corners
(worst setup **+8.694642 ns**, worst hold **+0.053322 ns**); routing, Magic,
KLayout, LVS, antenna, and disconnected-pin counts were zero. Standard-cell
area fell from v3's 276,617 to 264,828 square micrometres. This remains worse
than the original partition candidate's 20/7 diagnostic. Removing broad timing
repair helped, but did not isolate or cure the remaining ECO/rerouting effects.
The worst reported slew was about **6.57 ns**, so the residual violations are
not merely rounding errors. External memory/board I/O timing remains provisional.

A subsequent pin-identity comparison clarifies this result: in the max-SS
report at the same 1.5 ns target, **all 20 original slew-violating pins and all
seven original capacitance-violating pins disappeared from those violation
lists**. The 121 slew and 20 capacitance violations are on different pins;
none of the added ECO buffers appears in the slow-corner slew list. Thus the
targeted changes did resolve the original reported failures locally. The
overall result regressed after rerouting and subsequent processing. One new
violation is on input `_26547_/B` of a resized gate, while its repaired output
passes; 26 newly violating slew pins belong to antenna diodes. These are
observations, not proof assigning the regression to any single cause. Wire RC,
upstream loading, placement changes, and antenna repair need separate analysis.

## 2026-09-29 — Carry the physical flow into CI and preserve ECO routes

The user obtained confirmation from Tiny Tapeout on Discord that the action can
use a support-tools fork, and authorized publishing our flow changes. Created
`georgc4/tt-support-tools`, branch `codex/project-physical-flow`, pinned fork commit
`5d6e7f9` (based on upstream `01d5d2814fa9dd61e9d211e0b235a4a592a9316a`).
Its optional project contract validates script hashes and critical configuration,
requires completed custom steps, gates all declared corners' setup/hold/slew/cap
plus physical metrics, and copies provenance and a GDS SHA-256 into the standard
Tiny Tapeout submission. Seven fail-closed contract tests passed.

SoC branch `codex/partitioned-signoff-ci` carries the registered-decode RTL and a
clean Classic-flow extension: TritonPart followed by our four-part seed wrapper,
immediately before global placement. No local checkpoint is required in CI.
The two custom steps passed a pinned-container smoke test: 16,983 movable cells,
6,482 fixed instances unchanged, unchanged logical connectivity. The fork and
Tiny Tapeout action are pinned by full SHA; LibreLane remains 3.0.14. The
1.5 ns transition ceiling retains tighter library pin limits; 0.2 pF capacitance
and all nine signoff corners remain required. Post-GRT broad timing repair remains
disabled, matching the successful partition recipe. No unqualified ECO is baked
into this CI flow.

Draft PR: https://github.com/georgc4/rv32-linux-soc/pull/1 . Latest integration
commit at launch: `303c3a4`; GDS run:
https://github.com/georgc4/rv32-linux-soc/actions/runs/36615192813 . Fast checks and
docs passed; GDS was still running when this entry was written. An earlier CI run
was cancelled after correcting the contract for four legacy configuration fields
that LibreLane removes during migration. Main remains `adf6fd6`; this branch is
not yet a qualified submission. External I/O constraints remain provisional.

The companion route-preserving ECO starts with the same six equivalent-family
resizes and 17 noninverting buffers. Comparing connectivity and resized-cell
pins identifies 37 affected nets. The other 21,385 detailed routes are encoded
FIXED; unrelated cells are LOCKED during legalization. Only ECO cells moved, and
an exact normalized per-net DEF geometry comparison verified every protected
route unchanged. Logical pin connectivity was also checked after the roundtrip.

Pinned TritonRoute reads the *encoded wire-path type*: `dbNet.setWireType` alone
is insufficient. DEF export/re-import converts the encoding. An initial prototype
left master-pin access-point IDs referencing the destroyed block and crashed in
`dbMPin::getPinAccess` during detailed-route initialization. The preparer now clears
preferred access points and destroys old block access-point records before the
roundtrip. This changes cached routing metadata, not protected geometry.

Other integration findings retained in the logs: use exact OpenDB net lookup
instead of pattern matching an escaped bus net; disable the separate automatic
antenna-repair step, not only its iteration count. The first selective global
route reported eight coarse-grid overflow units. This experiment permits coarse
overflow to test actual detailed routability while keeping every final signoff
check enabled. CI still disallows global congestion. Final antenna checking is
retained even though automatic broad antenna repair is disabled.

Current attempt: `electrical-library15-preserved-routes-v6`, input directory
`build/experiments/route-preserving-eco-inputs-v3`. The runner automatically audits
protected routes after detailed routing and records missing evidence as missing.
A prepared/ legalized database passing the preservation audit is not a completed
ECO or a signoff pass. Prior short failed attempts and the router crash are kept
as failed results; no final slew improvement is claimed yet.

## 2026-09-30 — Completed ECO and clean CI outcomes

The route-preserving v6 experiment finished on September 29 at 19:38 UTC.
Its extracted STA reports zero slew and capacitance violations in all nine
corners, positive setup/hold everywhere (worst setup +9.114224 ns, hold
+0.054048 ns), and the post-route preservation audit confirms all 21,385
protected routes unchanged. This is promising diagnostic evidence, not signoff:
physical verification failed with 9 router markers (8 shorts, 1 metal-spacing),
61 Magic markers, 10 KLayout markers, 59 LVS errors, and 2 antenna-violating
nets. These tool counts are not additive independent defects. The LVS report
also shows supply-port matching problems requiring explicit investigation.
Generic external I/O constraints remain provisional.

The clean GitHub build completed on September 29 at 20:48 UTC. Logs prove both
RV32.PartitionDesign and RV32.SeedPlacement executed; final DRC, LVS and antenna
checks passed, as did setup and hold. The build correctly failed slew/capacitance
gates. This validates that CI is executing our physical technique, but does not
qualify its artifact or validate successful submission/provenance packaging yet.
Precheck and gate-level jobs were skipped after GDS failed. PR #1 remains draft.
The Mac experiment container has exited; neither of these two runs is active.

Recommended next work: map the physical ECO failures first, including LVS supply
connectivity, then enlarge the editable routing neighborhood only around the
conflicting wires/pins while preserving distant routes. Repair the two antenna
nets locally and rerun extraction plus all physical checks. Finally make the
repair selection report-driven for the clean CI-produced database, rather than
copying hard-coded cell names from the local checkpoint. Rerun CI with the
qualified repair integrated before promoting the submission.

## 2026-09-30 — Expanded repair experiment moves into CI

The user explicitly requested the next experiment and directed that changes run
in CI from now on. Full physical experiments now run on
`codex/partitioned-signoff-ci` through the pinned Tiny Tapeout action/fork. Local
work is limited to editing, analysis and fast validation; no local PnR job was
launched for this experiment.

Follow-up inspection of the prior v6 failure established that all eight router
short markers join a rerouted ECO net to a protected net. The extracted SPICE
also merges the input/output nets of five inserted buffers even though their
powered Verilog netlist keeps those terminals distinct. This confirms physical
connectivity damage; the zero-slew result is not a valid signoff. The top-level
supply-port matching failures do not by themselves prove a separate power-grid
fault. Three fewer diode devices appear on the extracted side of LVS, another
reason not to equate the 59 mismatch count with 59 independent defects.

CI commit `0f2390aebcab129f10275dccba6f242ddc6c45c7` adds report-driven repair
selection after the first extracted nine-corner STA pass. Driver identities come
from that build's ODB, not hard-coded local checkpoint names. Same-family resizes,
long-branch noninverting buffers and spatial clock-buffer splitting are bounded;
unsupported repairs fail explicitly. The neighborhood includes routes within
20 um of changed old/new cell footprints and 5 um of the original affected wire
segments. Selected whole nets may reroute; distant routes remain encoded FIXED.
A 25% net-count ceiling bounds accidental broad rerouting. Logical driver and
protected-geometry audits run before and after detailed routing. Antenna repair
is enabled; DRC/disconnected-pin checks, filler insertion, RCX and all-corner STA
repeat before the ordinary final Magic/KLayout/LVS and electrical gates.

Nine pure helper tests passed, including clean reports that omit violation
sections and DEF relative-coordinate handling. The parser also read 21,385
existing routed nets / 565,407 segment-point boxes. Plugin loading and all 95
steps' configuration validated in the pinned container without a physical run.
The tests are part of the GDS workflow. The provenance manifest requires all
new stages and hashes all runtime flow scripts.

Current experiment: https://github.com/georgc4/rv32-linux-soc/actions/runs/36808009959 .
PR #1 remains draft and main remains unchanged. This entry records the launch,
not a successful repair or a qualified artifact.

## 2026-09-30 — Datasheet-faithful memory experiments move into CI

The user requested more experiments and models close to the purchased parts:
four ESP-PSRAM64H and one W25Q128JVSIQ-TR. The public manufacturer datasheets
were available (PSRAM via the Adafruit product mirror); no user upload was
needed. CI branch commit **8e069576fb3384952e3f668e83c26376c29abb7b** adds a
strict digital model alongside the existing accelerated Linux model.

The strict tests use actual capacities, elapsed flash BUSY times up to 3 ms
program / 400 ms erase, delayed outputs/release, power-up and reset requirements,
input/CS/clock timing, page wrap, one-to-zero NOR programming, and explicit
unsupported-command failures. Seventeen model self-tests include intentional
invalid transactions with exact expected failure reasons. All three bridge
profiles (typical/maximum operation latency and 6 ns/2 ns output delays) passed
locally at 20 MHz core clock. This is not complete emulation of every vendor
feature or analog board behavior; coverage is documented in the CI branch's
`docs/verification/datasheet-memory-models.md`.

The old gate smoke only checked reset. Its replacement uses the production
wrapper pins and unchanged ROM to boot the diagnostic through NOR and PSRAM,
check UART OK and RAM signature, then reject a bad-checksum reboot with UART E.
The RTL version passed (2.67266 ms simulated). The same bench is wired into the
GDS action's generated-netlist test, with cocotb 2.0.1 pinned to avoid upstream's
incompatible 1.8 default. Gate-level simulation is unit-delay, not extracted SDF,
and remains pending; no physical signoff claim follows from the RTL result.

A newly exposed interface limitation: PSRAM's 150 us initialization does not
cover NOR's up-to-5 ms write-inhibit interval. ROM/loader only read NOR. Strict
programming tests wait until 5 ms, and a negative test proves early writes are
rejected. A future updater must wait, or RTL must gain a separate write guard.
No synthesized RTL or physical scripts changed in this experiment.

CI launches:
- Memory matrix / existing regressions: https://github.com/georgc4/rv32-linux-soc/actions/runs/36809950960
- New revision GDS + stronger eventual GL test: https://github.com/georgc4/rv32-linux-soc/actions/runs/36809950961
- Earlier repair run 36808009959 was still running when these launched.

PR #1 remains draft. Main remains unchanged. CI completion and physical repair
results were not yet known when this entry was written.

### CI completion update — datasheet memory matrix

Run **36809950960** completed successfully on **8e06957**: the existing RTL
regressions, production-pin boot/rejection, and all three full-capacity timing
profiles passed in GitHub Actions. Both GDS runs (36808009959 and 36809950961)
were still in progress at this check; gate-level/physical results remain pending.

## 2026-09-30 — Full Linux against datasheet memory models

User asked whether to run Linux with the stricter chip models. CI commit
**6dc707f7766bc5b4c69bab2367034dd77d818fd7** adds the long acceptance workflow:
https://github.com/georgc4/rv32-linux-soc/actions/runs/36811346832 .

The test uses the exact previously accepted NOR image (SHA-256 590ed638...), now
stored as a 1.6 MiB compressed, size/hash-checked fixture with its kernel config.
It compiles staged production `src/*.v`, loads only the external NOR, and boots
through real serial transfers. The C++ driver now runs at 20 MHz and processes
all pending timed events so chip output/release delays cannot be skipped.
The CI branch's image build recipe also gained the existing ash prompt and
acceptance-program source, which were missing there despite the harness
expecting them.

Two profiles test 6 ns outputs / A5 PSRAM and 2 ns outputs / 5A PSRAM. The
nonzero patterns test some startup-data dependencies under Verilator's two-state
semantics; they are not four-state X propagation. Both local million-cycle
compile/driver smoke runs passed, and all 17 chip-model checks passed under both
Icarus and Verilator. Those smoke runs explicitly report linux_accepted=false.

A full pass requires userspace, an ash prompt, all 22 UART command bytes, and
ASH_PROGRAM_OK from /bin/acceptance_smoke. Every job preserves source, ROM,
physical config, image and simulator hashes plus progress/output/result files.
The limit is 20 billion cycles / 5.5 wall hours per hosted runner; an unfinished
run fails, rather than being treated as a boot pass. Full CI results were still
pending at launch. This tests RTL with modeled external chips, not gate-level
Linux or board analog behavior. Main is unchanged.

### Linux CI compiler compatibility correction

First launch 36811346832 passed both simulators' chip-model tests, then failed
C++ compilation because Ubuntu's Verilator lacks the optional
`VerilatedContext::statsPrintSummary` method. Commit **26f81b8** removes only
that reporting call. The million-cycle smoke still passed; the corrected long
matrix is https://github.com/georgc4/rv32-linux-soc/actions/runs/36811470885 .
This was a host-tool compatibility failure, not Linux or chip timing evidence.

## 2026-09-30 — Shared buffer trees and distributed repair neighborhood

The four repeated GDS launches through **36811470893** failed before applying
an ECO: the independent per-sink chain planner proposed **874 buffers** for
**37 target nets**, exceeding the unchanged 250-buffer bound. Initial detailed
routing was clean; these failed plans give no evidence about repaired LVS or STA.
The user authorized local experiments on a copy of the CI database before dispatch.

CI branch commit **0fc5c9b** shares spatial buffer trunks, bounds fanout to eight
and planned Manhattan segments to 90 micrometres, and prunes redundant junctions.
The exact failed-CI checkpoint now needs **207 buffers and 36 driver resizes**.
An 80-micrometre version needed 264 buffers and was rejected; the checked-in
geometry fixture makes this comparison reproducible. These geometric bounds are
not extracted timing guarantees and legalization can lengthen segments.

Local legalization passed. The pre-route audit checked **55,220 original input
pins** and **8,950 exact protected routes**. Keeping the 20/5 micrometre
cell/route halos selects **12,505 editable nets / 21,248 original routed nets**,
a conservative 58.85% ratio including 207 newly added nets. Cell halos alone
select 9,490 nets; even shrinking to 1/0.5 micrometres still selects 7,080 nets.
Rather than remove nearby routing freedom, the trial explicitly raises the
editable-net budget from 25% to **65%**. This is a distributed repair; rerouted
neighbors may acquire new slew/capacitance violations. All final DRC, LVS,
connectivity, antenna, timing and electrical gates remain required.

The local global route completed with **42 units of coarse overflow**. Detailed
routing was still in progress at this checkpoint. Local Liberty revision
0fe599b2 differs from CI's 8afc8346, so local results are screening evidence only.
All **15 helper tests** pass and all **95 flow steps** register in the pinned
LibreLane 3.0.14 container. Physical provenance hashes were refreshed.

Evidence snapshot: [shared-tree checkpoint](evidence/20261001T060502Z/).
The new physical CI build was dispatched by pushing 0fc5c9b to the draft PR #1
branch. Main is unchanged. The existing two-profile Linux matrix **36811470885**
continues without a restart; no full Linux acceptance was established here.

## 2026-10-01 — CI antenna repair loses protected routes

The user asked to inspect failed GDS run [36822832367](https://github.com/georgc4/rv32-linux-soc/actions/runs/36822832367).
The 207-buffer shared-tree plan, legalization, and pre-route audit passed. The
first ECO detailed-route checkpoint preserved all **8,950 protected nets**.
After antenna repair/reroute pass 1, **218 protected routes were missing**; after
passes 2 and 3, **228 were missing**. Surviving protected paths were unchanged.
Example `_00378_` retains logical pins `_13425_/X` and `_27062_/D` but loses its
wire geometry. The guard stopped at **RV32.AuditECORoutes**, not buffer planning.
This is a real connectivity concern, not a harmless DEF text-format mismatch.

CI inserted **255 antenna diodes** across the three passes. The final router DRC
count is **zero**. A fresh local antenna check on the exact final CI ODB also
reports **zero net and pin violations**; the metrics file's 2 nets/3 pins were
from the check before the last repair. Neither zero count proves connectivity.
Post-ECO disconnected-pin checking, extracted STA, Magic/KLayout and LVS were
not reached. No repaired-GDS qualification is claimed.

The separate local route, which omitted antenna repair, completed in 13m20s with
zero router DRC and now passes the post-route audit (55,220 original input pins,
8,950 protected routes). This comparison isolates the failure to the antenna
repair/reroute loop. The next correction should preserve protected wires across
that loop, or explicitly promote affected nets into the editable set and route
them; audit every pass and check disconnected pins before signoff. Exact tool
operation causing the loss remains to be instrumented. Main is unchanged.

Evidence: [checkpoint comparison](evidence/20261001T180539Z/).

## 2026-10-01 — Guard antenna repair and launch the next CI run

The user authorized the fix and next run. Commit **7fd688d** on the CI branch
adds a same-block OpenDB wire backup around antenna repair. It records protected
pin membership, cell masters, positions/orientations and top-port geometry;
restores a deleted path only when those signatures remain unchanged; rejects
existing altered paths or changed pins; and verifies every detailed-route pass.
The pinned GRT `updateDirtyNets` code destroys dirty wires before testing whether
pin positions changed. A standalone repair process did not reproduce the loss,
but the routing/repair sequence did, underscoring why the complete sequence matters.

The local reproduction inserted **227 diodes** and deleted **218 protected
paths** during the first antenna repair pass. The guard restored all 218 before
routing resumed, and checked all **8,950 protected paths**. Subsequent detailed
routing finished with **zero router DRC**. The independent post-route audit
passed all **55,220 original input pins** and **8,950 protected routes**.
After this one-pass local regression, **6 antenna nets / 10 pins remain**;
this is not a fully signed-off result. CI runs the complete three-pass loop,
then disconnected-pin checks, extraction, all-corner STA, DRC and LVS.

Six native OpenDB fault-injection checks verify no-op/result forwarding,
deleted-wire restoration, altered-geometry rejection, protected pin-change
rejection, repair-error propagation, and detection of wire loss during routing.
They also run in CI on a disposable copy of each build's own database. All 15
Python helper tests pass, all 95 flow steps register, and source hashes were
refreshed. Local linking still uses PDK 0fe599b2; CI uses 8afc8346.

Next run: [36943817911](https://github.com/georgc4/rv32-linux-soc/actions/runs/36943817911).
Draft PR #1 is updated; main is unchanged. No signoff gate was disabled.
Evidence: [guarded-repair regression](evidence/20261002T000237Z/).

## Physical shorts and a second extracted-timing ECO (2026-10-02)

The user asked to check the failure, fix it, and redispatch. Run **36943817911**
reached final signoff: the previous antenna guard preserved all 8,950 protected
routes, but Magic reported 12 DRC, KLayout four DRC, and LVS 13 errors. Four
logically separate nets were physically merged near (490.59, 74.29) um. One
contact existed before antenna repair; a fresh router process alone retained it.
Zero router DRC and logical connectivity therefore did not establish physical
connectivity. No final signoff gate was bypassed.

Commit **00ef812** adds independent same-layer centerline contact detection,
explicit promotion/rerouting of the contacting protected nets, and separate
processes for routing and antenna repair. At most three contact retries are
allowed per pass under the existing 65% editable-net limit. Local four-net
repair eliminated all detected contacts while preserving 8,949 other routes
and all 55,220 original input-pin drivers. The actual nested LibreLane step
completed with zero router DRC and zero antenna violations. The standalone
antenna child was exercised on an antenna-clean DB; a full nonzero-antenna loop
remains CI validation. Full physical DRC/LVS are still required.

The first ECO cleared its 37 targets, but extracted reports exposed 208 failing
pins on 29 different neighboring nets. A bounded second round consumes these
new reports and repeats routing, audits, antenna checks and nine-corner
extraction. The local plan uses 161 buffers and 29 resizes. Resized drivers must
be unlocked again before legalization, and boundary decaps must survive filler
removal; both issues were fixed. Placement legality and the pre-route audit
pass (55,677 pins, 9,600 protected routes). The initial 20/5 um margins exceeded
the 65% budget at 76.6%; 5/1 um margins select 12,016 editable nets, or 56.0%.
Tighter margins may constrain routing and are an experiment, not closure proof.

All 21 Python helper tests and six native guard fault checks pass. The manifest
verifies both ECO rounds among 108 flow stages. Local Liberty is PDK 0fe599b2,
whereas CI uses 8afc8346. No local electrical or physical result is presented as
fab qualification. Main remains unchanged and draft PR #1 is updated.

New CI run: [37028071522](https://github.com/georgc4/rv32-linux-soc/actions/runs/37028071522).
GitHub created two identical push runs; duplicate 37028072405 was cancelled.
Evidence: [compact regression snapshot](evidence/20261002T153757Z/). Full ignored local
artifacts remain under the CI worktree's build/signoff-fix and ci-36943817911.

## Where the evidence lives

- Source changes and experiment runners are in Git. RTL trials use exact
  commits; the principal architecture branches are separate from the harness.
- [Timestamped evidence snapshots](evidence/) preserve compact result JSON,
  configurations, partition assignments, ECO Tcl, diagnostics, selected reports,
  and a SHA-256 manifest. A snapshot of a running job is explicitly unfinished.
- Full logs, ODB/GDS, extracted parasitics, Linux images, and large archives
  remain under ignored `build/` paths or previously configured artifact stores.
  A hash records identity; it does not back up those bytes. This checkpoint
  does not establish that every large artifact has a remote backup.
- This journal summarizes the conversation's decisions. It is not a complete
  chat transcript or a claim that every intermediate edit was committed when
  made. The preservation commits retain actual timestamps; no history was
  fabricated or backdated.

For the blog, the defensible story is: inspect the real evidence; fix a
misleading qualification metric; shorten a logic path without adding cycles;
test the user's connectivity-partitioning hypothesis; distinguish clean
routing, timing closure, and electrical limits; keep regressions visible.
The final silicon/signoff outcome is still open.
