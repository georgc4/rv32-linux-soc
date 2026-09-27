# Linux-facing requirements trace

This is a quick current index. The [engineering handbook](README.md) gives implementation details, and [tests and models](verification/tests-and-models.md) gives exact verification scope. A digital Linux acceptance pass applies to its pinned RTL commit and flash image; it does not prove silicon or board timing.

| Requirement | Implemented path | Evidence and remaining gap |
|---|---|---|
| RV32IMA, CSR, traps | Core, iterative MDU, privilege unit | Directed core/MDU/privilege tests and full Linux boot; broader architectural compliance suite remains open. |
| Sv32 and A/D updates | Two-level walker, four-entry direct-mapped TLB, `SFENCE.VMA` flush | Directed MMU/supervisor tests and Linux page-fault activity; exhaustive malformed PTE and context-switch testing remains open. |
| External 32 MiB RAM | Four 8 MiB PSRAM chips through actual `EBh`/`38h` serial phases | Pin-level model and full Linux simulation; purchased-device electrical timing and board bring-up remain open. |
| NOR boot and raw update | ROM RVSB copy, loader LNX1/Image/DTB copy, NOR read/program/erase/status | Valid/corrupt image tests and full boot; updater/recovery protocol and secure authentication are not implemented. |
| Linux timer/SBI | CLINT `mtime/mtimecmp`, M-mode loader BASE/TIME SBI | Directed handoff and full Linux timer traces; routed timing and physical clock accuracy remain open. |
| UART console and external IRQ | SoC `uart16550_lite`, PLIC source 1, pin wrappers | TX/RX unit and wrapper tests plus full ash command over UART; real FPGA/demoboard serial connection untested. |
| Interactive userspace | Embedded BusyBox ash `/init`, static smoke program | Full serial acceptance sees `ASH>`, injects `/bin/acceptance_smoke`, and sees `ASH_PROGRAM_OK`; broader application workload and persistent storage are separate work. |
| Fabricable physical layout | Tiny Tapeout/LibreLane 5×4 reference, independent DRC/LVS audit | One pinned reference GDS passes geometry/connectivity checks; current architecture/8×2 trials, full multi-corner timing/power/IO and final shuttle signoff remain open. |
