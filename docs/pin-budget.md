# External signal budget (logical allocation, no pad numbers)

Tiny Tapeout's general interface advertises 8 input-only (`ui_in`), 8 output-only (`uo_out`), and 8 bidirectional (`uio`) signals plus framework clock/reset. The **proposed** logical count is:

| Signal | Count | Direction at SoC | Reset/startup | Tentative class |
|---|---:|---|---|---|
| Shared memory DQ[3:0] | 4 | bidirectional | high impedance until initialized | `uio` |
| Memory SCK | 1 | output | low while CS inactive | `uo_out` |
| PSRAM CS# ×4 | 4 | output | high; external pull-up under study | `uo_out` |
| NOR CS# | 1 | output | high; external pull-up under study | `uo_out` |
| UART TX | 1 | output | mark/idle high | `uo_out` |
| UART RX | 1 | input | idle high from host | `ui_in` |

Count: 4/8 bidirectional, 7/8 output-only, 1/8 input-only. This **count fits** the usual interface. It is not a verified wiring design. Chip datasheets must confirm selected SPI/QPI modes, non-selected output high impedance, DQ2/DQ3 functions during boot and command transitions, timing, reset behavior, and safe sharing among all five ICs. Assigning SCK and CS# to output-only pins assumes the target shuttle routes them as expected. No FPGA pin numbers are selected until the delivered board revision and schematic are checked.

Flash programming path proposal: boot ROM accepts a framed image over UART, validates length/checksum, erases/programs/verifies NOR through the same internal controller, and boots it after reset. An initial external programmer can preprogram the SOIC device as a recovery path. Directly driving the shared memory wires from a programmer while the ASIC is active would risk contention and is not assumed. A UART recovery mode needs a trigger, perhaps an image-validity check or a command window; its exact mechanism is open.

Electrical gates: both memory variants are nominal 3.3 V devices. The general Tiny Tapeout SKY130 GPIO page lists a 3.3 V demo-board I/O supply, 4 mA drive strength and a 33 MHz output rating; the five-device fanout and actual SKY26d pad implementation still need checking. Verify operating ranges, FPGA bank voltages, pull-ups, regulator capacity, and a common ground. Confirm SOIC width/orientation and place real 100 nF ceramics near **each** device before breadboard bring-up. The kit label “104 pF” is ambiguous and is not a substitute. Approximate 10 kΩ CS# pull-ups remain to be checked against device leakage and rise-time data.
