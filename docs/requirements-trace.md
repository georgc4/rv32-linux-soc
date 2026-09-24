# Linux requirements trace

| Linux-facing feature | RTL mechanism | Current evidence | Remaining gate |
|---|---|---|---|
| M/S/U privilege and traps | `rv32_priv_unit`, core trap/return path | `test-priv` checks M-mode ECALL/CSR/MRET; `test-supervisor` checks M-to-S transition | U-mode and delegated trap matrix; privileged ISA compliance |
| Virtual memory | `sv32_bus_adapter` two-level walk, no TLB | `test-sv32` checks 4 KiB/4 MiB translation, A/D, permissions; `test-supervisor` checks translated fetch/store | Extensive malformed-PTE and page-fault tests; kernel execution |
| Page faults | Sv32 response distinguishes page fault from access fault; CPU writes trap cause/value | Adapter permission-fault test | End-to-end delegated page-fault handler and `stval` test |
| Atomic synchronization | RV32A LR/SC and word AMOs, serialized single-master bus | Diagnostic assembly checks LR/SC success/failure, AMO add/min | ISA litmus, all AMOs, physical reservation semantics and ordering review |
| Instruction/data ordering | Single outstanding bus; no instruction cache; fences are serialized/no-op | Diagnostic CPU program, interconnect simulation | Self-modifying code and device ordering tests |
| Timer ticks | `mtime`, `mtimecmp`, `msip`; time CSR; M/S interrupt CSR state | `test-timer` checks compare and software IRQ; `test-priv` checks machine timer trap | SBI TIME service, Linux clockevent |
| UART console | 16550-like TX/RX, four-byte register spacing | Integrated boot sends `OK\n` through serial TX pin; `test-uart` checks RX and interrupt clear | Linux driver binding, interactive shell |
| External RAM | Four-bank PSRAM standard SPI bridge | `test-serial` covers banks and lanes; `test-soc` boots through flash and RAM | Physical timing, stress, capacity, throughput, board test |
| Boot image | ROM header with bounded length and checksum; NOR read/program/erase | `test-soc-bad` checks valid boot and corrupt-image rejection; `test-serial` exercises program/erase/status | Linux loader, UART updater and recovery, stronger image integrity |
| Linux handoff | Not implemented in firmware | Supervisor transition test only | SBI firmware, DTB, kernel/initramfs, boot log |
| Device discovery | Physical memory map | Bus decode tests | DTB and Linux driver binding |

No Linux boot has been observed. RTL tests establish individual mechanisms and a diagnostic end-to-end path only.
