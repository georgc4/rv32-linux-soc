# 5×4 interactive-speed campaign

The submitted GitHub `main` metadata requests 5×4 SKY26d tiles. This is a
project size choice, not a paid tile allocation or a qualified GDS. The portal
said SKY26d sales were not open on 2026-09-27.

## Candidates

The reference is the 16-byte, one-line instruction cache at `7ebde5c`.
The next six immutable RTL revisions are pinned in
[`speed-5x4-acceptance.json`](speed-5x4-acceptance.json) and
the related candidate manifests:

| Revision | Change | Why it may help |
|---|---|---|
| `ceb45b7` | Four direct-mapped 16-byte physical instruction lines | Retain several adjacent code lines instead of evicting on every line crossing. |
| `6ed28d6` | Eight direct-mapped instruction lines | Reduce instruction misses across short calls and branches. |
| `7825dd2` | Eight instruction lines plus eight Sv32 TLB entries | Reduce page walks if the Linux working set conflicts in the four-entry TLB. |
| `f07fc47` | Sixteen instruction lines plus eight TLB entries | Spend more of the 5×4 area margin to retain code across a larger working set. |
| `246c244` | One instruction line plus eight TLB entries | Isolate the larger TLB's speed benefit while keeping the cache layout close to the routed one-line design. |
| `d765508` | No instruction cache plus eight TLB entries | Measure the TLB gain without cache flops or cache routing. |

All misses use the actual quad-serial PSRAM pins and protocol. A line fill is
still 16 bytes, keeping the PSRAM chip-select interval unchanged. Stores
invalidate instruction lines to preserve self-modifying code and kernel text
updates. The directed serial test checks two simultaneously resident lines,
two actual fills, and cache invalidation. The TLB test checks page walks,
hits, flush, SATP change, permissions and A/D updates.

Run the full true-serial Linux 6.12 / BusyBox ash acceptance on each RTL
revision; the sixteen-line candidate uses
[`speed-5x4-large-acceptance.json`](speed-5x4-large-acceptance.json).
The one-line/eight-TLB comparison uses
[`speed-5x4-one-line-tlb8-acceptance.json`](speed-5x4-one-line-tlb8-acceptance.json)
and [`speed-5x4-one-line-tlb8-physical.json`](speed-5x4-one-line-tlb8-physical.json).
The no-cache/eight-TLB comparison uses
[`speed-5x4-no-cache-tlb8-acceptance.json`](speed-5x4-no-cache-tlb8-acceptance.json)
and [`speed-5x4-no-cache-tlb8-physical.json`](speed-5x4-no-cache-tlb8-physical.json).
Use the exact smaller-kernel image SHA-256 recorded by the runner.
Physical trials use 5×4 only, with a 50 ns/`AREA 2` GDS run for each
candidate and 45/40 ns `DELAY 2` trials for the eight- and sixteen-line
candidates.
The queue starts with a one-line cache rerun at 0.05 ns post-placement hold
margin. Its zero-margin run produced GDS and passed Magic DRC/LVS, but the
flow failed final hold timing; KLayout was not run by the experiment gate.
The added margin is a measured repair attempt, not a claimed fix.
The 45/40 ns trials measure implementation headroom; a faster silicon clock
also requires a matching UART divisor, timer frequency and device tree.

Every physical candidate must reach final GDS and pass full KLayout DRC,
Magic DRC, Netgen LVS and antenna checks. Route and physical verification
have **no wall-clock timeout**. Physical-only constraints may reuse Linux
acceptance for the same RTL commit and flash image, with provenance recorded
by the runner. No new candidate replaces the working reference until both
gates pass. Compare cycles to the ash program marker, serial command counts,
routed setup/hold slack, utilization, and instance area. Boot-cycle count is
not an interactive latency benchmark; after the first qualified winner, run
a short shell-command latency workload on the same image. The current
acceptance command already exposes a first comparison: the dashboard reads
`SHELL_INPUT` and `ACCEPTANCE` markers and plots command-to-completion cycles.
The accepted no-cache reference takes 132,317,853 cycles, or 6.62 seconds
at the 20 MHz simulation clock, for `/bin/acceptance_smoke`.

## Commands and run logs

```sh
python3 experiments/runner.py plan experiments/speed-5x4-acceptance.json
python3 experiments/runner.py run experiments/speed-5x4-acceptance.json \
  --all --phase acceptance \
  --flash-image build/experiments/images/no-plist-no-vm-pgtable/flash.bin \
  --timeout-hours 24 --max-cycles 40000000000
python3 experiments/run_physical_queue.py experiments/speed-5x4-physical.json
python3 experiments/run_physical_queue.py experiments/speed-5x4-timing.json
```

The background launches for this batch are logged in ignored
`build/experiments/speed-5x4-*.log`; per-run results are in
`build/experiments/runs/<id>/result.json`. The physical queue runs one
candidate at a time and archives completed workspaces, preserving the newest
OpenROAD database. Linux runs may proceed concurrently with each other and
with physical implementation because they have distinct run IDs.
