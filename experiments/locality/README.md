# 5×4 locality and timing campaign

This campaign follows the 2026-09-27 physical review. The thirteen original
commit-pinned experiments now use `run_parallel_campaign.py`, with four Mac PNR
slots and two PS4 PNR slots. Trials 15–16 occupy Mac slots through their existing
workers; trial 14 occupies a PS4 slot. Trials 07, 08, 11 and 12 are dispatched to
PS4, and the other original trials to the Mac. Trial 13 waits for its independent
PS4 Linux acceptance result. The original one-line-cache GDS is the control; its
final timing audit is retained beside the unchanged historical result.

The dispatcher reserves Mac slots during staging, before containers appear, and
requires 6 GiB VM memory available for a new Mac job or 3.5 GiB available for a new
PS4 job. Disk guards remain enabled. Existing hardening processes survived the
scheduler migration. Adopted Mac runs explicitly report an unobserved process
exit code and use TT's final success markers plus the normal physical/timing
audits; their original logs and checkpoints remain intact. Live dispatch state
is in `build/experiments/locality-campaign/status.json` and `parallel.log`.

| Trials | Controlled change |
|---|---|
| 01 | Timing-driven placement, original corner setup |
| 02 | Timing-driven placement with typical/slow/fast implementation corners |
| 03 | Same implementation corners without timing-driven placement |
| 04–06 | Timer/CSR, operand, and cache clusters independently, against 01 |
| 07 | All three cluster families, against 01 |
| 08 | Combined clusters plus implementation corners, against 02 |
| 09 | DELAY 2 mapping, against 02's AREA 2 |
| 10 | Post-global-route timing repair, against 02 |
| 11–12 | One-line/eight-TLB and no-cache/eight-TLB architecture candidates |
| 13 | Register legality during READ_RS2; unchanged instruction cycle count |
| 14 | PS4 worker: combined clusters without timing-driven placement |
| 15–16 | Parallel Mac workers: timer/CSR and operand clusters with multicorner timing |

Trials 01–10 use `7ebde5c`, 5×4, 50 ns, the accepted smaller kernel, and 0.05 ns post-CTS hold margin. Trials 11–12 reuse their exact commit/image Linux acceptance. Trial 13 is isolated on `codex/locality-registered-decode` at `f91a5e1`; directed core, fault, privilege, supervisor, production serial boot, bad-image tests and lint pass. A simulation-only assertion checks staged legality against live decode in every EXEC cycle. This variant must pass a fresh full true-serial Linux run before PNR. Physical improvements remain unmeasured until completed runs report them.

The original standalone sequential scheduler uses a three-container admission
threshold; it has been replaced for the main campaign by the dispatcher above.
Detailed routing and full DRC have no wall-clock timeout. Each new router uses
four threads and corner STA uses two workers. The session retains its frozen run
list, source snapshot and live resource observations. A lock prevents duplicate
dispatchers, and changed provenance rejects future launches. Completed stages
are compressed only after results are recorded, retaining the latest ODB.

```sh
python3 experiments/run_locality_campaign.py --plan
python3 experiments/run_locality_campaign.py --resources
python3 -u experiments/run_locality_campaign.py
```

`status.json` and `campaign.log` in the session directory are the live status. The dashboard now separates physical/functional evidence from final timing/electrical qualification. Missing final timing cannot qualify; slow corners cannot be overwritten by typical corners. Final reports are audited even if LibreLane returns a deferred timing failure. New full-GDS runs still undergo independent KLayout, Magic, antenna and Netgen checks.

Trials 15 and 16 run in additional workers alongside the original sequential
queue. Their manifests are `experiments/locality-worker-15.json` and
`experiments/locality-worker-16.json`; each has its own
`build/experiments/locality-worker-N/` session, logs, lock, and source snapshot.
Launch with `--campaign` and `--session` to select these independent queues.
Admission checks count PNR containers across the whole VM. The initial three
jobs leave room for twelve routing threads in total; serial stages naturally
use fewer cores. Each scheduler has its own caffeinate process.

Placement uses the pinned LibreLane 3.0.14 runtime. A staged-local plugin replaces only global placement and inserts connectivity grouping before `global_placement`. It does not modify the installed flow or any already-running container. Each group contains 2–24 synthesized instances, excludes physical-only cells, and has disjoint membership. Empty matches fail the experiment. The generated `placement-clusters.tsv` records every group. Profiles, plugin and Tcl contents contribute to the experiment flow hash.

## External memory constraints

The owner confirmed four **ESP-PSRAM64H / Adafruit 4677** (`1528-4677-ND`) and a **W25Q128JVSIQ-TR** (`256-W25Q128JVSIQTRCT-ND`). These match the RTL/model comments and saved datasheets under `build/references/`.

The saved PSRAM datasheet lists CLK-to-output 2–6 ns, data setup/hold 2/2 ns, CE setup 2.5 ns, CE hold 20 ns, CE-high minimum 50 ns, CE-low maximum 8 µs, input capacitance up to 6 pF and output capacitance up to 8 pF. The saved Winbond Rev F lists clock-low-to-output maximum 6 ns, output hold minimum 1.5 ns, data setup/hold 1/2 ns, CS setup/hold 3 ns, read deselect minimum 10 ns and program/erase deselect minimum 50 ns. See [PSRAM datasheet](https://cdn-shop.adafruit.com/product-files/4677/4677_esp-psram64_esp-psram64h_datasheet_en.pdf) and [Winbond Rev F](https://www.winbond.com/resource-files/w25q128jv%20revf%2003272018%20plus.pdf).

The first matrix retains the fallback I/O constraints to isolate internal placement changes and labels them provisional. Device limits are not the entire macro-boundary budget: shuttle output/input pad and mux latency, carrier traces, five-device loading and return-clock phase must be included. Do not apply external 30 pF bus loading directly to a core-standard-cell macro output or invent board flight times. Reset deassertion and the asynchronous UART synchronizer also need separate treatment. No candidate is represented as board/silicon signed off by passing this matrix.

Next selection: compare final worst-corner slack/TNS, electrical violations, area, hold and repair buffers, wire length, routing congestion and full physical checks. Combine only measured winners. Assess the existing 8×2 jumper runs before scheduling additional 8×2 trials; no further blind density sweep is part of this batch.
# PS4 worker and resource recovery (2026-09-27)

The additional `14-ps4-clusters-only.json` trial runs independently on the PS4,
using combined placement clusters with timing-driven placement disabled. It is
not in the Mac's sequential queue. The x86 LibreLane 3.0.14 image was exported
from the iMac into `/srv/ps4-data/rv32-locality/rootfs` and runs in a chroot;
the PS4 does not have Docker installed. Its OpenROAD revision and timing-library
SHA-256 were checked against the Mac. Source, configuration, and checkpoint paths
inside the chroot match their Mac paths. Platform and image identity are retained
in the result because architecture-dependent tool differences remain possible.

`build/experiments/locality-campaign/ps4-worker.json` records the remote PID and
collector status. `experiments/collect_ps4_worker.py` waits for completion, copies
the reports and checkpoints back, applies the usual timing and physical audits,
and updates the dashboard. SSH goes through `imac` to `ps4`. The worker survives
SSH disconnects. Its log is `/srv/ps4-data/rv32-locality/rootfs/worker.log` on PS4.

The Mac has 18 GiB physical RAM, so its VM retains 16 GiB and all 12 cores.
Approximately 15 GiB was reclaimed from rebuildable `.o` files in the inactive
`ps4-infer-work` volume and dangling image layers; source and experiment evidence
were preserved. Both the Mac VM and PS4 now have 8 GiB of disk swap, with
swappiness 10. Swap activation is for the current boot. Mac VM jobs and the PS4
worker run at nice -10. Caffeinate keeps the Mac awake while its scheduler lives.

PS4's persistent btop installation is `/srv/ps4-data/tools/btop`, with a command
link at `/usr/local/bin/btop`. `/srv/ps4-data/tools/start-btop-display.sh` launches
it on tty1, using `btop-display.conf` and a 100 ms refresh interval.

The PS4 also runs full Linux acceptance for trial 13's registered-decode RTL,
alongside trial 14's physical flow. Verilator builds with four compiler jobs;
the simulation uses the unchanged acceptance harness and serial memory model,
the pinned flash image, a 40-billion-cycle ceiling, and a 48-hour wall limit.
Every transferred input was checked by SHA-256. Its runtime and logs are separate
from PNR. `ps4-acceptance.json` records its status, and
`experiments/collect_ps4_acceptance.py` collects the logs and merges the result
under the existing per-run lock. A separately completed Mac acceptance result is
preserved rather than overwritten. The C++ build uses the image's GCC 14.3
wrapper, plus the iMac's GNU make binary through the image's glibc loader.
