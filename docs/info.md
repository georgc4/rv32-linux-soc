# RV32 Linux SoC — TTSKY26d draft

This project targets a 5×4 tile allocation on TTSKY26d. The RTL contains an
RV32IMA CPU, Sv32 address translation, UART, timer, interrupt controller, and
serial interface to four external quad PSRAM chips and one quad NOR flash.
The logical Tiny Tapeout pins are documented in [the pin budget](pin-budget.md).

The external NOR holds a bootloader, Linux 6.12 kernel, device tree, and a
BusyBox ash initramfs. The external PSRAM provides 32 MiB of memory. The
repository's full serial RTL simulation boots Linux, reaches the BusyBox
ash prompt, sends `/bin/acceptance_smoke` through UART RX, and observes
`ASH_PROGRAM_OK` on UART TX for the source snapshot below.

**Qualification status:** The source snapshot matches RTL commit
`7ebde5cec555806030467657d8bdd1e4f48fe0e6`: one 16-byte instruction-cache
line and four TLB entries. Its local 5×4 run
`7ebde5cec555-e811a35c1f2d` passed full serial Linux/BusyBox acceptance
in 13,877,255,869 cycles, full KLayout FEOL/BEOL/off-grid DRC, Magic DRC,
Netgen LVS, and antenna checks. This submission reproduces its AREA 2
mapping and 0.05/0 ns hold margins, with KLayout DRC also enabled in CI.

It is **not fully timing-qualified or fabrication-ready**: final slow-corner
setup slack is −9.447 ns at the 50 ns target, electrical limit violations
remain, and external I/O timing constraints are provisional. Passing the
standard GDS action does not close those gaps. The recorded evidence and
full timing audit are in [tt/qualification/7ebde5c](../tt/qualification/7ebde5c).
GitHub GDS, precheck, and gate-level results must be checked on this exact
submission commit.

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
