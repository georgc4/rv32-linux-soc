# RV32 Linux SoC experiment

Goal: an original RV32 SoC on a Tiny Tapeout die that boots Linux from external NOR into 32 MiB of external PSRAM, exposes a UART shell, and runs an 8×8 grayscale digit classifier.

## TTSKY26d project draft

The default branch includes Tiny Tapeout's root-level [project metadata](info.yaml),
`src/` RTL snapshot, [project documentation](docs/info.md), testbench, and
GDS/Docs workflows. Refresh the snapshot from `rtl/` with
`python3 tt/update_submission_sources.py`. This is a **draft**: the 8×2
physical flow has not completed a GDS, so no fabrication revision is ready.

The repository now contains an integrated RTL path: RV32IMA CPU, selected machine/supervisor CSRs and traps, Sv32 walker, 4-bank SPI PSRAM and NOR read/program/erase, boot ROM, UART, CLINT-like timer, one-source PLIC, physical interconnect and Tiny Tapeout logical pin wrapper. Simulations boot a checked diagnostic flash image and reject a corrupt one. A local build produces a Linux 6.12.111 RV32 `Image`, DTB, embedded BusyBox ash initramfs, digit demo, M-mode SBI loader, and a 16 MiB NOR image. A full-image RTL simulation reached `/init` through real serial transfers across the modeled NOR and four PSRAM chips; BusyBox ash executed the init script and printed `RV32 Linux userspace ready` at cycle 12,454,790,706. The test exits at that marker, before checking the interactive shell prompt. The first SKY26d 8×2 physical attempt [failed detailed placement](tt/physical-baseline.md) after high area density and buffer insertion. ASIC fit, compliance testing, routed timing, and board validation remain open.

## Local checks

Install Icarus Verilog, Verilator, Yosys, Make, Python 3 and a C compiler. RISC-V GNU binutils are needed to regenerate checked-in program/ROM hex files and to strip the RV32 BusyBox image. `make image-linux-flash` also needs RV32-capable LLVM Clang, Podman, curl, and the local Podman machine; it downloads sources and tools into ignored `build/` without installing host packages.

```sh
make test test-core test-mdu test-priv test-sv32 test-supervisor
make test-serial test-uart test-timer test-plic test-soc-bad test-digit
make lint
make synth-core synth-soc
make image-smoke  # creates build/rv32i_smoke.flash.bin
make image-linux-flash  # builds local RV32 Linux artifacts and 16 MiB NOR image
make test-linux-handoff # simulates loader, SBI, timer, and PLIC handoff
make test-linux-serial-boot # long run: full Image through five quad-capable SPI chip models
```

`synth-core` and `synth-soc` report generic Yosys cells, not SKY130 mapped area or timing. Fast checks run in GitHub Actions. RTL is in `rtl/`; behavioral device models and directed tests are in `sim/`. The FPGA board constraints and shuttle-specific physical configuration remain open.

See [architecture](docs/architecture.md), [physical map](docs/memory-map.md), [boot flow](docs/boot-flow.md), [requirements trace](docs/requirements-trace.md) and [verification plan](docs/verification-plan.md). Source provenance is in [references](docs/references.md).
