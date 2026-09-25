# RV32 Linux SoC — TTSKY26d draft

This project targets an 8×2 tile allocation on TTSKY26d. The RTL contains an
RV32IMA CPU, Sv32 address translation, UART, timer, interrupt controller, and
serial interface to four external quad PSRAM chips and one quad NOR flash.
The logical Tiny Tapeout pins are documented in [the pin budget](pin-budget.md).

The external NOR holds a bootloader, Linux 6.12 kernel, device tree, and a
BusyBox ash initramfs. The external PSRAM provides 32 MiB of memory. The
repository's serial RTL simulation has booted the baseline design into ash
and run an acceptance program. The current area-optimized RTL variant is
still under serial acceptance testing.

**Draft status:** This design has not passed the TTSKY26d physical flow. The
8×2 local trials have not generated a signoff GDS. This repository revision
must not be selected as a fabrication revision until GDS, precheck, timing,
and gate-level checks pass. The external board and pinout also need validation.

The 20 MHz `clk` input and `rst_n` are the standard Tiny Tapeout interface.
UART RX is `ui_in[0]`; UART TX is `uo_out[6]`. The memory serial clock is
`uo_out[0]`, the four PSRAM chip selects are `uo_out[1:4]`, and the NOR chip
select is `uo_out[5]`. The six bidirectional memory data pins are `uio[0:5]`.
`uo_out[7]` signals completion of PSRAM initialization.

The physical baseline and reproducible build instructions are in
[the physical baseline report](../tt/physical-baseline.md). The exact image
build and simulation acceptance command are in [the main README](../README.md).
