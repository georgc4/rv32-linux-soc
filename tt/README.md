# Tiny Tapeout integration

The logical 8/8/8 signal wrapper is `rtl/soc/tt_um_rv32_linux_soc.v`; see `docs/pin-budget.md` and the [serial-console wiring](uart-bringup.md). Its UART RX/TX use the demoboard UART-capable `ui_in[3]`/`uo_out[4]` pair; PSRAM 3 CS# uses `uo_out[6]`. The wrapper lints and synthesizes with Yosys. `make synth-sky130` records a technology-mapped area baseline. `make stage-sky26d` creates a pinned Tiny Tapeout/LibreLane workspace in ignored `build/`; staging records the pin labels that match the staged RTL revision. The 5×4 physical sweep uses the supported 20-tile shape; see [physical baseline](physical-baseline.md). Generic Yosys gate counts cannot establish tile fit.

The [experiment framework](../experiments/README.md) runs commit-pinned synthesis, physical trials, and the serial Linux shell gate, then builds an interactive Pareto dashboard. It preserves each run's configuration and logs under ignored `build/experiments/`.
