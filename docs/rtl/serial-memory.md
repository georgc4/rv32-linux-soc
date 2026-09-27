# Serial PSRAM and NOR controller

**Sources:** [`serial_mem_bridge.v`](../../rtl/memory/serial_mem_bridge.v), [`serial_spi_model.v`](../../sim/models/serial_spi_model.v). The bridge is the only production interface to external RAM and flash. It does not use a parallel behavioral memory in the integrated Linux gate.

## Electrical lane plan and arbitration

There are five active-low chip selects: PSRAM 0–3 and NOR. DQ0 is the shared command/data input lane and DQ1 the shared serial output lane. DQ2–3 belong to PSRAM quad transfers; DQ4–5 belong to NOR quad output. At most one CS is low. `spi_dq_oe` controls which SoC lanes drive in each phase; reset and idle release them. The bridge gives RAM requests priority, then flash-window requests, then NOR-control requests. It accepts one request and does not accept another until its response is consumed. `selected_flash` routes the shared `DONE` response to the correct logical port.

After reset, `POWER_WAIT` counts `POWERUP_CYCLES` SoC clocks, then sends `66h` and `99h` separately to each PSRAM chip. `initialized` rises after the fourth reset sequence. The production parameter is 3000 clocks; at 20 MHz the count is 150 µs. Actual device power-up and reset requirements must be checked against the purchased parts and board supply ramp. The bridge comment also notes the PSRAM CS-low maximum; a slower clock or enlarged transaction must be checked against that constraint.

## Transfer engine

`SETUP` prepares pins, `HIGH` raises SCK and samples input, `LOW` lowers SCK and advances the command/address/data selector. A `GAP` keeps CS high between commands. `DONE` and `CTRL_DONE` hold response valid until the corresponding response-ready handshake. SCK toggles once per `HIGH`/`LOW` pair, so its nominal transfer frequency is half the SoC clock. Bit indices in RTL count **SCK cycles**, even when a cycle carries a nibble on four lines. The command phase is single-lane; selected address/data phases are quad. The byte reorder converts serial most-significant-byte-first data into the little-endian 32-bit bus word.

| Operation | Opcode | SCK cycles while CS is low | Lanes and purpose |
|---|---:|---:|---|
| PSRAM 32-bit read | `EBh` | 28 | 8 single-lane command + 6 quad address + 6 turnaround/wait + 8 quad data |
| PSRAM full-word write | `38h` | 22 | 8 single-lane command + 6 quad address + 8 quad data |
| PSRAM selected-byte write | `38h` | 16 per byte | 8 single-lane command + 6 quad address + 2 quad data; each selected byte is its own CS transaction |
| NOR 32-bit read | `6Bh` | 48 | 8 single-lane command + 24 single-lane address + 8 dummy + 8 quad data |
| NOR write-enable | `06h` | 8 | single-lane command |
| NOR byte program | `02h` | 40 | command + 24-bit address + one byte, single-lane |
| NOR sector erase | `20h` | 32 | command + address, single-lane |
| NOR status read | `05h` | 16 | command + one serial status byte |

For RAM, offset bits `[24:23]` select one of four 8 MiB chips and `[22:0]` are the chip byte address. The bridge aligns a read to a word. Full-word writes issue one command; partial writes iterate only the asserted byte lanes, using the individual byte address. Zero-strobe writes return an error. A request beyond the 32 MiB offset range errors. The NOR window covers 16 MiB, is read-only, and aligns its serial read to a word; writes to that window error. The physical bus supplies the window-relative offset.

The NOR-control block has four word-spaced registers. `+0x0` holds a 24-bit address and requires a full-word write with zero top byte. `+0x4` holds one program byte. Writing command `1` to `+0x8` starts write-enable, byte program, then status polls; command `2` erases an aligned 4 KiB sector; command `3` reads status. `+0xc` exposes diagnostic operation/poll/status fields. Program and erase return only after WIP clears or a bounded poll count expires. An unaligned erase or malformed strobe errors. This is a primitive controller, not a filesystem, wear-leveling layer, or boot-update protocol.

## Area changes and throughput limits

The bridge retains one `read_shift` register and combinationally reorders it for the response rather than keeping a duplicate response word. `serial_write_word` is built from the retained write word or selected byte. The power-up counter width is derived from the configured count instead of a fixed wide counter. These are RTL area changes, with separate commit-pinned synthesis and Linux acceptance evidence in [experiments](../experiments/method.md).

The bridge has no cache, line fill, read burst, write buffer, or overlap between requests. An instruction fetch from PSRAM can require a 28-SCK-cycle transaction plus bus/core overhead; a TLB miss adds PTE reads and perhaps a PTE write. This is a major source of boot cycles. The digital SPI model verifies pin-level command and data phases but not setup/hold, voltage, package parasitics, pullups, or analog contention. [Verification](../verification/tests-and-models.md) lists the exact test scope.
