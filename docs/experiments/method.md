# Commit-pinned experiments and Pareto decisions

**Sources:** [`runner.py`](../../experiments/runner.py), [`run_physical_queue.py`](../../experiments/run_physical_queue.py), [`visualize.py`](../../experiments/visualize.py), JSON manifests in [`experiments/`](../../experiments/README.md).

The purpose of the framework is to compare architecture and physical knobs without confusing a changed source tree, image, PDK, or signoff scope. A manifest names Git revisions and a Cartesian product of settings: ABC delay, LibreLane synthesis strategy, ABC `nf`, clock period, placement density, post-placement/global-route hold margins, antenna-repair mode/iterations, and tile shape. `runner.py plan` resolves each revision to an immutable commit and hashes the canonical configuration, relevant flow scripts/test harness/model, PDK source identity and Liberty SHA, and optional flash image SHA. The resulting run ID is the first 12 commit characters plus 12 hash characters. Runs live under ignored `build/experiments/runs/<id>/` and use a detached worktree at the commit; result JSON is written atomically.

## Stages and qualification

`--phase synth` maps SKY130 standard cells and records cell count/area. `--phase pnr` stages a Tiny Tapeout project, runs full hardening, collects area/utilization/timing, and audits final GDS. `--phase acceptance` builds a Verilator harness around that commit's RTL and runs the true-serial Linux image to ash plus `/bin/acceptance_smoke`. `--phase reuse-acceptance` references a prior proven log for the **same RTL commit and image SHA**, recording provenance. The cache also checks the harness and serial-model hashes for directly reused prior results. Image-only experiments need a fresh acceptance run for each image. RTL changes need a fresh functional gate even when standalone unit tests pass.

PNR status `pass` requires GDS and the runner's explicit KLayout, Magic, Netgen, and antenna checks. The dashboard's green Pareto points require both PNR pass and acceptance pass. A run that stops at global route, produces a GDS with an antenna violation, or only reaches a Linux prompt is not qualified. `visualize.py` builds an interactive scatter/ledger at `build/experiments/pareto.html`; the frontier is recomputed for selected axes among qualified rows. A mapped-area point may still be plotted for screening, but it is not promoted to the frontier.

## Reproduce or extend a trial

```sh
python3 experiments/runner.py plan experiments/next-state-5x4.json
python3 experiments/runner.py run experiments/next-state-5x4.json \
  --id <planned-run-id> --phase acceptance \
  --flash-image build/experiments/images/no-plist-no-vm-pgtable/flash.bin \
  --max-cycles 25000000000 --timeout-hours 8
python3 experiments/run_physical_queue.py experiments/next-state-5x4.json
make experiment-chart
```

The physical queue executes runs sequentially within its lane and archives bulky PNR workspaces; the current area-round scheduler runs one acceptance lane and one physical lane concurrently, with free-disk guards. A run should not be edited in place: commit an RTL change, add a new manifest revision/setting, and let the identity change. The physical lane can test the same commit while its Linux gate runs; a physical pass alone does not imply Linux passed. Check the status JSON and per-run result before reporting a result. The [results snapshot](../../experiments/RESULTS.md) is narrative and dated; per-run JSON/logs are the precise evidence.

## Measurement hygiene

Record the exact metric stage: Yosys mapped cell area, LibreLane synthesis area, global-placement instance area, routed instance area, and outer die/core area are different quantities. Compare like with like under the same image and flow where possible. Setup WNS must be identified by corner and stage; 50 ns input constraint is not achieved 20 MHz without complete IO constraints and routed multi-corner STA. Check whether the run inserted buffers or antenna fixes, because a small mapping win can grow after repair. For boot time, compare cycle markers and request/trap counts under identical images; host wall time is a simulator performance metric, not chip boot time. A design choice should be made from area, qualified physical status, acceptance cycles, frequency margin, and remaining risks together.
