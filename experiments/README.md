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
explicit flash-image path and records its SHA-256 plus the testbench SHA-256.
The result JSON, logs, mapped netlist, and PNR workspace live in each run
directory. When several PNR settings use the same RTL commit, flash image,
serial model, and harness, a passing acceptance result is reused with an
explicit link to its original log; the multi-billion-cycle boot runs once for
that functional design. `--timeout-hours` and `--max-cycles` bound long trials. No sweep
changes RTL, the memory topology, the ISA, or the shell image by itself.
