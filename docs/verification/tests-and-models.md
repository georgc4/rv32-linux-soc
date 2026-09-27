# Verification layers, testbenches, and limits

**Sources:** [`Makefile`](../../Makefile), [`sim/tests/`](../../sim/tests/), [`sim/models/`](../../sim/models/). A test passing confirms the stimulus and assertions in that test, not an exhaustive proof of an ISA, controller, or physical interface.

## Directed tests

| Make target / testbench | What it checks |
|---|---|
| `test` / `physical_bus_tb` | Address decode, target selection, request/response holding, errors, latency device behavior |
| `test-core` / `rv32i_core_tb` | RV32 instruction execution, loads/stores, register writes, diagnostic faults with word RAM/UART sink |
| `test-mdu` / `rv32_mdu_tb` | Multiply/divide edge cases, signedness, divide zero, iterative completion |
| `test-priv` / `priv_trap_tb`, `priv_mip_tb` | CSR/trap/return and software/hardware interrupt-pending behavior |
| `test-sv32` / `sv32_bus_adapter_tb` | Page-table walks, TLB, permission and A/D behavior, faults |
| `test-supervisor` / `sv32_supervisor_tb` | Core plus MMU running a small supervisor program |
| `test-serial` / `serial_mem_bridge_tb` | Real serial command phases, four-bank RAM, reset, NOR read/program/erase/status, data-lane contention checks |
| `test-uart` / `uart16550_lite_tb` | Register subset, divisor, TX/RX frames, IRQ behavior |
| `test-physical-uart` / `physical_uart_paths_tb` | Pin-level TX and RX frames through FPGA and ASIC wrappers and production UART RTL |
| `test-timer`, `test-plic` | CLINT register/IRQ and PLIC claim/complete behavior |
| `test-soc`, `test-soc-bad` | Integrated ROM/flash/PSRAM boot of small image and corrupt-image rejection |
| `test-linux-handoff` / `linux_handoff_tb` | M-mode loader and a small substitute kernel, including bad DTB/kernel cases |
| `test-digit` | Host build of the digit program and fixture outputs |

`make lint` runs Verilator lint on individual units and the complete Tiny Tapeout wrapper. `synth-core`, `synth-soc`, and `synth-sky130` check synthesizeability and mapped area, but are not functional proofs. The checked-in hex programs under `sim/programs/` are generated from assembly with the `regen-*` targets. [`bin_to_memh.py`](../../scripts/bin_to_memh.py) and [`make_flash_image.py`](../../scripts/make_flash_image.py) turn small binaries into model inputs.

## Serial memory model

`serial_spi_model.v` consumes the actual SCK, CS#, output data, and output-enable waveforms, decodes serial opcodes and addresses, and returns data at the appropriate bit/nibble phases. It supports PSRAM reset, quad read/write, and NOR read, write-enable, byte program, sector erase, and status polling. Small directed tests use reduced memory capacities; the Linux bench instantiates four full 8 MiB PSRAM arrays and one full 16 MiB NOR array. The bench initializes NOR to erased `0xff`, loads byte-hex from the packed flash image, and leaves RAM as modeled storage. It checks simultaneous chip selection and drive conflicts in the directed bridge test. This is a digital functional model: it does not enforce real setup/hold, power ramp, analog bus contention, line capacitance, or vendor corner timing.

## Full Linux acceptance

[`linux_serial_boot_tb.v`](../../sim/tests/linux_serial_boot_tb.v) instantiates the production `soc_top` with diagnostic mode off, five serial chip models, and UART pins. [`linux_serial_boot_main.cpp`](../../sim/tests/linux_serial_boot_main.cpp) supplies the Verilator clock and execution loop. The bench observes UART writes as text, records cycle/retirement/interrupt/SPI counters, fails on a kernel panic, fault/halt, RX overrun, or cycle cap, and prints periodic `PROGRESS`/`GUEST` traces. Once it sees the `ASH> ` prompt, it transmits `/bin/acceptance_smoke\n` as timed UART **receive frames**, waiting for the guest to consume each byte because the UART has one receive register. The pass requires userspace marker, ash prompt, `ASH_PROGRAM_OK`, and a zero-exit simulation. The bench also counts UART IRQ edges, PLIC claims/completions, SBI ECALLs, page faults, and external-memory requests for diagnosis.

The default bench cap is 20 billion cycles; experiment runs can pass `+max_cycles` and commonly use 25 billion. A timeout after a shell prompt is not a functional failure unless other evidence says so. A `PASS` in a different RTL revision or flash image cannot be transferred without exact provenance. The [runner](../experiments/method.md) records RTL commit, image SHA, harness hash, serial-model hash, and source log. Simulation wall time depends on host and simulator optimization. A logical 20 MHz clock means a completed cycle would be 50 ns on ideal hardware; it does not pace the host simulator in real time.

## Missing coverage to add when hardware changes

The acceptance gate proves one image and workload. It is not a formal ISA suite, analog SPI timing qualification, power-on sequencing measurement, board validation, or exhaustive NOR endurance test. New RTL that changes atomicity, MMU permissions, interrupt timing, UART framing, memory command cadence, or external pins should get a focused directed regression and a fresh full acceptance run before physical comparison. New custom macros require DRC/LVS/extracted timing separately; the standard-cell GDS check cannot establish an unintegrated macro's correctness.
