# Host and build workflow

Inspected on the primary M3 Pro macOS host on 2026-09-23: Icarus Verilog 13.0, Verilator 5.046, Yosys 0.63, Python 3.14.6, and `riscv64-unknown-elf-gcc` 15.1.0 are present. Make and a host C compiler are present. A RISC-V **Linux** cross compiler was not found. No system packages were installed or updated in this session.

Fast local loop: `make test test-core test-digit lint synth-bus synth-core`. The synthesis targets report generic Yosys cells in `build/synth-*.log`, not mapped area or frequency. `make regen-smoke` rebuilds the checked-in diagnostic program using local GNU RISC-V binutils 2.45; CI does not require that cross toolchain because it uses the committed hex image. CI uses Ubuntu 24.04 with apt-installed Icarus and Verilator. The distribution package versions are not yet pinned; before release, pin a container digest or exact package versions and record the toolchain in build manifests.

macOS runs the fast RTL loop and `make image-linux`. The image script uses the existing local Podman machine for the Linux kernel build and Zig for static RV32 userspace; it does not use the remote iMac. It verifies source SHA256 values and writes configs, DTB, image artifacts, and a size/hash manifest under ignored `build/`. A firmware build and serial boot log are still needed before any boot claim. Do not put host credentials in build scripts.

The Tang Nano 20K FPGA stage needs a board-specific constraint file after the physical revision is known. The Tiny Tapeout stage needs a wrapper/configuration imported from the selected shuttle's official template and an actual mapped/routed area result. Neither is part of the fast loop.
