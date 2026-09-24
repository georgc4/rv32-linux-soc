# Verification ladder

| Stage | Current evidence | Next acceptance gate |
|---|---|---|
| Interconnect | `test` checks decode, boundaries, stalls, held responses and control window | Timeout/fault injection |
| CPU ISA | `test-core` executes RV32IMA diagnostic; `test-mdu` checks 512 arithmetic vectors | RISC-V architectural suite and differential instruction trace |
| Privilege/MMU | `test-priv` checks ECALL/MRET/timer IRQ; `test-sv32` checks pages, superpages, permissions and A/D; `test-supervisor` checks translated S-mode execution and delegated external IRQ | U-mode, page-fault, CSR WARL and exception matrix |
| Memory controllers | `test-serial` checks PSRAM banks and NOR read/program/erase/status; `test-uart` checks serial RX/IRQ; `test-timer` checks compare/MSIP; `test-plic` checks UART source routing and claim/complete | Device timing and reset-abort tests against purchased parts |
| ROM | `test-soc-bad` checks a valid image and corrupt-checksum rejection through modeled SPI and UART pins | Recovery/update firmware and larger first-stage images |
| Linux | 6.12.111 RV32 Image, DTB, BusyBox initramfs, M-mode loader and NOR package build locally; `test-linux-handoff` runs a small S-mode payload through SBI timer and PLIC IRQ | Full Linux kernel boot and UART log to BusyBox ash |
| FPGA | Board pending | Board revision and power audit; UART and each purchased memory live |
| ASIC | Logical TT wrapper lints; `synth-soc` reports generic cells | SKY26d template, mapped area/timing, DRC/LVS, power and pad rules |
| Fabricated chip | No silicon | RAM stress, Linux shell, digit program and recorded serial log |

Fast CI runs all directed simulations and Verilator lint. Behavioral device models check commands and observable data, not setup/hold timing, pad voltage, regulator capacity, signal integrity or process corners. The 32-bit ROM checksum is accidental-corruption detection, not authentication. Save waveforms, seeds, tool versions, image hashes and raw logs for release milestones.
