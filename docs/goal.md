# Goal and acceptance criteria

**End goal:** fabricated, original RV32 SoC runs a reproducibly built Linux image using the purchased 32 MiB external PSRAM, presents an interactive UART shell, then runs a user-space 8×8 grayscale digit classifier with fixed expected outputs. Performance is secondary to correctness and an achievable shuttle submission. Tapeout budget ceiling: approximately USD 2,000 excluding prototype hardware.

Milestone evidence:

1. Bus simulation: self-checking tests pass; completed in this repository.
2. CPU: original product RTL passes RV32I/M/A, CSR, trap, and privilege tests; **diagnostic RV32I program now passes**, full ISA/privileged claim remains open.
3. MMU: Sv32 PTE permissions, page faults, access/dirty handling, and `SFENCE.VMA` pass directed and differential tests; no claim yet.
4. Firmware: a reproducible ROM/flash image initializes RAM and hands off to Linux with recorded register state and device tree; no claim yet.
5. Linux: serial log from full-SoC simulation, FPGA, and fabricated chip identifies kernel build, memory map, init process, shell, and a repeatable interaction; no claim yet.
6. Digit program: fixed 8×8 test vectors and expected labels, software-only baseline, measured RAM use and output on fabricated chip; no claim yet.
7. Shuttle: target-specific physical flow, timing, DRC/LVS, pin and power checks, and cost fit before submission; no claim yet.

Decisions from 2026-09-23: target **TTSKY26d** for submission; **BusyBox ash** satisfies the first fabricated interactive shell milestone; consider **explicitly reviewed and attributed reuse** to meet the shuttle date; use **Linux 6.12 LTS** as the prototype baseline. This does not authorize substituting a complete third-party CPU or SoC as the product. Tile allocation, final pinout, and any specific reused block remain open. No product RTL from another CPU or SoC has been adopted.
