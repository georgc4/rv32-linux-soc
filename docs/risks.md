# Feasibility and risk register — 2026-09-24

| Risk | Why it matters | Next evidence |
|---|---|---|
| SKY26d 16-tile physical fit | The full serial model reached Linux `/init`. The first 8×2 TT/LibreLane flow mapped 252,455 µm² of cells into a 302,420 µm² core, reached 85.3% utilization after global placement, inserted 3,578 repair buffers, and failed detailed placement on 367 instances. No routed result exists. | Review [physical baseline](../tt/physical-baseline.md), choose one area experiment, and rerun the same flow and Linux workload. |
| Tile budget under USD 2,000 | Digital tile pricing/available shapes for selected shuttle not confirmed; purchase portal may change. | Live offer and configured project quote, then route with margin. |
| 32 MiB memory pressure | The built Image occupies about 5.14 MiB at runtime before initramfs unpacking, page tables, processes, and firmware. | Boot the actual image; capture free memory and peak use. |
| Serial-memory latency | Quad-lane serial transfers enabled a full-image Linux `/init` run, but the interactive shell and digit workload have not been measured. No cache is the area-first baseline. | Continue the real-serial run to prompt, paced RX command and on-chip digit output; measure cycles and serial traffic. |
| Shared five-device bus | Mode, reset, DQ2/DQ3 behavior and high-Z on deselect may differ; five loads plus wiring may exceed 4 mA pad drive or timing. | Read both exact datasheets and bench-test one of each, then all five with contention and edge checks. |
| FPGA electrical supply | Board revision, GPIO bank voltage and 3.3 V regulator current are unknown. | Delivered-board schematic and measured/quoted regulator capacity, power budget, constraints. |
| Breadboard signal integrity | Four PSRAM plus flash at high SCK adds capacitance and long stubs. | Start at low SCK, scope waveforms, move to perfboard/PCB as needed. |
| Decoupling absent | Kit says “104 pF”; cannot assume 100 nF. | Obtain five local 100 nF ceramics plus bulk capacitors, verify package/fit. |
| FPGA tool flow | Sipeed documents Gowin IDE and OpenFPGALoader; open synthesis/place-route support for this exact device/board is not established. | Test supported open tools with a board revision; use Gowin only if needed for bitstream. |
| Flash updates and recovery | A bad image can brick a boot path; external programming can contend with driven ASIC pins. The owner chose an accessible external programmer over a larger ROM. | Demonstrate an assembled-board reflash procedure with SoC pins isolated/deasserted, then erase/program/verify. |

The first mapped and placed results are now recorded in the physical baseline. The initial 8×2 configuration does **not** legalize, so neither generic gates nor the partial placement establish tile fit or timing. The owner will review measured area options before architectural changes.
