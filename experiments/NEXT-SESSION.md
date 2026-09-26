# Next physical and architecture session

## Starting point, 2026-09-25

The chip boots Linux 6.12 and reaches interactive BusyBox ash through the
SoC's UART using true quad-serial NOR and PSRAM transfers in simulation. The
4-entry TLB plus shared core register read port (`b3fdd5a`) passed the
ash/program gate at 17,129,216,271 cycles with flash SHA-256 `590ed638…`.
Its 5×4 `AREA 2`, 50 ns, zero-margin physical run produced a 247,744 µm²
instance-area GDS. An independent full KLayout FEOL/BEOL/off-grid DRC on
that exact GDS found zero items; Magic DRC and Netgen LVS also passed. Its
legacy physical result used the baseline flash image, so the existing
dashboard does not treat the two records as one same-image qualified point.

The 2-entry TLB plus shared core read port (`e360da0`) has the lowest routed
area, 243,676 µm² on 5×4, but did not reach `/init` by 20 billion cycles
with the baseline image. The 2-entry shared-MDU design's 246,819 µm² GDS
reported an antenna violation. Neither 2-entry version can replace the
4-entry reference on current evidence. Earlier 8×2 runs of the 4-entry and
2-entry shared-read designs failed at antenna repair/detailed placement.

## Required result contract

Every new physical candidate must run to the **final GDS**. To pass its PNR
stage, it must have zero items in full KLayout `sky130A_mr.drc` with FEOL,
BEOL, and off-grid enabled, zero Magic DRC violations, uniquely matching
Netgen LVS netlists, and zero antenna violations. The runner records all
report hashes, the GDS hash, PDK revision, and KLayout deck hash. A flow that
stops before GDS fails; it cannot be called a routed candidate. The
interactive Pareto frontier additionally requires the true-serial BusyBox
ash plus `/bin/acceptance_smoke` pass.

For the same exact RTL commit **and flash image hash**, physical and synthesis
knob changes reuse the previous proven Linux result. The queue attaches that
evidence automatically, including the original run ID, log, harness hash,
and serial-model hash. An RTL change or image change requires a new complete
Linux acceptance run. The two-item hash condition deliberately prevents a
different kernel image from silently inheriting a pass.

## Ordered experiments

1. **Establish a new qualified 5×4 reference.** Run
   [`next-5x4-baseline.json`](next-5x4-baseline.json), pinned to `b3fdd5a`
   and the already accepted smaller kernel. It repeats the established 50 ns
   `AREA 2` physical settings under the new complete GDS gate, then reuses
   the exact commit/image Linux result. Compare the new area and timing with
   the historical 247,744 µm² GDS. Stop and investigate if the rerun is not
   reproducible.
2. **Test hold robustness.** Run
   [`next-5x4-hold.json`](next-5x4-hold.json) with 0.05 and 0.1 ns
   post-placement hold margins, one setting at a time. Record hold endpoints,
   inserted buffers, routed area, setup and hold slack, and all GDS checks.
   The old zero-margin run is an area screen; this experiment measures the
   cost of additional hold repair.
3. **Test frequency headroom.** Run
   [`next-5x4-clock.json`](next-5x4-clock.json) at 40 ns and 33.333 ns,
   keeping `AREA 2` and margins fixed. The 50 ns reference corresponds to
   20 MHz; 40 and 33.333 ns are 25 and 30 MHz targets. Compare post-route
   timing and area. Add explicit external SPI/UART/reset I/O constraints
   before treating any achieved clock as silicon signoff.
4. **Screen 8×2 mapping strategies.** Run
   [`next-8x2-strategy.json`](next-8x2-strategy.json) at `AREA 0` and
   `AREA 1`. The historical `AREA 2` 8×2 run failed detailed placement near
   79% utilization. A successful screen must still reach final GDS and pass
   the full checks. If both fail, focus on RTL area rather than repeating
   density knobs at the same cell count.
5. **Architecture area trials, one Git commit each.** First finish the
   proposed 32×32 1RW+1R register-file macro path only after bitcell and
   array DRC/LVS, extracted timing, and an integration interface exist.
   Compare a standard-cell register bank with macro/multi-bank variants at
   fixed 4-entry TLB and image. Separately profile the SV32 adapter's
   stored tag/data bits and the core's remaining register read/decode muxes;
   implement one targeted reduction per commit. Use standalone synthesis as
   an inexpensive screen, then route promising changes through the full
   KLayout GDS gate and rerun true-serial Linux acceptance for each changed
   RTL commit. Revisit 2-entry TLB only if a complete ash/program run passes
   with an adequate cycle cap and no functional regression.
6. **Hardware and signoff follow-through.** Complete the Tang Nano 20K
   FPGA bring-up on the actual board revision when it arrives, including
   bidirectional traffic through the SoC UART and real serial flash/RAM.
   For the selected ASIC candidate, add I/O timing constraints, review
   routed multi-corner setup/hold, power and pad rules, and rerun the Tiny
   Tapeout submission action. Retain the pinned GDS and reports.

The first four experiments are ready to run. For each manifest, inspect IDs
before execution, then use the queue, which archives the large PNR workspace:

```sh
python3 experiments/runner.py plan experiments/next-5x4-baseline.json
python3 experiments/run_physical_queue.py experiments/next-5x4-baseline.json \
  > build/experiments/next-5x4-baseline.log 2>&1
python3 experiments/visualize.py
```

Repeat for the hold, clock, and 8×2 manifests. Run them in the order above
so the first complete gate result is reviewed before spending cycles on the
rest. Full KLayout DRC adds roughly nine minutes per GDS on this Mac based
on the independent reference audit. The macro and other architecture work
must receive new commit-pinned manifests once the actual RTL exists; do not
prelabel unbuilt designs as measured experiments.

## LVS scope

LibreLane already runs Netgen LVS between the extracted physical netlist and
the synthesized design. Prior 5×4 pass logs reported matching circuits. The
new runner checks the Netgen report and mismatch JSON explicitly before
marking PNR pass. This validates standard-cell connectivity for that routed
top; it does not validate a future custom bitcell/register-file layout. Any
custom cell needs its own extracted schematic-to-layout LVS, DRC, parasitic
extraction, timing characterization, and an integration check after routing.
