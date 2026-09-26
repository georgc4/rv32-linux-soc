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
Yosys/SKY130 screen. A mapped-area improvement by itself is not a qualified
Pareto result.

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
core test grew from 795 to 867 cycles for 85 retired instructions. The full
boot trials preserve the true serial NOR/PSRAM and UART paths.

All first-wave baseline-image serial trials have finished. The 8-entry TLB
passed ash and `/bin/acceptance_smoke` in 17,221,284,460 cycles, versus
13,010,943,367 for the 16-entry baseline. The 4-entry TLB, its shared-context
version, and the MDU-sharing version reached the ash prompt at exactly
19,892,897,550 cycles and began the acceptance command, but hit the
20-billion-cycle cap before its output. Those are timeouts after a working
shell, not observed functional failures. The 4-entry TLB plus shared core
read port reached `/init` at 19,909,867,269 cycles, then also hit the cap.
Both 2-entry variants reached the kernel's PLIC initialization but not
`/init` within 20 billion cycles. A focused follow-up uses the already
validated smaller kernel image to qualify the 4-entry candidates with a
higher cap.

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
GDS yet in those earlier 8×2 trials. The provisional 8×2 floorplan remains
too congested for these variants despite successful synthesis and pre-antenna
global routing. The later 5×4 results below supersede the no-GDS status.

The public `main` submission-package run at commit `32e9ce3` independently
reproduced the baseline physical failure in Tiny Tapeout's GitHub GDS action:
`OpenROAD.RepairDesignPostGPL` ended with `[DPL-0036] Detailed placement
failed`. Docs and fast checks passed, but no GDS artifact was produced. The
action run is `https://github.com/georgc4/rv32-linux-soc/actions/runs/36179089201`.
The area-optimized draft branch's official GDS action also failed detailed
placement, but later in the flow: post-CTS hold repair found 2,652 violating
endpoints and inserted 2,810 hold buffers before legalization failed. Its
run is `https://github.com/georgc4/rv32-linux-soc/actions/runs/36178436940`.

The kernel-only images retain baseline RTL. Disabling `CONFIG_DEBUG_PLIST`
reduces packed kernel bytes from 4,864,556 to 4,856,268; also disabling
`CONFIG_DEBUG_VM_PGTABLE` reduces them to 4,855,980. Both variants passed
the full true-serial BusyBox ash plus `/bin/acceptance_smoke` gate. The first
passed in 11,196,604,401 cycles (flash SHA-256
`5ecc0c79c514643baaa4d3445453ece19de346acbd4c387a8a2fe24f11266f13`);
the second passed in 11,155,721,103 cycles (flash SHA-256
`590ed63886833648537907532aac191c210e3eb4e36e300c99c4de4707e6f615`).
These are 13.9% and 14.3% below the earlier baseline gate, respectively.
The measured image and simulation result is sound; attributing all cycle
savings to those two config bits requires further image comparison.
Rebuilding the unmodified baseline config on 2026-09-25 reproduced flash
SHA-256 `d7ca41e95c47af4ae02fe69c3fd0f56c9b33e41545bc2a0b8a95a23cac485b0c`
exactly, matching the image used for the earlier ash-program pass.

## 5×4 physical sweep, 2026-09-25/26

LibreLane 3.0.14, SKY130A PDK `8afc8346`, `AREA 2`, a **50 ns** clock target,
and zero requested hold margin were used for these 5×4 runs. The physical
core area is 430,538 µm². Instance area is from the routed RC extraction
stage, not the floorplan area. All passing runs produced GDS and passed
LibreLane's LVS check. The flow warned that a KLayout DRC error count was not
reported; DRC must be checked independently before signoff.

| RTL variant | Physical flow | Routed instance area (µm²) | Utilization | Separate true-serial ash/program gate |
|---|---|---:|---:|---|
| 16-entry TLB baseline | Failed post-global-placement detailed placement | 258,560 at global placement | 60.1% | Pass, baseline image, 13,010,943,367 cycles |
| 8-entry TLB | GDS produced; flow failed hold check | 272,460 | 63.3% | Pass, baseline image, 17,221,284,460 cycles |
| 4-entry TLB | Pass | 256,845 | 59.7% | Reached ash, acceptance command timed out at 20 billion cycles on baseline image |
| 4-entry TLB, shared context | Pass | 251,993 | 58.5% | Pass, smaller kernel, 16,823,568,756 cycles |
| 4-entry TLB, shared context and MDU | Pass | 252,096 | 58.6% | Reached ash, acceptance command timed out at 20 billion cycles on baseline image |
| 2-entry TLB, shared context and MDU | Flow exit 0, but one antenna pin/net violation | 246,819 | 57.3% | Did not reach `/init` by 20 billion cycles on baseline image |
| 4-entry TLB, shared core register read port | Pass | **247,744** | 57.5% | Pass, smaller kernel, 17,129,216,271 cycles |
| 2-entry TLB, shared core register read port | Running | — | — | Did not reach `/init` by 20 billion cycles on baseline image |

The 4-entry shared-read-core design saves **4,249 µm²** of routed instance area
versus the 4-entry shared-context design, while the smaller-kernel full gate
uses **305,647,515** more cycles. Both functional passes are on the same RTL
commits as their physical runs, but their smaller kernel image differs from
the physical sweep's baseline image; the current dashboard therefore does
not mark those specific experiment IDs as combined, same-image Pareto points.

An independent DRC audit of the 4-entry shared-read-core final GDS
(`b3fdd5a8fa31-a1822f8ccbbe`) found **zero violations** in Magic and **zero
items** in KLayout's `sky130A_mr.drc` report with FEOL, BEOL, and off-grid
checks enabled. KLayout completed in 554 seconds. The checked GDS SHA-256 is
`4af60c02eed459131988c642ede762b0c8420ecc9e5fd492bdeda921815e4239`;
the rule deck SHA-256 is
`caf4a6b08cb12f78d6bb2d120737424c786b3bae8d6489234b9b269e91107bfc`.
The local report and logs are in ignored
`build/experiments/drc-4tlb-shared-read/`. Seal-ring and floating-metal
options were not enabled for this user macro. This DRC result applies to that
one GDS; other variants still need their own checks.

The **50 ns (20 MHz)** physical target matches the project's intended
demoboard operating clock; the board clock is user-configurable. A 20 ns
constraint would be needed only for a separate 50 MHz goal. The reported
register-to-register setup slack at the early timing stage is about 24–26 ns
for the passing variants. Timing signoff at 20 MHz still needs dedicated
reset, UART, SPI, and external-memory I/O constraints and review of routed
multi-corner setup and hold reports; these runs used zero extra hold-repair
margin and the flow's fallback SDC.
