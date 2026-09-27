# 5×4 interactive-speed campaign

The submitted GitHub `main` metadata requests 5×4 SKY26d tiles. This is a
project size choice, not a paid tile allocation or a qualified GDS. The portal
said SKY26d sales were not open on 2026-09-27.

## Candidates

The reference is the 16-byte, one-line instruction cache at `7ebde5c`.
The next three immutable RTL revisions are listed in
[`speed-5x4-acceptance.json`](speed-5x4-acceptance.json):

| Revision | Change | Why it may help |
|---|---|---|
| `ceb45b7` | Four direct-mapped 16-byte physical instruction lines | Retain several adjacent code lines instead of evicting on every line crossing. |
| `6ed28d6` | Eight direct-mapped instruction lines | Reduce instruction misses across short calls and branches. |
| `7825dd2` | Eight instruction lines plus eight Sv32 TLB entries | Reduce page walks if the Linux working set conflicts in the four-entry TLB. |

All misses use the actual quad-serial PSRAM pins and protocol. A line fill is
still 16 bytes, keeping the PSRAM chip-select interval unchanged. Stores
invalidate instruction lines to preserve self-modifying code and kernel text
updates. The directed serial test checks two simultaneously resident lines,
two actual fills, and cache invalidation. The TLB test checks page walks,
hits, flush, SATP change, permissions and A/D updates.

Run the full true-serial Linux 6.12 / BusyBox ash acceptance on each RTL
revision. Use the exact smaller-kernel image SHA-256 recorded by the runner.
Physical trials use 5×4 only, with a 50 ns/`AREA 2` GDS run for each
candidate and 45 ns/`DELAY 2` trials for the two eight-line candidates.
The queue starts with a one-line cache rerun at 0.05 ns post-placement hold
margin. Its zero-margin run produced GDS and passed Magic DRC/LVS, but the
flow failed final hold timing; KLayout was not run by the experiment gate.
The added margin is a measured repair attempt, not a claimed fix.
The 45 ns trials measure implementation headroom; a faster silicon clock
also requires a matching UART divisor, timer frequency and device tree.

Every physical candidate must reach final GDS and pass full KLayout DRC,
Magic DRC, Netgen LVS and antenna checks. Route and physical verification
have **no wall-clock timeout**. Physical-only constraints may reuse Linux
acceptance for the same RTL commit and flash image, with provenance recorded
by the runner. No new candidate replaces the working reference until both
gates pass. Compare cycles to the ash program marker, serial command counts,
routed setup/hold slack, utilization, and instance area. Boot-cycle count is
not an interactive latency benchmark; after the first qualified winner, run
a short shell-command latency workload on the same image.

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
