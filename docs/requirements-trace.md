# Initial Linux requirements trace

| Linux-facing feature | Architectural mechanism | Proposed module | Acceptance test | Current status |
|---|---|---|---|---|
| Kernel in S-mode, tasks in U-mode | M/S/U privilege, status/return, delegation | CPU CSR/trap unit | M→S→U transitions, ecall/trap return | Unimplemented |
| Virtual memory | `satp` Sv32, two-level page walk, `SFENCE.VMA` | MMU/walker | 4 KiB/4 MiB maps, ASID, TLB invalidation | Unimplemented |
| Page faults | PTE V/R/W/X/U/G/A/D, access vs page faults, `stval` | MMU + trap unit | Permission and malformed PTE matrix | Unimplemented |
| Atomic synchronization | RV32A LR/SC and AMOs, ordering | CPU atomic unit + memory lock | ISA litmus and interrupt/reservation tests | Unimplemented |
| Instruction/data ordering | `FENCE`, `FENCE.I`, coherent view for flash/RAM writes | CPU + bus/control | Self-modifying code and MMIO ordering | Unimplemented |
| Timer ticks | counter + compare, M/S interrupt and SBI TIME path | timer + firmware | Timer interrupt and Linux clockevent | Unimplemented |
| UART console | byte TX/RX, polling first, IRQ later | UART + interrupt controller + driver/DT | Boot log and interactive input | Unimplemented |
| External working RAM | 4 × 8 MiB PSRAM, byte stores, bursts, atomicity | PSRAM controller | Per-chip stress, boundary, refresh/timing | Unimplemented |
| Boot image | immutable ROM, NOR reads/copy, validated firmware | ROM + flash controller + firmware | Cold boot and corrupt-image recovery | Unimplemented |
| Linux handoff | `a0` hart ID, `a1` DTB, `satp=0`, 4 MiB aligned RV32 image | M-mode firmware | Entry-state assertion and serial boot | Unimplemented |
| Device discovery | correct DTB for memory/UART/timer/IRQ | firmware + build scripts | `dtc` and kernel driver binding | Unimplemented |

The initial bus routes **physical** requests and passes its contract tests. That is a dependency for several rows, not completion of a Linux feature.
