# Tiny Tapeout integration

The logical 8/8/8 signal wrapper is `rtl/soc/tt_um_rv32_linux_soc.v`; see `docs/pin-budget.md`. The wrapper lints and synthesizes with Yosys. `make synth-sky130` records a technology-mapped area baseline. `make stage-sky26d` creates a pinned 8×2 Tiny Tapeout/LibreLane workspace in ignored `build/`; see [physical baseline](physical-baseline.md). The pin plan and physical results need owner review before architectural changes or submission. Generic Yosys gate counts cannot establish tile fit.
