# Verification ladder

| Stage | Minimum evidence | Status |
|---|---|---|
| Interconnect module | RAM/flash/UART decode, boundary, stalled request, held response, write strobes, miss error | **Pass** `make test` |
| CPU base ISA | Directed RV32I/M/A, riscv-arch-test or equivalent, differential trace vs reference | Partial: assembled RV32I diagnostic program and three fault scenarios pass; no architectural compliance suite |
| Privilege/MMU | CSR WARL, traps/delegation, `MRET`/`SRET`, Sv32 pages/superpages, permissions, A/D, `SFENCE.VMA`, faults | Not started |
| Controllers | Datasheet command/timing testbenches, bus contention assertions, arbitrary stalls, reset abort | Not started |
| Boot ROM + firmware | Flash manifest, copy, recovery update, image hash, S-mode handoff assertions | Not started |
| Full SoC | Reproducible Linux image and serial boot log through `init` and shell | Not started |
| FPGA | Board revision confirmed, voltage/power audit, UART loopback, each purchased memory tested | Board pending |
| Fabricated chip | UART log, memory stress, shell commands, digit tests on silicon | Future |
| Physical | Target-shuttle wrapper, synthesis, timing, DRC/LVS, power and pad rules | Not started |

Fast CI runs `make test test-core test-digit lint`. The bus contract model supplies a deterministic address tag. The CPU test has a small word RAM and an MMIO byte sink. Neither model represents PSRAM, NOR or UART electrical protocols, nor establishes safe bus sharing. Expand only as concrete controllers are implemented. Keep waveforms, seeds, tool versions, image hashes, and logs for failures and release milestones.
