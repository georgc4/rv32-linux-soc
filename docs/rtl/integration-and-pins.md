# Integration, wrappers, and pin ownership

**Sources:** [`soc_top.v`](../../rtl/soc/soc_top.v), [`tt_um_rv32_linux_soc.v`](../../rtl/soc/tt_um_rv32_linux_soc.v), [`tang_nano_20k_3921_soc.v`](../../fpga/tang_nano_20k_3921_soc.v). The memory-mapped UART is the same RTL module in simulation, FPGA, and ASIC; the wrappers only connect its serial pins.

`soc_top` wires CPU instruction/data outputs to the Sv32 adapter, then its physical request to `physical_bus`. The bus fans out to seven logical targets. RAM, NOR-read, and NOR-control ports all terminate in one serial bridge. CLINT machine timer/software IRQ, UART machine external IRQ, and PLIC supervisor external IRQ return to the CPU. `sfence_commit` from the core invalidates the Sv32 TLB. `retire_valid`/`retire_pc` are internal observation wires, not a debug bus at the chip pins.

## Tiny Tapeout logical pins

| Pin | Function | Direction at project |
|---|---|---|
| `clk`, `rst_n` | System clock, active-low reset | Input |
| `ui_in[3]` | SoC UART RX | Input |
| `uo_out[4]` | SoC UART TX | Output |
| `uo_out[0]` | SPI SCK | Output |
| `uo_out[1:3]` | PSRAM 0–2 CS# | Output |
| `uo_out[6]` | PSRAM 3 CS# | Output |
| `uo_out[5]` | NOR CS# | Output |
| `uo_out[7]` | PSRAM initialization complete | Output |
| `uio[0:1]` | Shared IO0/IO1 | Bidirectional by phase |
| `uio[2:3]` | PSRAM IO2/IO3 | Bidirectional by phase |
| `uio[4:5]` | NOR IO2/IO3 | Bidirectional by phase |

The remaining user inputs/IO are unused in RTL. `ena` is intentionally unused. Pin placement is a logical mapping; it does not build a PCB connection or turn the demoboard controller into a transparent USB serial bridge. [`tt/uart-bringup.md`](../../tt/uart-bringup.md) gives the onboard UART pair, external 3.3 V adapter fallback, and controller revision caveat. The fourth PSRAM select moved from the earlier `uo_out[4]` to `uo_out[6]`; external wiring must follow the new map. Use [`stage_sky26d_uart.py`](../../tt/stage_sky26d_uart.py) for physical staging, because it checks the wrapper and corrects the base stage script's historical pin labels.

## Tang Nano 20K FPGA wrapper

The provisional target is PCB 3921, schematic rev 1.30. FPGA pin 69 is SoC TX toward the onboard BL616 RX; pin 70 is SoC RX from BL616 TX, both 3.3 V LVCMOS on the schematic. The board MS5351 clock output reaches pin 10 and must be configured to 20 MHz; reset is pin 71. The wrapper turns each of the six SPI DQ output-enable bits into a top-level tristate. Its [CST](../../fpga/tang_nano_20k_3921.cst) assigns pins and [SDC](../../fpga/tang_nano_20k_3921.sdc) constrains 50 ns. The [FPGA guide](../../fpga/README.md) lists every header pin, BL616 `choose uart`, and host terminal procedure. The board has not yet been received and its actual PCB revision must be confirmed before relying on these constraints.

The production Linux device tree continues to describe UART at `0x1000_0000` with four-byte register stride. Neither wrapper substitutes a vendor UART peripheral or a host-software console. The [physical UART test](../../sim/tests/physical_uart_paths_tb.v) sends and receives frames through both wrappers and the SoC UART pins in simulation; hardware confirmation remains separate.
