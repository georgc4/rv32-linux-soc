# Feasibility and risk register — 2026-09-23

| Risk | Why it matters | Next evidence |
|---|---|---|
| SKY26d schedule/area vs original Linux CPU | User has chosen SKY26d as the submission target. Closing date shown as 2026-11-30, about 68 days from this check; CPU, MMU, controllers and software do not yet exist. A full Linux SoC tapeout on this run is **high risk**. | Meet the dated evidence gates in `schedule.md`; a missed Linux readiness gate must be reported and explicitly resolved before a different submission scope is chosen. |
| Tile budget under USD 2,000 | Digital tile pricing/available shapes for selected shuttle not confirmed; purchase portal may change. | Live offer and configured project quote, then route with margin. |
| 32 MiB memory pressure | Kernel, decompression, initramfs, firmware and page tables compete for same RAM. | Reproducible minimal RV32 image, peak-memory log, free headroom. |
| Serial-memory latency | At illustrative 10 MHz SCK, a 64-bit single-lane command/address/data exchange takes ≥6.4 µs before controller overhead; page walks and instruction fetch could multiply this. Quad bursts and small caches may be necessary. This is a lower-bound illustration, not a measured rate. | Cycle-accurate controller plus trace-driven workload at conservative timing. |
| Shared five-device bus | Mode, reset, DQ2/DQ3 behavior and high-Z on deselect may differ; five loads plus wiring may exceed 4 mA pad drive or timing. | Read both exact datasheets and bench-test one of each, then all five with contention and edge checks. |
| FPGA electrical supply | Board revision, GPIO bank voltage and 3.3 V regulator current are unknown. | Delivered-board schematic and measured/quoted regulator capacity, power budget, constraints. |
| Breadboard signal integrity | Four PSRAM plus flash at high SCK adds capacitance and long stubs. | Start at low SCK, scope waveforms, move to perfboard/PCB as needed. |
| Decoupling absent | Kit says “104 pF”; cannot assume 100 nF. | Obtain five local 100 nF ceramics plus bulk capacitors, verify package/fit. |
| FPGA tool flow | Sipeed documents Gowin IDE and OpenFPGALoader; open synthesis/place-route support for this exact device/board is not established. | Test supported open tools with a board revision; use Gowin only if needed for bitstream. |
| Flash updates and recovery | A bad image can brick a boot path; external programming can contend with driven ASIC pins. | UART ROM recovery protocol and erase/program/verify test. |

The bus Yosys run uses generic cells only. On this host it reported **349 generic cells**, mostly decode combinational logic, for `physical_bus` alone. This cannot be converted to Sky130 tile count or timing, and excludes every costly CPU/memory block. After the CPU skeleton exists, map with the selected shuttle flow and leave routing margin.
