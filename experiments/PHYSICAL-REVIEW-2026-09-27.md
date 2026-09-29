# Physical implementation review — 2026-09-27

## Recommendation

Use the 5×4 one-line instruction-cache run `7ebde5cec555-e811a35c1f2d` as the physical optimization reference. Keep `31d9966b2614-5dea292570bf` as the smaller, slower alternative. Neither the dashboard's qualification label nor its mid-flow setup number establishes full multi-corner timing closure. The latest one-line reference **fails slow-corner setup at 50 ns** despite passing the existing physical/functional gate.

8×2 is a research possibility, not a demonstrated implementation. I would not make it the delivery plan or expect placement attractions alone to qualify it. Finish assessing the already-running jumper experiments before another 8×2 campaign; prioritize fixing the 5×4 implementation and measurement flow.

This review reads the local result ledger, logs, exact archived final reports, production and commit-pinned RTL, and the one-line reference's final OpenDB. It does not launch implementation runs or modify RTL, flow settings, existing evidence, or running jobs. Detailed extracted evidence and read-only analysis scripts are under `build/experiments/review-2026-09-27/`.

## Latest measured candidates

All command times below are simulated `/bin/acceptance_smoke` dispatch-to-completion at 20 MHz, including fork/exec and program execution. They are not general shell responsiveness measurements or signed-off silicon timings. The image is SHA-256 `590ed63886833648537907532aac191c210e3eb4e36e300c99c4de4707e6f615`.

| Candidate / run | Physical evidence | Instance area | Command time |
|---|---|---:|---:|
| Shared adder, no cache, four TLB entries — `31d9966b2614-5dea292570bf` | Existing physical and Linux gates pass | 243,230 µm²; 56.49% | 6.616 s |
| One cache line, four TLB entries, 0.05 ns hold margin — `7ebde5cec555-e811a35c1f2d` | Latest physical and Linux gates pass; slow-corner setup fails | 282,602 µm²; 65.64% | 4.961 s |
| One cache line, eight TLB entries — `246c244cbeac-f5a15bbee41e` acceptance / `246c244cbeac-105362e499c1` physical | Linux passes; detailed routing in progress | No final result | 3.929 s |
| No cache, eight TLB entries — `d76550884dd8-85f1ffb42c35` | Linux passes; physical run queued behind one-line/eight-TLB trial | No final result | 4.743 s |
| Eight cache lines, eight TLB entries — `7825dd2f9db9-8888ea2685b8` | Linux passes; post-CTS repair/legalization fails | 316,818 µm² at CTS; not routed area | 3.544 s |

The one-line reference improves this command by 25.0% and total acceptance cycles by 19.0% versus the shared-adder candidate, for 16.2% more final instance area. Its GDS hash is `ddb3cf7fc7245c4fbb20a8bd70c5e991eecfc01e7a7ed83a6aabeb089c953a6b`; full KLayout, Magic, Netgen and antenna checks pass. The older `b3fdd5a8fa31-af3b9db59426` also meets the repository gate but is dominated by the smaller shared-adder result at identical measured cycles. Checked-in RESULTS.md and SPEED-5X4.md lag the live ledger.

## Timing is the first qualification gap

The exact one-line final `55-openroad-stapostpnr/summary.rpt` and `final/metrics.json` report:

- Worst setup slack **−9.4466 ns**, at `max_ss_100C_1v60`; 979 violating endpoints in that corner and TNS −3611.95 ns. Nominal-RC slow corner also fails at −8.0894 ns.
- Worst hold slack **+0.02655 ns**, with no hold violations across the nine reported corners.
- Nominal typical-corner setup slack +21.2029 ns.
- Worst reported electrical counts: 245 max-capacitance and 11,980 max-slew violations. These require investigation against the actual limits and intended operating envelope.

The resolved flow uses `TIMING_VIOLATION_CORNERS=["*tt*"]`, `SETUP_VIOLATION_CORNERS=null`, `HOLD_VIOLATION_CORNERS=["*"]`; max slew/cap corner selectors are `[""]`. Timing-driven global placement is **disabled**, routability-driven placement enabled, and post-global-route timing repair disabled. PNR and signoff SDC overrides are null, using the fallback SDC.

`experiments/runner.py:207` collects only immediate stage `or_metrics_out.json` files and overwrites per-corner values instead of reducing over corners. This run therefore records stage 43 mid-flow WNS=0 and register-to-register slack +26.564 ns, missing final multi-corner timing. `experiments/visualize.py:90` requires physical checks and functional acceptance, but no explicit final timing pass. The label is accurate only for that narrower contract.

The worst final path is `_28662_/Q` (`soc.cpu.funct7[3]`) → decode/control and writeback → `_27914_/D` (`soc.cpu.regs[4][20]`). In the reported data path, 53 cell arcs sum to about **58.420 ns**, versus **0.359 ns** of explicit interconnect delay. A long serial OR/decode chain and cascaded fanout buffers are prominent. Wire loading contributes to cell delays, so this decomposition does not say placement is irrelevant; it does show that shortening visible wires alone cannot be assumed to recover 9.45 ns. Audit why delay-buffer masters are selected for ordinary fanout repair before changing their allowed usage; retain appropriate cells for hold repair.

## Placement attractions: measured targets

The final one-line ODB has an 856.52 × 511.36 µm die. A read-only pin/route inventory measured 22,572 non-power nets with at least two located terminals:

- 102 nets have pin bounding-box HPWL above 500 µm, including four clock nets. Clock distribution must be evaluated separately from data clustering.
- 232 nets have routed length above 500 µm; eight exceed 1 mm. Total decoded signal/clock wire length is approximately 1.274 m.
- 27 of the 64 `time_value` nets exceed 500 µm HPWL. Those 64 nets account for 29.10 mm of routing. Place timer state/comparison and CSR time-read logic with deliberate adjacency, using bit slices and local consumer groups rather than one giant cluster.
- Eight operand-B bits exceed 500 µm HPWL. The 32 named operand-B nets total 11.75 mm. Inspect their register-file, ALU, shifter and MDU consumers and buffered branches before choosing groups.
- `_13346_` connects `_25171_/X` to `_25172_/C1`: 529.21 µm HPWL, **1,139.87 µm** route. These cells belong to the CSR/time read mux. This is a concrete locality and detour candidate.
- `_03166_` runs from cache-line mux `_21500_/X` to `hold4276/A`: 156.29 µm HPWL, **757.74 µm** route. Shortening it must be followed by hold analysis; hold-related routes cannot simply be deleted or compressed without requalification.

The raw net names, endpoints, HPWL and route lengths are in `build/experiments/review-2026-09-27/net-locality.json`. HPWL is a pin bounding-box metric, not a point-to-point distance for multi-terminal nets, and includes connected antenna terminals. Reconstruct buffered logical nets before attributing total fanout or total bus cost. These are geometric targets, not automatically the worst timing paths.

The installed OpenROAD revision `dcf36133a369abc8f3c5e5738cd4d82e4903c0e0` supports `placement_cluster`; verified by querying the pinned container and its matching source. Apply small, non-overlapping connectivity-based groups **before global placement**, then rerun legalization, CTS, repair and routing. Resolve actual synthesized instances; do not rely on hierarchy patterns matching flattened `_NNNNN_` cells. Avoid hard fences around whole CPU/adapter blocks and avoid merging all consumers of reset/clock/high-fanout controls into giant groups. Local grouping can increase pin congestion even while shortening HPWL.

References: [pinned placement command implementation](https://github.com/The-OpenROAD-Project/OpenROAD/blob/dcf36133a369abc8f3c5e5738cd4d82e4903c0e0/src/gpl/src/replace.tcl), [global placement documentation](https://openroad.readthedocs.io/en/latest/main/src/gpl/README.html), [placement padding documentation](https://openroad.readthedocs.io/en/latest/main/src/dpl/README.html). Use the pinned implementation when current documentation differs.

## Why 8×2 remains high risk

The 8×2 placeable core is 302,420 µm², versus 430,538 µm² for 5×4: about 29.8% less core area, with a much longer, narrower outline. Simply dividing the qualified one-line 5×4 cell area by the smaller core gives **93.45%** utilization before accounting for changed repair overhead. This is a capacity comparison, not a predicted 8×2 placement result.

The compact-MDU/state-sharing no-cache run `4f836c5b3e6c-2447128dd710` is more promising: 219,569 µm² and 72.60% at global route, with Linux acceptance. However, antenna repair inserted 165 jumpers on 152 nets, then failed legalization on 15 instances. There is no final GDS. Earlier shared-read/shared-adder 8×2 trials fail around 78–81% utilization.

Jumper-only successors `c1c485de7289-679940ae8188` and `4f836c5b3e6c-3a934ee08209` have reached detailed routing but remain unfinished. At this review they had been running about 19 hours; recent completed-iteration violation totals were approximately 185k and 174k. These are intermediate router counts, not final DRC results, and are not proof of impossibility. They do show that bypassing the earlier antenna/legalization failure has not yet established routability. The local GUI launch points to the combined 8×2 antenna-repair checkpoint, not a final routed GDS checkpoint; the running router is later in the flow.

A reasonable 8×2 research target would be roughly 60–65% utilization **after repair**, about 181–197k µm², with bounded local congestion. Relative to the compact run's 219.6k pre-final area that suggests another roughly 10–17% reduction plus any later repair overhead. This is an engineering screening target, not a guaranteed or mandatory routability threshold. A characterized memory/register-file macro could change the tradeoff, but the exploratory custom cell is not presently an integration-ready solution.

## Ordered 5×4 optimization plan

1. **Fix evidence and constraints first.** Read final metrics and retain every corner's setup/hold/TNS/electrical counts; display the worst corner and stage. Keep physical/functional qualification distinct from timing qualification. Enforce the selected operating-corner envelope explicitly. Add justified reset, asynchronous UART, serial-memory I/O and board-load constraints; do not false-path functional decode or register-file paths. Add a regression test proving that this archived slow-corner failure cannot appear as a timing pass. Record resolved configuration, SDC, cluster-file and flow hashes in the run identity so physical experiments cannot collide or reuse stale results.
2. **Establish a controlled placement comparison on `7ebde5c`.** Keep 5×4, image, 50 ns target, AREA 2 and the proven 0.05 ns hold setting fixed. First compare baseline with timing-driven global placement using the required slow/fast corners for analysis and repair. Retain routability-driven placement. This isolates the effect before adding custom groups. An unchanged archived baseline is the control; do not needlessly rerun Linux.
3. **Test attractions one family at a time.** On the winning placement setup, try (a) timer/CSR mux bit-slice groups, (b) register-file operand/decode/writeback groups, (c) cache fill/output mux and serial data-path groups near their fixed TT I/O interface. Measure group cell area, pin density and congestion before committing to tight footprints. Test modest local padding around demonstrated repair hotspots separately; blanket padding consumes scarce area. Route each surviving candidate fully and rerun all physical checks. Compare total and tail wire lengths, extracted capacitance, critical-path delay, antenna fixes, repair buffers, local overflow and final utilization, not screenshots alone.
4. **Reduce repair overhead while closing both setup and hold.** The reference grows from 216,390 µm² at floorplan to 282,602 µm² final (+30.6%). It inserts 2,971 post-placement design-repair buffers, 398 CTS buffers and 2,126 hold buffers; post-CTS timing repair alone adds 21,284 µm². Audit buffer-master selection, corner coverage, fanout distribution and CTS skew, and evaluate post-route-estimate timing repair. Do not recover area by accepting hold violations or reverting to the previously failing zero-margin cache run.
5. **Repair the decode/writeback logic if it still dominates.** Use the reported funct7-to-register-file cone to guide balanced legality/decode reductions, earlier registered predecode using the existing operand-read phase, local control replication, or a different mapping strategy. Make one change per pinned commit. Verify instruction/trap/CSR/MDU/atomic behavior with directed tests, then the full true-serial Linux gate for every changed RTL. No blanket multicycle exception without a proven launch/capture protocol. Placement cannot remove the logic depth identified above.
6. **Then choose the faster architecture.** Prioritize the already-running one-line/eight-TLB candidate and queued no-cache/eight-TLB comparison. The former cuts measured command time another 20.8% versus the qualified one-line/four-TLB reference; the latter offers a smaller-cache alternative. Larger caches should wait: four lines currently struggle in routing, eight lines/eight TLB failed legalization, and sixteen lines/eight TLB did not improve this measured command over eight lines. A winner needs final GDS, clean checks, final timing and Linux evidence. Add representative short shell-command latency measurements before optimizing only this acceptance program.
7. **Promote only an exact, reproducible implementation.** Require zero final DRC/LVS/antenna issues, nonnegative setup/hold at all required corners, resolved electrical violations, explicit I/O constraints, and matching RTL/image acceptance. Archive the exact GDS/ODB, reports and hashes. Only then test faster clock targets or revisit 8×2 with the measured placement improvements. A clock change also needs UART/timer/device-tree consistency.

For an initial screening objective, seek at least a 10% reduction in long-net tail or repair overhead without worsening congestion, and demonstrable improvement in worst-corner setup. This is an experiment selection criterion, not a promised gain. The final acceptance criterion remains complete physical, functional and timing closure.
