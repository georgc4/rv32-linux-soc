# Linux requirements trace

| Linux-facing feature | RTL mechanism | Current evidence | Remaining gate |
|---|---|---|---|
| M/S/U privilege and traps | `rv32_priv_unit`, core trap/return path | `test-priv` checks M-mode ECALL/CSR/MRET and timer IRQ; `test-supervisor` checks M-to-S transition; `test-linux-handoff` checks S-mode SBI ECALL and delegated timer/external IRQ | U-mode and broader delegation matrix; privileged ISA compliance |
| Virtual memory | `sv32_bus_adapter` two-level walk and 16-entry TLB, flushed on `SFENCE.VMA` | `test-sv32` checks 4 KiB/4 MiB translation, A/D, permissions, TLB hit/flush; `test-supervisor` checks translated fetch/store; full-image Linux run reached `/init` | Extensive malformed-PTE and page-fault tests |
| Page faults | Sv32 response distinguishes page fault from access fault; CPU writes trap cause/value | Adapter permission-fault test | End-to-end delegated page-fault handler and `stval` test |
| Atomic synchronization | RV32A LR/SC and word AMOs, serialized single-master bus | Diagnostic assembly checks LR/SC success/failure, AMO add/min | ISA litmus, all AMOs, physical reservation semantics and ordering review |
| Instruction/data ordering | Single outstanding bus; no instruction cache; fences are serialized/no-op | Diagnostic CPU program, interconnect simulation | Self-modifying code and device ordering tests |
| Timer ticks | `mtime`, `mtimecmp`, `msip`; time CSR; M/S interrupt CSR state | `test-timer` checks compare and software IRQ; `test-priv` checks machine timer trap; Linux boot ran with a 16 Hz tick | Investigate late-boot soft-lockup warnings and broaden timing validation |
| UART console | 16550-like TX/RX, four-byte register spacing; one-source PLIC wired to S external interrupt | Integrated boot sends `OK\n`; `test-uart` checks RX/IRQ; `test-plic` checks claim/complete; `test-linux-handoff` takes S external interrupt; full-image Linux run printed `/init` marker through UART | Interactive input and shell prompt |
| External RAM | Four-bank PSRAM `EBh`/`38h` quad SPI bridge | `test-serial` covers banks and byte lanes through bit-level device models; `test-soc` boots through flash and RAM | Physical timing, stress, capacity, throughput, board test |
| Boot image | ROM header with bounded length and checksum; NOR read/program/erase | `test-soc-bad` checks valid boot and corrupt-image rejection; `test-serial` exercises program/erase/status; full NOR image boots Linux through `/init` | UART updater and recovery, stronger image integrity |
| Linux handoff | Resident M-mode loader copies Image/DTB and implements SBI v0.2 BASE/TIME | `test-linux-handoff` runs a kernel-shaped S-mode payload; full Linux 6.12.111 image reaches BusyBox ash `/init` in 12,454,790,706 cycles | Interactive shell and digit demo end-to-end checks |
| Device discovery | Physical memory map | Bus decode tests; DTB compiled with PSRAM, PLIC, UART and CPU; full Linux UART console log | Review live device probes and validate on hardware |

The full-capacity quad-serial simulation completed its `/init` userspace-ready criterion with exit code 0 on 2026-09-24. `/init` ran under BusyBox ash, but the testbench stops before the interactive shell prompt. Three recoverable soft-lockup warnings appeared before userspace; the run still reached `/init`.
