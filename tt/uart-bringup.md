# Tiny Tapeout serial-console wiring

The SoC's own memory-mapped `uart16550_lite` drives the Linux console at
`0x1000_0000`, 115200 8N1 with a 20 MHz project clock. The Tiny Tapeout
wrapper maps SoC RX to **`ui_in[3]`** and SoC TX to **`uo_out[4]`**. This is
one of the two [documented onboard UART pairs](https://tinytapeout.com/specs/pinouts/#uart-to-usb)
for the Tiny Tapeout demoboard. The prior `ui_in[0]`/`uo_out[6]` pair was not
one of those pairs. The other supported pair (`ui_in[1]`/`uo_out[0]`) would
require moving the memory clock, so this design uses the first pair.

The demoboard controller is connected to project I/O and can configure its
hardware UART for this pair. Its USB serial connection normally exposes the
controller's management REPL. A transparent bridge from that USB connection
to the SoC UART requires suitable demoboard firmware or a board-side script;
pin placement alone does not enable such forwarding. The
[Tiny Tapeout demoboard guide](https://tinytapeout.com/guides/get-started-demoboard/)
describes selecting a project and setting a clock before driving the inputs.
The [current board repository](https://github.com/TinyTapeout/tt-demo-pcb)
describes an RP2350 revision, while earlier boards use RP2040. Confirm the
actual carrier revision and firmware supplied with SKY26d before choosing a
controller-side UART bridge implementation. The SoC UART interface does not
depend on that choice.

For a direct serial connection, use a USB-to-UART adapter whose **signal
levels are 3.3 V** (not 5 V RS-232):

| Adapter signal | Tiny Tapeout project signal | Direction |
|---|---|---|
| TXD | `ui_in[3]` on the INPUT header | Adapter → SoC RX |
| RXD | `uo_out[4]` on the OUTPUT header | SoC TX → adapter |
| GND | Demoboard GND | Common reference |

Do not connect the adapter's power output to the demoboard. Put the demoboard
in manual-input mode if the RP2 would otherwise drive `ui_in[3]`, and ensure
the DIP switch for input 3 is off. Select the design, provide a verified
20 MHz project clock, and open the adapter's host serial device at 115200
8N1 with flow control disabled. The external adapter is the direct electrical
fallback when the onboard controller does not provide a transparent bridge.

The external five-chip SPI wiring remains: `uo_out[0]` SCK,
`uo_out[1:3]` PSRAM 0–2 CS#, `uo_out[6]` PSRAM 3 CS#,
`uo_out[5]` NOR CS#, and `uio[5:0]` the six data lanes. The change to
PSRAM 3 CS# is a required carrier/interposer wiring change. A PCB trace to
the old `uo_out[4]` pad would connect that memory select to UART TX and must
not be used.

`make test-physical-uart` verifies both directions at the project pins using
the production UART RTL. A second serial Linux acceptance test sends UART RX
frames and checks a BusyBox ash command through `soc_top`. Neither simulation
establishes a completed board-level bridge or electrical timing; perform a
terminal exchange on the actual demoboard when available.
