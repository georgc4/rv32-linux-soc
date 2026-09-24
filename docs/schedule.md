# SKY26d evidence gates

Target: TTSKY26d, currently listed to close **2026-11-30**. Dates below are planning gates, not promises. A full Linux boot on original fabricated silicon cannot be proven until chips return; pre-tapeout evidence must include simulation and FPGA behavior plus physical signoff. Budget remains ≤approximately USD 2,000 for tapeout. Recheck live shuttle date and offer at each gate.

| Gate by | Evidence required to continue at full scope |
|---|---|
| Sep 30 | Exact memory datasheets and board revision reviewed; five-chip bus/power/pin plan feasible; selected Linux 6.12 source and ISA/ABI/config frozen; target tile pricing/shapes quoted. |
| Oct 14 | Original CPU executes RV32I/M tests; UART and one purchased PSRAM/NOR transaction path proven in protocol simulation; initial target-mapped area estimate with margin. |
| Oct 28 | RV32A, M/S/U traps, Sv32 and page-fault directed tests pass; firmware reads flash/copies to RAM; timer/interrupt path exercised. |
| Nov 11 | Reproducible Linux image reaches BusyBox ash through full-SoC serial simulation; 32 MiB peak-memory and 16 MiB flash budgets measured, failures triaged. |
| Nov 18 | FPGA prototype uses purchased external memory and UART; target-shuttle physical flow meets area/timing and basic pad/power checks. |
| Nov 23 | Freeze product RTL, firmware/image hashes, pinout and wrapper; run regression plus DRC/LVS and submission dry run. |
| Nov 30 | Submit only a design whose actual demonstrated capability and remaining limits are disclosed accurately. |

Missing a gate prompts an immediate engineering review of feasibility, including tile availability, timing, memory, and potential scope or shuttle changes. It does not silently convert a Linux-capable SoC claim into a simpler demo. Reviewed reuse may be proposed for non-distinguishing blocks with source, license, area, integration cost and verification plan before any product RTL import. The original CPU architecture and integration remain our design; an existing CPU/SoC cannot become the product by repackaging.
