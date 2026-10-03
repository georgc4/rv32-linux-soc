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

**Timing-fix candidate:** This snapshot stages instruction legality during the
existing READ_RS2 cycle, removing that decode cone from EXEC writeback.
Its canonical RTL matches tested revision
`f91a5e108ca57f257d740447d6e14c926b77360b`. That revision passed full serial
Linux/BusyBox acceptance in 13,877,255,869 cycles, identical to its parent.

Physical validation is pending at the unchanged 50 ns clock target. CI uses
timing-driven placement and TT/SS/FF optimization corners, and checks
setup, hold, slew, and capacitance across all signoff corners. Two
local comparisons cover multicorner timing-driven placement and the
previously routable baseline physical settings. This candidate must not be
called timing-qualified until extracted setup and hold pass at every
required corner and physical DRC/LVS/antenna checks pass.

The [parent baseline evidence](../tt/qualification/7ebde5c) is retained for
comparison only. Its GDS and physical pass do not qualify this changed RTL.
External I/O timing remains provisional.

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
