# External signal allocation

The `tt_um_rv32_linux_soc` wrapper assigns six bidirectional signals, seven output signals, and one input signal. This fits the Tiny Tapeout logical 8/8/8 interface, subject to actual shuttle pad and board validation.

| Signals | Logical pins | Reset/startup behavior |
|---|---|---|
| Shared IO0/IO1 for all five memories | `uio[0:1]` | High impedance while reset is held |
| PSRAM SIO2/SIO3 | `uio[2:3]` | External pull-downs required during power-up |
| NOR IO2/IO3 (WP#/HOLD# on non-QE variants) | `uio[4:5]` | External pull-ups give defined levels during reset |
| Memory SCK | `uo[0]` | Low |
| Four PSRAM CS# | `uo[1:4]` | High; external pull-ups advised |
| NOR CS# | `uo[5]` | High; external pull-up advised |
| UART TX | `uo[6]` | Idle high |
| PSRAM initialization status | `uo[7]` | Low until all reset commands complete |
| UART RX | `ui[0]` | Host drives idle high |

The split IO2/IO3 assignment lets PSRAM use its required low power-up bias while the NOR's corresponding pins have a defined high startup level. The purchased SIQ NOR has QE fixed on, so those pins carry quad read data after the serial command and address. The bridge waits 150 µs at a 20 MHz clock, resets each PSRAM with `66h` then `99h`, and uses SCK at half the SoC clock. PSRAM `EBh` reads use 8 serial command clocks, 6 quad address clocks, 6 wait clocks, and 8 quad data clocks for a word; `38h` full-word writes use 8+6+8 clocks. Both fit the PSRAM 8 µs CS-low maximum at 10 MHz SCK. The board must provide a stable 20 MHz clock, appropriate 3.3 V signaling and power, common ground, each device's decoupling, and the stated passive pulls. Pad drive/fanout and physical signal integrity remain unverified.

No physical pad numbers or PCB pinout are asserted here. `ui[7:1]` and `uio[7:6]` are unused.
