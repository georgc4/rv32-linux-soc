# Experiment results snapshot

These are measured screening results, not final signoff. The authoritative
per-run JSON, logs, netlists, and generated interactive dashboard are under
ignored `build/experiments/` in the local workspace. Recreate the dashboard
with `make experiment-chart`.

| RTL revision / trial | Mapped cells | Mapped cell area | Physical result | Serial Linux gate |
|---|---:|---:|---|---|
| `847766b`, first LibreLane 8×2 run | — | — | Detailed placement failed | Not run at this revision |
| `19cb40a`, first full-image baseline | 22,088 | 224,972.0 µm² | Not routed | Reached userspace marker; IRQ loop before ash |
| `410115b`, UART THRE fix | 22,122 | 225,065.9 µm² | Not rerouted | Same IRQ loop; CSR issue diagnosed |
| `8b2424d`, CSR MIP/SIP fix, default ABC | 22,129 | 225,060.9 µm² | Not routed | Ash + program pass at 13,010,943,367 cycles |
| `8b2424d`, ABC 50 ns | 22,129 | 225,060.9 µm² | Screening only | Reuses the verified default-ABC serial pass |
| `8b2424d`, ABC 35 ns | 22,129 | 225,060.9 µm² | Screening only | Reuses the verified default-ABC serial pass |

The earlier LibreLane placement reached 257,959 µm² of placed instance area,
85.3% core utilization, and -18.55 ns setup WNS before detailed placement
failed. That physical run used a different PDK revision from the standalone
mapping screen, so its area is not directly comparable to the mapped area
column. Requested density of 60% was raised to 97% by the placer because the
design nearly fills the core. No point yet qualifies for the routed-and-ash
Pareto frontier.

The default, 50 ns, and 35 ns standalone ABC runs produce the same mapped
cell count and area. This particular constraint sweep therefore
shows no measured area tradeoff; it does not change the RTL or the LibreLane
physical mapping strategy. The next design trial should be motivated by the
serial boot measurements in [the boot performance note](../docs/boot-performance-baseline.md).

The full gate used the unchanged Linux 6.12.111 / BusyBox 1.37.0 image with
flash SHA-256 `d7ca41e95c47af4ae02fe69c3fd0f56c9b33e41545bc2a0b8a95a23cac485b0c`.
The simulator carried true quad-serial transfers to four PSRAM chips and one
NOR chip, received 22 command bytes through the UART, printed
`ASH_PROGRAM_OK`, and exited with code 0. Experiment
`8b2424d1772d-4b86b7212906` stores the verified local log and binary hashes.
