# Directed CPU programs

`rv32i_smoke.S` is an 88-word RV32IMA diagnostic linked at physical `0x80000000`. It checks arithmetic including M edge cases, byte lanes, branches, LR/SC and AMOs, sends `OK\n` through UART, writes a signature, and stops on `EBREAK` in diagnostic mode. `make regen-smoke` regenerates the checked-in hex with GNU RISC-V binutils and `scripts/bin_to_memh.py`. SHA256 of the current hex: `58a6bd2251a3e4ea766ea7b5068879769ee153efb932092ed9d9b817f8906dfd`.

`priv_trap.S` checks synchronous machine traps and timer interrupt delivery. `sv32_supervisor.S` builds page tables, enters S-mode with `MRET`, fetches through Sv32, and stores through a translated address. Use `make regen-priv regen-supervisor` to rebuild their checked-in hex files.

These are directed tests, not RISC-V architectural compliance or Linux boot evidence.
