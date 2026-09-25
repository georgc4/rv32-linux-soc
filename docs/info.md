# RV32 Linux SoC — TTSKY26d draft

This project targets an 8×2 tile allocation on TTSKY26d. The RTL contains an
RV32IMA CPU, Sv32 address translation, UART, timer, interrupt controller, and
serial interface to four external quad PSRAM chips and one quad NOR flash.
The logical Tiny Tapeout pins are documented in [the pin budget](pin-budget.md).

The external NOR holds a bootloader, Linux 6.12 kernel, device tree, and a
BusyBox ash initramfs. The external PSRAM provides 32 MiB of memory. The
repository's full serial RTL simulation reached `/init` and printed
`RV32 Linux userspace ready` on the baseline design. A stronger BusyBox ash
and user-program gate is being evaluated on experiment branches.

**Draft status:** This design has not passed the TTSKY26d physical flow. The
8×2 local trial did not generate a signoff GDS. This repository revision
must not be selected as a fabrication revision until GDS, precheck, timing,
and gate-level checks pass. The external board and pinout also need validation.

The 20 MHz `clk` input and `rst_n` are the standard Tiny Tapeout interface.
UART RX is `ui_in[3]`; UART TX is `uo_out[4]`, the demoboard's documented
hardware-UART pair. The memory serial clock is `uo_out[0]`; PSRAM 0–2 chip
selects are `uo_out[1:3]`, PSRAM 3 is `uo_out[6]`, and NOR is `uo_out[5]`.
External memory wiring must use the new PSRAM 3 pin. The six bidirectional
memory data pins are `uio[0:5]`.
`uo_out[7]` signals completion of PSRAM initialization.

The physical baseline and reproducible build instructions are in
[the physical baseline report](../tt/physical-baseline.md). The exact image
build and simulation acceptance command are in [the main README](../README.md).
