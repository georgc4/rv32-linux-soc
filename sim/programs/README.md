# Diagnostic program

`rv32i_smoke.S` is assembled for RV32I at the **temporary test RAM base** 0x80000000. `make regen-smoke` regenerates the 41-word `rv32i_smoke.hex` using GNU RISC-V binutils and `scripts/bin_to_memh.py`. Assembled here with binutils 2.45; SHA256 of the checked-in hex is `dc210081a3c0262a0d3ecb3de5f8a7ce22b05fef01a97836cfc7a42201b3244f`.

The program tests selected ALU, branch, jump, sign-extension and byte-lane behavior, emits `OK\n` through a simulation MMIO sink, writes a success signature, and stops on diagnostic EBREAK. It is not an ISA compliance suite. If the program length changes, update `word_ram.INIT_WORDS` along with the hex file.
