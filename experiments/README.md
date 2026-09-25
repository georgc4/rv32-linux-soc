# Reproducible design experiments

The first gate is `make test-linux-serial-boot`. It runs the actual boot ROM,
quad-serial NOR, four serial PSRAM models, Linux image, and UART. The test now
waits for the interactive BusyBox ash prompt, sends `/bin/acceptance_smoke`
as UART RX frames, and passes only after the separate RV32 executable checks
memory/arithmetic and prints `ASH_PROGRAM_OK`. The test paces each byte until Linux has
read the one-byte UART receive register. The simulator prints `ACCEPTANCE
ash_program=pass` with cycle and request counts; a panic, UART overrun, CPU
fault, timeout, or missing program output fails the gate. This is a deliberately
small first userspace program, not a comprehensive shell or classifier test.

The Verilator harness drives the same 10 ns testbench clock from C++ so each
edge reaches the unchanged bit/nibble-level serial chip models without the
simulator scheduling an `always #5` event. On this Mac, a 100 million cycle
serial boot window fell from 34.8 to 22.1 host seconds; its progress records,
including SPI command counts and CPU state, matched at 25 million cycle
intervals. Runtime threading was slower for this design.

Each design version is a **Git commit**. The experiment runner checks out the
exact commit as a detached worktree under ignored `build/experiments/runs/`,
records the resolved 40-character SHA and complete config, and refuses to
overwrite an existing stage result. Commit an RTL change before measuring it;
uncommitted RTL is never included. The runner also hashes the flow scripts and
acceptance harness and the manifest's flash image into the run ID. The
acceptance phase checks the image against that planned hash. To repeat a result after a tool-flow
change, regenerate the plan with the changed scripts. Failed and incomplete
runs remain visible.

```sh
python3 experiments/runner.py plan experiments/sweep.json
python3 experiments/runner.py run experiments/sweep.json --id <ID> --phase synth
python3 experiments/runner.py run experiments/sweep.json --id <ID> --phase pnr
python3 experiments/runner.py run experiments/sweep.json --id <ID> --phase acceptance \
  --flash-image build/linux/flash.bin
python3 experiments/visualize.py
```

An already completed local `make test-linux-serial-boot` or timed serial run can
be attached to the matching commit-pinned experiment without booting again:

```sh
python3 experiments/import_acceptance.py experiments/sweep.json --id <ID> \
  --log build/linux-ash-uartfix-run.log \
  --binary build/obj_linux_ash_uartfix/Vlinux_serial_boot_tb \
  --flash-image build/linux/flash.bin
```

The importer requires ordered userspace, ash, program, and clean-exit markers;
checks that every RTL and harness source matches the Git commit and predates
the simulator binary; verifies the full serial hex against the flash image;
then copies the log and binary into the run directory with hashes. Imported
results are labeled as such in JSON. It refuses a partial run or an existing
acceptance stage.

Open `build/experiments/pareto.html` in a browser. The dashboard is self
contained and offline. It shows source commits, sweep settings, stage status,
measured area, early setup slack, and Linux cycles. Change either axis to
inspect tradeoffs. A point joins the Pareto frontier only if the physical flow
produced GDS **and** the ash-program acceptance passed. Failed physical runs,
including the first 2026-09-24 baseline, remain visible but are excluded from
the candidate frontier. Routing and this gate do not replace final signoff.
That baseline reached about 85% core utilization at global placement;
OpenROAD raised its effective placement density to 97% and detailed placement
failed. A lower requested density cannot create more tile area. RTL area
reduction or a larger allocation is needed before density tuning is likely to
produce a routed point.
The baseline's old Linux result reached `/init` only;
it is labeled "boot marker only" and does not qualify.
The `8b2424d` serial run has now passed the ash-program gate at
13,010,943,367 cycles; the 50 ns and 35 ns standalone ABC screens reuse its
verified evidence because they have the same RTL, harness, and flash image.
Those points still do not qualify for the frontier because no routed GDS has
been produced. A concise committed [results snapshot](RESULTS.md) records the
measurements and their limits.

The matrix in [`sweep.json`](sweep.json) can list multiple Git revisions,
standalone Yosys ABC delay targets, LibreLane synthesis strategies, clock
periods, placement densities, and post-placement hold margins. The runner
takes their Cartesian product; `plan` shows the exact run IDs before anything
expensive is launched. `--all` runs every planned point for one phase. Keep
the baseline matrix small, then expand one axis at a time to expose causal
effects.

Standalone `abc_delay_ps` changes only the area-screening Yosys synthesis;
it does **not** feed that netlist into LibreLane. For comparable physical
mapping trials, change `synth_strategy` or `synth_abc_area_use_nf`, which are
applied inside the pinned LibreLane flow. `clock_period_ns` is a physical
timing target; the functional simulator and Linux device tree still model a
20 MHz clock. The physical run uses the pinned Tiny Tapeout 8×2 template and
LibreLane 3.0.14. The first failed placement used a different PDK revision
from the standalone area screen, so plotted areas retain their stage labels.
Early WNS is not routed signoff.

The runner requires the local Sky130A PDK for synthesis and the prepared
`build/sky130/venv` LibreLane runtime for PNR. The acceptance phase takes an
explicit flash-image path and records its SHA-256 plus the combined testbench
and C++ clock-driver SHA-256.
The result JSON, logs, mapped netlist, and PNR workspace live in each run
directory. When several PNR settings use the same RTL commit, flash image,
serial model, and harness, a passing acceptance result is reused with an
explicit link to its original log; the multi-billion-cycle boot runs once for
that functional design. `--timeout-hours` and `--max-cycles` bound long trials. No sweep
changes RTL, the memory topology, the ISA, or the shell image by itself.

## Area and kernel trials

[`tlb-sweep.json`](tlb-sweep.json) compares the committed 8-entry and 4-entry
direct-mapped TLBs with a 4-entry variant that shares a single SATP context.
The shared-context adapter invalidates cached entries when SATP changes; it
also omits the index bits from each stored VPN tag. All runs use the same
baseline flash image under `build/experiments/baseline-flash.bin` and its
adjacent `.json` manifest. The runner copies both files into each detached
worktree before serial simulation.

[`area-strategy-sweep.json`](area-strategy-sweep.json) tries LibreLane
`AREA 1` through `AREA 3` at the same 50 ns clock and 60% requested density;
`AREA 0` is in the TLB sweep. [`area-nf-sweep.json`](area-nf-sweep.json)
tests the ABC area `nf` switch. Standalone Yosys mapped area screens RTL
changes, while the LibreLane PNR metrics compare the synthesis strategies.
[`area-hold-zero.json`](area-hold-zero.json) isolates the physical hold-margin
setting after the 0.1 ns trial inserted thousands of hold buffers and failed
placement. A zero-margin result still needs routed STA and physical checks;
it is an experiment, not a signoff waiver.

[`mdu-share.json`](mdu-share.json) combines the division trial comparison and
subtraction, and shares the signed-result negation path. [`tlb-two.json`](tlb-two.json)
screens a 2-entry TLB. [`core-read-share.json`](core-read-share.json) adds a
single shared general-register read mux, using one extra core cycle to latch
the second operand. [`core-read-tlb4.json`](core-read-tlb4.json) repeats that
core architecture with 4 TLB entries. The matching
[`core-physical.json`](core-physical.json) and
[`core-tlb4-physical.json`](core-tlb4-physical.json) use `AREA 2` and zero
requested hold margin for physical comparisons.

The two kernel-image trials remove `CONFIG_DEBUG_PLIST` and then also
`CONFIG_DEBUG_VM_PGTABLE`. Generate the full config deterministically from
the tracked baseline and build each image with:

```sh
python3 linux/config-variant.py no-plist build/experiments/configs/no-plist.config
KERNEL_CONFIG=build/experiments/configs/no-plist.config make image-linux-flash
mkdir -p build/experiments/images/no-plist
cp build/linux/flash.bin build/linux/flash.bin.json build/linux/Image \
  build/kernel/.config build/experiments/images/no-plist/
```

Repeat with `no-plist-no-vm-pgtable` for the second image. `make
image-linux-flash` replaces `build/linux/flash.bin`, so copy each result
before starting the next build. Run the matching
[`kernel-no-plist.json`](kernel-no-plist.json) or
[`kernel-no-plist-no-vm-pgtable.json`](kernel-no-plist-no-vm-pgtable.json)
manifest against the pinned baseline RTL to isolate the image change. The
flash SHA-256 and occupied flash span are recorded in each adjacent manifest.
