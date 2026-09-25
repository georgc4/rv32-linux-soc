# Tang Nano 20K physical UART path

The provisional target is the vendor's **PCB 3921**, using Sipeed's
[3921 rev 1.30 schematic](https://dl.sipeed.com/fileList/TANG/Nano_20K/2_Schematic/Tang_Nano_20K_3921_Schematics.pdf).
The board has not arrived; check its printed revision before using these
constraints. The [FPGA wrapper](tang_nano_20k_3921_soc.v) instantiates the
production `soc_top` directly. Linux's `serial@10000000` device and all boot
firmware accesses therefore use the SoC's `uart16550_lite` RTL. The BL616 is
only a USB-to-UART bridge; it does not implement the console registers.

| Path | 3921 schematic net | FPGA package pin | Direction at FPGA |
|---|---|---:|---|
| SoC UART TX → BL616 RX | `PIN69_SYS_TX` ↔ `BL616_UART_RX` | 69 | Output |
| BL616 TX → SoC UART RX | `BL616_UART_TX` ↔ `PIN70_SYS_RX` | 70 | Input |

Both signals use 3.3 V LVCMOS. They connect to the onboard BL616, not to
the FPGA JTAG pins or the FPGA header. The schematic shows no second device
on either UART net. Its bank 1 `VCCO_1` and BL616 `VDDIO1` are tied to 3.3 V.
The [3921 pin constraints](tang_nano_20k_3921.cst) assign the crossed
directions above and explicitly select `LVCMOS33`; the
[timing constraint](tang_nano_20k_3921.sdc) sets 50 ns for the 20 MHz clock.

The wrapper also connects all six bidirectional SPI data lanes to top-level
tristate pads and constrains the external five-chip bus on J5/J6. The `spi_dq`
order is shared IO0/IO1, PSRAM IO2/IO3, NOR IO2/IO3. The five `spi_cs_n`
outputs select PSRAM 0–3 and NOR. Some chosen header pins are also routed to
the LCD connector; leave that connector unused. The four PSRAMs and NOR need
their specified power, pull resistors, decoupling, and common ground. Board
power and signal integrity still need bench validation.

| SoC signal | FPGA pin | Header |
|---|---:|---|
| `clk_20m` | 10 | Onboard MS5351 CLK0 |
| `rst_n` | 71 | J5 pin 18 |
| `spi_sck` | 73 | J6 pin 1 |
| `spi_cs_n[0:4]` | 74, 77, 27, 28, 25 | J6 pins 2, 5, 8, 9, 11 |
| `spi_dq[0:3]` | 26, 29, 30, 31 | J6 pins 10, 12, 13, 14 |
| `spi_dq[4:5]` | 41, 42 | J5 pins 6, 5 |

The SoC and Linux DT both use **20 MHz**. Sipeed documents configuring the
BL616-controlled MS5351 with `pll_clk`. Set CLK0, which reaches FPGA pin 10,
to 20 MHz in the BL616 terminal (`pll_clk O0=20M -s`), then query `pll_clk`
and measure the pin before releasing reset. Pin 71 (J5 pin 18) is the
active-low reset input; pull it low while setting up the clock and external
memories. Sipeed's [BL616 terminal instructions](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/unbox.html#choose)
describe `choose uart`, which connects the USB serial channel to the FPGA
UART pins. Programming over the same USB connector does not by itself select
that mode.

On macOS, identify the BL616's serial channel after plugging the board in
(`ls /dev/cu.usbserial*`), then open that channel at **115200 8N1**, for
example with `screen /dev/cu.usbserial-<UART-channel> 115200`. Select
`choose uart` in the BL616 terminal if it is not already active. On Linux,
use the matching `/dev/serial/by-id/...` or `/dev/ttyUSB*` channel; on Windows,
use the corresponding COM port. The stock firmware may expose a separate
programmer channel. Match the serial port by unplugging/replugging and by
the BL616 command prompt before relying on it for Linux.

`make test-physical-uart` sends `0x5a` out the UART transmit register and
injects `0x41` as physical receive frames through both wrappers. It checks
that the production UART RTL decodes and returns the received byte. This is
a pin-level simulation test; final hardware validation still requires a
3921 board, the purchased memories, a bitstream, and a terminal exchange.
