# Feasibility and risk register — updated 2026-09-25

| Risk | Why it matters | Next evidence |
|---|---|---|
| SKY26d 16-tile physical fit | The initial 8×2 design and later 4-entry shared-read version failed detailed placement. The latter routed on 5×4 at 247,744 µm² with independent full KLayout DRC, Magic DRC, and Netgen LVS clear. A 16-tile fit is still unproven. | Run the [next 8×2 screens](../experiments/NEXT-SESSION.md); prioritize RTL area savings if placement still fails. |
| Tile budget under USD 2,000 | Digital tile pricing/available shapes for selected shuttle not confirmed; purchase portal may change. | Live offer and configured project quote, then route with margin. |
| 32 MiB memory pressure | The built Image occupies about 5.14 MiB at runtime before initramfs unpacking, page tables, processes, and firmware. | Boot the actual image; capture free memory and peak use. |
| Serial-memory latency | Quad-lane serial transfers reached interactive BusyBox ash and executed an RV32 smoke program. The 4-entry shared-read variant took 17.13 billion cycles on the smaller kernel image; no cache is the area-first baseline. | Measure longer shell and application workloads, serial traffic, and silicon clock/IO limits. |
| Shared five-device bus | Mode, reset, DQ2/DQ3 behavior and high-Z on deselect may differ; five loads plus wiring may exceed 4 mA pad drive or timing. | Read both exact datasheets and bench-test one of each, then all five with contention and edge checks. |
| FPGA electrical supply | Board revision, GPIO bank voltage and 3.3 V regulator current are unknown. | Delivered-board schematic and measured/quoted regulator capacity, power budget, constraints. |
| Breadboard signal integrity | Four PSRAM plus flash at high SCK adds capacitance and long stubs. | Start at low SCK, scope waveforms, move to perfboard/PCB as needed. |
| Decoupling absent | Kit says “104 pF”; cannot assume 100 nF. | Obtain five local 100 nF ceramics plus bulk capacitors, verify package/fit. |
| FPGA tool flow | Sipeed documents Gowin IDE and OpenFPGALoader; open synthesis/place-route support for this exact device/board is not established. | Test supported open tools with a board revision; use Gowin only if needed for bitstream. |
| Flash updates and recovery | A bad image can brick a boot path; external programming can contend with driven ASIC pins. The owner chose an accessible external programmer over a larger ROM. | Demonstrate an assembled-board reflash procedure with SoC pins isolated/deasserted, then erase/program/verify. |

The initial 8×2 configuration does **not** legalize. Later 5×4 results and the
next experiment sequence are recorded in [the results snapshot](../experiments/RESULTS.md)
and [next-session plan](../experiments/NEXT-SESSION.md). The current 5×4 GDS
evidence does not establish 8×2 fit or routed multi-corner timing signoff.
