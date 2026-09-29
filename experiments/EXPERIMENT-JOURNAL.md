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
