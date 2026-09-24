# RV32 Linux SoC experiment

Goal: an original RV32 SoC on a Tiny Tapeout die that boots Linux from external flash into 32 MiB of external PSRAM, exposes a UART shell, and runs an 8×8 grayscale digit classifier. This repository is at the **interconnect contract** stage; it does not contain a CPU, memory electrical controller, boot firmware, or a Linux image.

## Reproduce the first milestone

On macOS with Homebrew tools or Ubuntu with distribution packages, install Icarus Verilog, Verilator, Yosys, and Make. No tool installer is run by this repository.

```sh
make test       # request/response routing and stalls
make test-core  # assembled RV32I diagnostic program, RAM/UART and fault tests
make test-digit # host software-only classifier and fixed grayscale fixtures
make lint       # Verilator lint of the synthesizable bus
make synth-bus  # generic Yosys gate count; not a tile estimate
make synth-core # generic Yosys count of the diagnostic core
```

The same fast simulation/lint checks run in GitHub Actions. `rtl/` is original product RTL. The current CPU is a diagnostic RV32I implementation with no privileged architecture or MMU. `sim/models/` contains behavioral devices only. `fpga/` and `tt/` are awaiting board and shuttle-specific constraints and configuration.

Start with [the goal](docs/goal.md), [architecture](docs/architecture.md), [requirements trace](docs/requirements-trace.md), and [risks](docs/risks.md). Source provenance and verification dates are in [references](docs/references.md); host and Ubuntu workflow is in [workflow](docs/workflow.md).
