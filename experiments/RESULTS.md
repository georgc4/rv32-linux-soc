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
| `8b2424d`, CSR MIP/SIP fix, default ABC | 22,129 | 225,060.9 µm² | Not routed | Full serial run in progress |
| `8b2424d`, ABC 50 ns | 22,129 | 225,060.9 µm² | Screening only | Same functional RTL as default |
| `8b2424d`, ABC 35 ns | 22,129 | 225,060.9 µm² | Screening only | Same functional RTL as default |

The earlier LibreLane placement reached 257,959 µm² of placed instance area,
85.3% core utilization, and -18.55 ns setup WNS before detailed placement
failed. That physical run used a different PDK revision from the standalone
mapping screen, so its area is not directly comparable to the mapped area
column. Requested density of 60% was raised to 97% by the placer because the
design nearly fills the core. No point yet qualifies for the routed-and-ash
Pareto frontier.

The default, 50 ns, and 35 ns standalone ABC runs produce identical mapped
netlists by cell count and area. This particular constraint sweep therefore
shows no measured area tradeoff; it does not change the RTL or the LibreLane
physical mapping strategy. The next design trial should be motivated by the
serial boot measurements in [the boot performance note](../docs/boot-performance-baseline.md).
