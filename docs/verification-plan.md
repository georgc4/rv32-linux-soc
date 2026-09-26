# Verification ladder

| Stage | Current evidence | Next acceptance gate |
|---|---|---|
| Interconnect | `test` checks decode, boundaries, stalls, held responses and control window | Timeout/fault injection |
| CPU ISA | `test-core` executes RV32IMA diagnostic; `test-mdu` checks 512 arithmetic vectors | RISC-V architectural suite and differential instruction trace |
| Privilege/MMU | `test-priv` checks ECALL/MRET/timer IRQ; `test-sv32` checks pages, superpages, permissions and A/D; `test-supervisor` checks translated S-mode execution and delegated external IRQ | U-mode, page-fault, CSR WARL and exception matrix |
| Memory controllers | `test-serial` checks PSRAM banks and NOR read/program/erase/status; `test-uart` checks serial RX/IRQ; `test-timer` checks compare/MSIP; `test-plic` checks UART source routing and claim/complete | Device timing and reset-abort tests against purchased parts |
| ROM | `test-soc-bad` checks a valid image and corrupt-checksum rejection through modeled SPI and UART pins | Recovery/update firmware and larger first-stage images |
| Linux | 6.12.111 RV32 Image, DTB, BusyBox initramfs, M-mode loader and NOR package build locally; full true-serial boot reaches BusyBox ash and runs `/bin/acceptance_smoke` through the SoC UART | Longer shell workload, memory stress, and FPGA hardware boot |
| FPGA | 3921 schematic pin map and `test-physical-uart` cover the SoC UART through the FPGA wrapper | Confirm delivered revision, build bitstream, audit power, then test UART and each purchased memory live |
| ASIC | Logical TT wrapper and pin-level UART test pass; several 5×4 RTL variants produced GDS; the 4-entry shared-read GDS passed independent full KLayout DRC, Magic DRC, and Netgen LVS | Reproduce with the new per-run physical gate, constrain routed timing and external I/O, review power/pad rules, then demoboard UART test |
| Fabricated chip | No silicon | RAM stress, Linux shell, digit program and recorded serial log |

Fast CI runs all directed simulations and Verilator lint. Behavioral device models check commands and observable data, not setup/hold timing, pad voltage, regulator capacity, signal integrity or process corners. The 32-bit ROM checksum is accidental-corruption detection, not authentication. Save waveforms, seeds, tool versions, image hashes and raw logs for release milestones.
