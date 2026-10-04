# Build the external-memory carrier: Tang Nano 20K PCB 3923

This is the owner's bench guide. The [hardware agent handoff](hardware-agent-handoff.md) covers Ubuntu, bitstreams, programming, and test software. Build a compact **four-PSRAM + one-NOR memory carrier**, with a detachable connection to the FPGA. Keep the FPGA beside the Ubuntu iMac and connect its USB there.

**Use the 3923 mapping below.** The older repository guide reverses J6-10 and J6-11 in its header descriptions. The checked 3923 schematic says **J6-10 = FPGA 25**, **J6-11 = FPGA 26**. FPGA package numbers, header positions, and memory-package pin numbers are three different numbering systems.

## 1. Lay out the parts before soldering

| Part | Quantity | Check |
|---|---:|---|
| Tang Nano 20K | 1 | PCB **3923**, visible pin-1/header orientation |
| ESP-PSRAM64H | 4 | Mark each adapter P0, P1, P2, P3; **H** is the 3.3 V variant |
| W25Q128JVSIQ-TR | 1 | Mark adapter F; 16 MiB boot flash |
| SOP/SOIC-to-2.54 mm adapters | 5 | PSRAM: **150 mil** body; NOR package S: **208 mil** body; check footprints separately |
| Ceramic 100 nF capacitors | 5 | One directly at each chip's power pins |
| Bulk capacitor | 1 | Suggested starting point: 10 µF, at least 6.3 V rating; observe polarity if polarized |
| 10 kΩ resistors | 13 | Five CS pullups, one SCK pulldown, four RAM/shared DQ pulldowns, two NOR DQ pullups, one reset pullup |
| Reset switch or removable jumper | 1 | Shorts our `RESET_N` to ground when asserted |
| Perfboard/breadboard, headers, short wire | As needed | Detachable FPGA bus; labelled power and signal test points |
| USB data cable, multimeter | 1 each | USB charge-only cable will not program FPGA |
| Logic analyzer / oscilloscope | If available | Tell the agent what you have; scope needed to assess edge shape/voltage margins |

Capacitance and resistor values here are **proposed bench starting values**, not a completed electrical qualification. Check any preassembled adapters for existing resistors/regulators and their routing. Do not stack a NOR-style pullup network onto the PSRAM data pins.

The bare chips cannot plug directly into a breadboard. Solder each to its correct adapter with flux, inspect for bridges, then check continuity from every chip leg to its adapter terminal. Label terminals by **chip pin number** after checking them; an adapter may route pins differently from its silkscreen or from another adapter.

## 2. Understand the eight chip pins

Both selected eight-pin packages use the following functional arrangement, viewed **from the top, markings facing you**, with the pin-1 dot/notch at the top. Looking from the solder side mirrors it.

```text
                 notch / pin-1 end
                  +-----------+
   CS_N       1 --| •         |-- 8   3V3
   IO1        2 --|           |-- 7   IO3
   IO2        3 --|           |-- 6   SCK
   GND        4 --|           |-- 5   IO0
                  +-----------+
```

On the NOR, IO2 and IO3 also have /WP and /HOLD functions in relevant modes. Keep them as data pins with weak pullups; **do not hard-wire them to 3.3 V**. Verify chip markings and pin 1 against the [Espressif pinout](https://cdn-shop.adafruit.com/product-files/4677/4677_esp-psram64_esp-psram64h_datasheet_en.pdf) and [Winbond package-S pinout](https://www.winbond.com/resource-files/w25q128jv%20revf%2003272018%20plus.pdf) before powering.

## 3. Build the power section with the FPGA disconnected

1. Position the five adapters together, facing the same way. On a breadboard, each DIP adapter should straddle the center gap so opposite pins are not shorted by a shared row. Check split power rails with the meter. On perfboard, draw the top and solder-side layout before soldering.
2. Make a clearly labelled `MEM_3V3` rail and a ground rail. Connect **every chip pin 8 to MEM_3V3** and **every chip pin 4 to GND**. Put a 100 nF capacitor between those pins at each chip with the shortest practical leads; a capacitor at the far end of the breadboard does not replace these. Add the bulk capacitor at the carrier supply entry.
3. Have the agent check the board regulator/current budget before using its 3.3 V output for all five memories. A conservative preliminary memory allocation is about **200 mA plus margin**, based on summing datasheet maxima (4 × 40 mA PSRAM plus up to 25 mA NOR), separate from FPGA/board load. This is a budgeting estimate, not a measurement or proof of regulator headroom.
4. The preferred simple arrangement, **if that budget checks out**, is board 3.3 V → carrier, with the FPGA itself powered by USB. The schematic exposes 3.3 V at **J6-19** and **J5-16**, and ground at **J6-20**, **J5-15**, and **J5-2**. Select and verify the actual pads with the agent before connection. **J5-1 is +5 V: do not connect it to the memories.**
5. If a separate regulated 3.3 V supply is needed, have the agent specify sequencing and isolation. Share ground, but do not tie two regulator outputs together or drive an unpowered chip through its signal pins. Avoid this extra variable unless the power budget requires it.
6. With all power removed, check each chip's VCC and GND connections and inspect for a short between rails. Capacitors can briefly affect resistance/continuity readings; a persistent near-zero reading needs investigation. Measure voltage only in voltage mode with power on; never put the meter's current input directly across the supply.

## 4. Wire the carrier's shared signals and bias resistors

Give every signal a label. There are **six data nets**, not four shared by all five chips:

| Carrier net | Chip connections | One bias resistor per listed net |
|---|---|---|
| `SCK` | Pin 6 of P0, P1, P2, P3, F | 10 kΩ to GND |
| `DQ0` | Pin 5 of all five chips | 10 kΩ to GND |
| `DQ1` | Pin 2 of all five chips | 10 kΩ to GND |
| `RAM_IO2` | Pin 3 of P0–P3 only | 10 kΩ to GND |
| `RAM_IO3` | Pin 7 of P0–P3 only | 10 kΩ to GND |
| `FLASH_IO2` | Pin 3 of F only | 10 kΩ to MEM_3V3 |
| `FLASH_IO3` | Pin 7 of F only | 10 kΩ to MEM_3V3 |
| `CS_P0` | Pin 1 of P0 only | 10 kΩ to MEM_3V3 |
| `CS_P1` | Pin 1 of P1 only | 10 kΩ to MEM_3V3 |
| `CS_P2` | Pin 1 of P2 only | 10 kΩ to MEM_3V3 |
| `CS_P3` | Pin 1 of P3 only | 10 kΩ to MEM_3V3 |
| `CS_FLASH` | Pin 1 of F only | 10 kΩ to MEM_3V3 |

Do not tie the five chip selects together. Do not join `RAM_IO2` to `FLASH_IO2` or `RAM_IO3` to `FLASH_IO3`. There is no extra MOSI/MISO pair: in ordinary SPI, DQ0 is MOSI and DQ1 is MISO; during quad transfers these wires become bidirectional.

Use one compact bus with very short branches to the chips, with a nearby ground return. Place the carrier next to the FPGA; avoid a fan of long Dupont leads. A few centimetres is a useful layout goal, not a certified maximum. Prefer soldered perfboard for the final five-chip bus after proving one device. Fast edge rates matter even at a 10 MHz serial clock. Leave a place for an optional source-series resistor on SCK if scope measurements justify it; the agent should choose its value from observed waveforms rather than insert arbitrary delay into every data lane.

For incremental tests, keep unused chip adapters **fully disconnected from the bus**, not merely unpowered with signal wires attached. The final passive bus can be assembled now, but the agent needs a way to isolate adapters during fault finding.

## 5. Connect the carrier to the 3923 FPGA headers

The following mapping has been checked against the [official 3923 schematic](https://dl.sipeed.com/fileList/TANG/Nano_20K/2_Schematic/Tang_Nano_20K_3923_Schematics.pdf), PDF page 1. Find J5/J6 pin 1 from the physical board and schematic/pin drawing. **Do not infer left/right or count from a random online photograph**; the board may be rotated or shown from below. Have the agent annotate a photo of your actual board before final wiring.

| Carrier wire | FPGA header position | FPGA package pin | Goes to memory package pin |
|---|---|---:|---|
| SCK | **J6-1** | 73 | All chips pin 6 |
| CS_P0 | **J6-2** | 74 | P0 pin 1 |
| CS_P1 | **J6-5** | 77 | P1 pin 1 |
| CS_P2 | **J6-8** | 27 | P2 pin 1 |
| CS_P3 | **J6-9** | 28 | P3 pin 1 |
| CS_FLASH | **J6-10** | 25 | F pin 1 |
| DQ0 | **J6-11** | 26 | All chips pin 5 |
| DQ1 | **J6-12** | 29 | All chips pin 2 |
| RAM_IO2 | **J6-13** | 30 | P0–P3 pin 3 |
| RAM_IO3 | **J6-14** | 31 | P0–P3 pin 7 |
| FLASH_IO2 | **J5-6** | 41 | F pin 3 |
| FLASH_IO3 | **J5-5** | 42 | F pin 7 |
| RESET_N | **J5-18** | 71 | Reset switch/jumper, not a memory pin |
| MEM_3V3, if board-powered | **J6-19** | Supply, not FPGA GPIO | All chips pin 8 |
| GND | **J6-20** | Ground | All chips pin 4 and reset-switch return |

Connect RESET_N through a 10 kΩ pullup to the **board's 3.3 V rail**, and a switch/jumper from RESET_N to GND. Grounding RESET_N holds the SoC in reset; opening the switch releases it. This is a simple manual control; the hardware agent must check reset release behavior and any needed synchronization/debounce in its wrapper. Leave LCD/HDMI and other add-on peripherals detached while these shared header nets serve the memory bus.

The UART goes through the board's onboard BL616 and USB; no external TX/RX jumper is part of this carrier. CLK0 is also onboard; do not wire SCK to the board's clock-generator pin.

## 6. Check before the first connected power-up

- [ ] Each adapter label matches the physical chip, and each chip's pin 1 is identified.
- [ ] Every carrier wire measures through to the intended **chip leg**, not just an adapter label.
- [ ] No solder bridge/short between neighboring pins; no direct 3.3 V-to-ground short.
- [ ] Five independent CS nets; only the intended DQ groups are connected.
- [ ] Pull resistors have the specified destination and measured approximate resistance with power removed.
- [ ] Local capacitors are fitted; ground return is secure; no loose wire can reach the +5 V header.
- [ ] FPGA agent has demonstrated programming, clock, console, and safe memory-output states with carrier detached.
- [ ] Supply choice and current budget checked; circuit photographed from both sides.

Wire and rewire with power removed. Do not attach a powered FPGA signal bus to unpowered memories. For the first powered carrier test, use the agent's agreed setup and measure approximately 3.3 V **at each chip**, including during activity. Stop and remove power for unexpected heating, rail collapse, or unexplained current, then inspect rather than repeatedly rebooting.

The Espressif startup requirement is specific: CS must track VCC high, SCK and all four RAM DQ lines must stay low during the ramp and for **150 µs after stable supply**, followed by the reset command sequence. Resistors are intended to establish those states while FPGA pins are inactive; their actual effectiveness against FPGA configuration pulls must be checked. Holding our SoC reset does not control the factory bitstream or an unconfigured FPGA. The agent must establish a safe startup configuration before connecting the complete carrier for cold-power testing.

## 7. Work through the bench stages together

1. **FPGA alone:** plug USB into the iMac. The agent proves programming and UART echo, and configures the source clock to 20 MHz. Keep the carrier connector detached.
2. **P0 only:** connect the first PSRAM in the agreed safe startup setup. Run its memory test and inspect a transaction. Do not expect full Linux with three RAM chips missing.
3. **P1, P2, P3:** add one at a time, removing power between wiring changes. Repeat tests and confirm data written to one bank does not appear in another.
4. **NOR:** connect F and test single/quad reads. Program a small diagnostic using the agent's verified method, then the full checked Linux flash image. Keep the flash adapter/bus removable so an external programmer can be isolated from FPGA drivers.
5. **Linux:** release reset and log the console. Baseline acceptance takes about 11.6 minutes of cycle-equivalent time at 20 MHz. At `ASH> ` type `/bin/acceptance_smoke` and look for `ASH_PROGRAM_OK`. Save the whole boot log.
6. **Repeat:** test resets, full power cycles, and longer memory stress. A single successful boot is the first milestone; repeatability establishes whether the wiring is dependable.

There are two unrelated flash chips: the board's **FPGA configuration flash**, and your external **Winbond Linux boot flash**. Label them accordingly. Do not assume the standard FPGA programming command writes the external Winbond.

When using an external NOR programmer, reset alone is not electrical isolation: the FPGA can still drive SCK and chip selects. Disconnect/isolate those bus drivers and avoid powering the memory simultaneously from two sources. Let the agent select a programming procedure matched to your actual programmer.

Keep a short bench log: date, wiring revision/photo, which chips are attached, bitstream/image identifiers supplied by the agent, chip-pin voltage, test output, and any change. That will let us distinguish a wire repair from a firmware improvement and preserve the story of first hardware bring-up.
