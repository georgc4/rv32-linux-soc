# Feasibility and risk register — 2026-09-23

| Risk | Why it matters | Next evidence |
|---|---|---|
| SKY26d schedule/area vs original Linux CPU | User has chosen SKY26d as the submission target. Logical RTL, directed tests, RV32 Linux image, SBI loader, and NOR package exist; Linux boot, mapped area, and physical timing are unverified. | Run the full kernel, then map the RTL in the physical flow. |
| Tile budget under USD 2,000 | Digital tile pricing/available shapes for selected shuttle not confirmed; purchase portal may change. | Live offer and configured project quote, then route with margin. |
| 32 MiB memory pressure | The built Image occupies about 5.14 MiB at runtime before initramfs unpacking, page tables, processes, and firmware. | Boot the actual image; capture free memory and peak use. |
| Serial-memory latency | At illustrative 10 MHz SCK, a 64-bit single-lane command/address/data exchange takes ≥6.4 µs before controller overhead; page walks and instruction fetch could multiply this. Quad bursts and small caches may be necessary. This is a lower-bound illustration, not a measured rate. | Cycle-accurate controller plus trace-driven workload at conservative timing. |
| Shared five-device bus | Mode, reset, DQ2/DQ3 behavior and high-Z on deselect may differ; five loads plus wiring may exceed 4 mA pad drive or timing. | Read both exact datasheets and bench-test one of each, then all five with contention and edge checks. |
| FPGA electrical supply | Board revision, GPIO bank voltage and 3.3 V regulator current are unknown. | Delivered-board schematic and measured/quoted regulator capacity, power budget, constraints. |
| Breadboard signal integrity | Four PSRAM plus flash at high SCK adds capacitance and long stubs. | Start at low SCK, scope waveforms, move to perfboard/PCB as needed. |
| Decoupling absent | Kit says “104 pF”; cannot assume 100 nF. | Obtain five local 100 nF ceramics plus bulk capacitors, verify package/fit. |
| FPGA tool flow | Sipeed documents Gowin IDE and OpenFPGALoader; open synthesis/place-route support for this exact device/board is not established. | Test supported open tools with a board revision; use Gowin only if needed for bitstream. |
| Flash updates and recovery | A bad image can brick a boot path; external programming can contend with driven ASIC pins. | UART ROM recovery protocol and erase/program/verify test. |

The integrated `synth-soc` run reports **21,616 generic cells** with the PLIC. This cannot be converted to Sky130 tile count or timing. Map and route with the selected shuttle flow and leave routing margin.
