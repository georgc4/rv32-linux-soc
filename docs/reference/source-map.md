# Source map: where every major responsibility lives

This page is a navigation index. The detailed behavior is in the linked handbook chapters and source files. A generated `build/` directory is intentionally ignored; do not treat a local build artifact as a checked-in design input unless its hash and producing command are recorded.

## RTL

| File | Responsibility | Handbook |
|---|---|---|
| [`rtl/soc/soc_top.v`](../../rtl/soc/soc_top.v) | Production integration, bus wiring, interrupt wiring | [Architecture](../system/architecture.md), [integration](../rtl/integration-and-pins.md) |
| [`rtl/soc/tt_um_rv32_linux_soc.v`](../../rtl/soc/tt_um_rv32_linux_soc.v) | Tiny Tapeout logical pin wrapper | [Integration](../rtl/integration-and-pins.md) |
| [`rtl/cpu/rv32i_core.v`](../../rtl/cpu/rv32i_core.v) | Instruction sequencing, banked RF, ALU, loads/stores, atomics, traps | [Core](../rtl/cpu-core.md) |
| [`rtl/cpu/rv32_mdu.v`](../../rtl/cpu/rv32_mdu.v) | Iterative RV32M multiplication/division | [MDU](../rtl/mdu-and-privilege.md) |
| [`rtl/cpu/rv32_priv_unit.v`](../../rtl/cpu/rv32_priv_unit.v) | CSRs, modes, delegation, interrupts, trap vectors | [Privilege](../rtl/mdu-and-privilege.md) |
| [`rtl/interconnect/sv32_bus_adapter.v`](../../rtl/interconnect/sv32_bus_adapter.v) | Page walk, A/D update, TLB, physical requests | [Sv32](../rtl/sv32.md) |
| [`rtl/interconnect/physical_bus.v`](../../rtl/interconnect/physical_bus.v) | Physical address decode and single-target handshake | [Bus](../system/bus-and-address-map.md) |
| [`rtl/interconnect/cpu_bus_adapter.v`](../../rtl/interconnect/cpu_bus_adapter.v) | Direct-test instruction/data arbiter, not production path | [Bus](../system/bus-and-address-map.md) |
| [`rtl/memory/serial_mem_bridge.v`](../../rtl/memory/serial_mem_bridge.v) | Four PSRAM + NOR SPI transfer engine and NOR control | [Serial memory](../rtl/serial-memory.md) |
| [`rtl/peripherals/uart16550_lite.v`](../../rtl/peripherals/uart16550_lite.v) | 16550-like console registers/frames/IRQ | [Peripherals](../rtl/peripherals.md) |
| [`rtl/peripherals/clint_timer.v`](../../rtl/peripherals/clint_timer.v) | `mtime`, compare, software IRQ | [Peripherals](../rtl/peripherals.md) |
| [`rtl/peripherals/plic_lite.v`](../../rtl/peripherals/plic_lite.v) | UART source priority/enable/claim | [Peripherals](../rtl/peripherals.md) |
| [`rtl/peripherals/boot_rom.v`](../../rtl/peripherals/boot_rom.v) | First-stage instruction ROM | [Boot](../boot/boot-chain.md) |

## Firmware, Linux, and programs

| Files | Responsibility |
|---|---|
| [`firmware/boot_rom.S`](../../firmware/boot_rom.S), [`boot_rom.hex`](../../firmware/boot_rom.hex) | RVSB header validation, loader copy and jump; checked-in ROM content |
| [`firmware/linux_loader_entry.S`](../../firmware/linux_loader_entry.S), [`linux_loader.c`](../../firmware/linux_loader.c), [`linux_loader.ld`](../../firmware/linux_loader.ld) | M-mode startup/traps/SBI, Image/DTB copy, RAM placement |
| [`linux/build-image.sh`](../../linux/build-image.sh), [`Containerfile`](../../linux/Containerfile), [`sources.sha256`](../../linux/sources.sha256) | Pinned source downloads, BusyBox, kernel, programs, DTB build |
| [`linux/kernel-6.12.111.config`](../../linux/kernel-6.12.111.config), [`busybox-1.37.0.config`](../../linux/busybox-1.37.0.config), [`patch-hz16.py`](../../linux/patch-hz16.py), [`config-variant.py`](../../linux/config-variant.py) | Kernel/BusyBox options and controlled variants |
| [`linux/rv32-linux-soc.dts`](../../linux/rv32-linux-soc.dts), [`init`](../../linux/init), [`check-image.py`](../../linux/check-image.py) | Hardware description, first userspace process, artifact validation |
| [`software/acceptance_smoke.c`](../../software/acceptance_smoke.c) | Deterministic userspace acceptance marker |
| [`software/digit/digit_demo.c`](../../software/digit/digit_demo.c), [`test_digit.py`](../../software/digit/test_digit.py), fixtures | 8×8 integer classifier and host tests |
| [`scripts/pack_linux_flash.py`](../../scripts/pack_linux_flash.py), [`build_linux_firmware.sh`](../../scripts/build_linux_firmware.sh), [`flash_to_bytehex.py`](../../scripts/flash_to_bytehex.py) | Build/pack/check NOR contents and serial-model byte hex |
| [`scripts/make_flash_image.py`](../../scripts/make_flash_image.py), [`bin_to_memh.py`](../../scripts/bin_to_memh.py), [`run_timed_serial_boot.py`](../../scripts/run_timed_serial_boot.py) | Small-image tooling and timed boot runs |

## Simulation and verification

`sim/models/serial_spi_model.v` is the pin-level PSRAM/NOR model. `word_ram.v` and `latency_device.v` support fast directed unit tests; `mmio_uart_sink.v` captures test UART writes. `sim/tests/` contains the named unit/integration benches described in [verification](../verification/tests-and-models.md), including `linux_serial_boot_tb.v` and its Verilator C++ driver. `sim/programs/` holds small assembly fixtures and regenerated hex. [`Makefile`](../../Makefile) is the executable index of common local checks.

## Physical, FPGA, and experiments

`fpga/tang_nano_20k_3921_soc.v`, `.cst`, and `.sdc` form the provisional FPGA wrapper, pin map, and 50 ns constraint; [`fpga/README.md`](../../fpga/README.md) is the board procedure. `tt/stage_sky26d.py`/`stage_sky26d_uart.py` create a pinned shuttle workspace, `run_sky130_synth.sh` produces standalone mapped estimates, and `generate_rtl_block_diagrams.py`/`generate_rtl_tool_views.sh` create code-derived architecture views in `docs/rtl-block-diagrams/`. `tt/reports/` contains a checked-in early physical baseline; local later runs are under ignored `build/experiments/`.

`experiments/runner.py` identifies and executes commit-pinned trials; `run_physical_queue.py` controls disk-conscious PNR; `run_area_round.py` schedules acceptance and physical lanes; `visualize.py` builds the interactive Pareto page. JSON manifests select immutable revisions/configurations. [`RESULTS.md`](../../experiments/RESULTS.md) and [`NEXT-SESSION.md`](../../experiments/NEXT-SESSION.md) are dated ledgers/plans. `experiments/register-file/` contains independent RTL, SPICE, KLayout/Magic, and OpenRAM studies; these are not production CPU storage. [Physical](../physical/flow-and-evidence.md) and [layout](../physical/register-file-layout.md) explain the evidence.

The [CI workflow](../../.github/workflows/ci.yml) runs fast simulation/lint on pushes and PRs, not full Linux or PNR. [Debugging and reproduction](../verification/debugging-and-reproduction.md) explains how to interpret those layers. [Tools and views](../tools-and-views.md) covers Yosys/netlistsvg, GDS/KLayout, and the experiment dashboard.
