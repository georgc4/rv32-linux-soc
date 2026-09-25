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

## Area campaign, 2026-09-25

Each RTL row below is a separate Git commit measured by the same standalone
Yosys/SKY130 screen. The new serial runs are still active; a mapped-area
improvement by itself is not a qualified Pareto result.

| RTL revision | Change | Mapped cells | Mapped area (µm²) | Versus `8b2424d` |
|---|---|---:|---:|---:|
| `8b2424d` | 16-entry TLB baseline | 22,129 | 225,060.9 | — |
| `e55522c` | 8-entry TLB | 19,960 | 199,111.0 | −11.5% |
| `1edce9c` | 4-entry TLB | 18,692 | 186,462.6 | −17.2% |
| `b32aa91` | 4-entry TLB, shared SATP context/tag bits | 18,419 | 180,528.1 | −19.8% |
| `cefb9b0` | Shared MDU division logic | 18,121 | 180,176.6 | −19.9% |
| `ad9aadc` | 2-entry TLB with shared context and MDU | 18,030 | 176,704.5 | −21.5% |
| `e360da0` | One core register-file read port, 2-entry TLB | 17,690 | 171,635.9 | −23.7% |
| `b3fdd5a` | One core register-file read port, 4-entry TLB | 18,077 | 175,393.2 | −22.1% |

The 16-to-4-entry shared-context TLB change accounts for 44,532.7 µm² of
total saving; its adapter module falls from 63,360.8 to 19,426.1 µm².
The shared core read port saves 5,068.6 µm² relative to the same 2-entry
TLB architecture. It adds one operand-read cycle per instruction; the focused
core test grew from 795 to 867 cycles for 85 retired instructions. Full boot
cycle and shell results are being measured through unchanged true serial
NOR/PSRAM and UART paths.

At the 4-entry shared-context commit, LibreLane's physical synthesis mapped
`AREA 0`, `AREA 1`, `AREA 2`, `AREA 3`, and `AREA 0` plus ABC `nf` to
210,398.0, 209,970.1, 207,923.2, 265,474.6, and 211,695.5 µm²,
respectively. `AREA 2` is the best area strategy in this small knob screen;
its 1.2% improvement over `AREA 0` is much smaller than the TLB change.
`AREA 3` fails global placement at 100.72% utilization.

With the original 0.1 ns hold margin, `AREA 0`, `AREA 1`, `AREA 2`, and the
ABC `nf` trial fail post-CTS detailed placement after hold repair. For the
4-entry shared-context `AREA 0` run, lowering the requested hold margin to
zero reduces hold endpoints from 2,550 to 3. That run completes global
routing but fails during antenna repair when placement cannot fit the
inserted jumpers. The smaller 2-entry/shared-read-core physical run also
reaches antenna repair and fails detailed placement there; its global route
reports congestion. The corresponding 4-entry/shared-read-core run fails at
the same antenna-repair placement step. No new area campaign point has routed
GDS yet. The provisional 8×2 floorplan remains too congested for these
variants despite successful synthesis and pre-antenna global routing.

The kernel-only images retain baseline RTL. Disabling `CONFIG_DEBUG_PLIST`
reduces packed kernel bytes from 4,864,556 to 4,856,268; also disabling
`CONFIG_DEBUG_VM_PGTABLE` reduces them to 4,855,980. Their serial boot
trials are active with separate flash hashes and effective kernel configs.
Rebuilding the unmodified baseline config on 2026-09-25 reproduced flash
SHA-256 `d7ca41e95c47af4ae02fe69c3fd0f56c9b33e41545bc2a0b8a95a23cac485b0c`
exactly, matching the image used for the earlier ash-program pass.
