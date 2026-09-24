# Linux requirements trace

| Linux-facing feature | RTL mechanism | Current evidence | Remaining gate |
|---|---|---|---|
| M/S/U privilege and traps | `rv32_priv_unit`, core trap/return path | `test-priv` checks M-mode ECALL/CSR/MRET and timer IRQ; `test-supervisor` checks M-to-S transition; `test-linux-handoff` checks S-mode SBI ECALL and delegated timer/external IRQ | U-mode and broader delegation matrix; privileged ISA compliance |
| Virtual memory | `sv32_bus_adapter` two-level walk, no TLB | `test-sv32` checks 4 KiB/4 MiB translation, A/D, permissions; `test-supervisor` checks translated fetch/store | Extensive malformed-PTE and page-fault tests; kernel execution |
| Page faults | Sv32 response distinguishes page fault from access fault; CPU writes trap cause/value | Adapter permission-fault test | End-to-end delegated page-fault handler and `stval` test |
| Atomic synchronization | RV32A LR/SC and word AMOs, serialized single-master bus | Diagnostic assembly checks LR/SC success/failure, AMO add/min | ISA litmus, all AMOs, physical reservation semantics and ordering review |
| Instruction/data ordering | Single outstanding bus; no instruction cache; fences are serialized/no-op | Diagnostic CPU program, interconnect simulation | Self-modifying code and device ordering tests |
| Timer ticks | `mtime`, `mtimecmp`, `msip`; time CSR; M/S interrupt CSR state | `test-timer` checks compare and software IRQ; `test-priv` checks machine timer trap | Linux clockevent running under the full kernel |
| UART console | 16550-like TX/RX, four-byte register spacing; one-source PLIC wired to S external interrupt | Integrated boot sends `OK\n`; `test-uart` checks RX/IRQ; `test-plic` checks claim/complete; `test-linux-handoff` takes S external interrupt; DTB binds UART to PLIC | Live 8250 driver probe, interactive input and shell |
| External RAM | Four-bank PSRAM standard SPI bridge | `test-serial` covers banks and lanes; `test-soc` boots through flash and RAM | Physical timing, stress, capacity, throughput, board test |
| Boot image | ROM header with bounded length and checksum; NOR read/program/erase | `test-soc-bad` checks valid boot and corrupt-image rejection; `test-serial` exercises program/erase/status | UART updater and recovery, stronger image integrity, full-kernel boot |
| Linux handoff | Resident M-mode loader copies Image/DTB and implements SBI v0.2 BASE/TIME | `test-linux-handoff` runs a kernel-shaped S-mode payload; 6.12.111 Image and 16 MiB NOR package build | Full Linux boot log and userspace shell |
| Device discovery | Physical memory map | Bus decode tests; DTB compiled with PSRAM, PLIC, UART and CPU | Live kernel driver probe and console log |

No Linux boot has been observed. RTL tests establish individual mechanisms and a small end-to-end S-mode handoff, not execution of the Linux kernel.
