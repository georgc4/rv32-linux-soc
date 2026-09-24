# Tiny Tapeout integration

The logical 8/8/8 signal wrapper is `rtl/soc/tt_um_rv32_linux_soc.v`; see `docs/pin-budget.md`. The wrapper lints and synthesizes with Yosys. This directory will hold the SKY26d-specific template files, `info.yaml`, configuration and mapped physical-flow results after the target shuttle's delivered rules, tile shape and board pinout are checked. Generic Yosys gate counts cannot establish tile fit.
