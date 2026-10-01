# Datasheet memory experiments

The purchased parts are **four Espressif ESP-PSRAM64H (Adafruit 4677)** and
**one Winbond W25Q128JVSIQ-TR**. No additional datasheets are needed to run these
experiments. This is a digital model of the SoC's memory interface, not a claim
that every feature or the analog behavior of either chip has been emulated.

## Sources and electrical assumptions

Reviewed 2026-09-30:

* Espressif **2018.06 V1.0**, [manufacturer PDF hosted by Adafruit for product 4677](https://cdn-shop.adafruit.com/product-files/4677/4677_esp-psram64_esp-psram64h_datasheet_en.pdf).
  Sections 3, 5–8 and table 10-5 define initialization, commands and timing.
  Espressif's older public document URL currently redirects to a missing page.
* Winbond **Revision F, 2018-03-27**, [manufacturer PDF](https://www.winbond.com/resource-files/w25q128jv%20revf%2003272018%20plus.pdf).
  Sections 7, 8 and 9.3/9.6 define WEL/BUSY, framing, page programming and timing.
  SIQ is the fixed-QE ordering option; register-2 reads report QE=1.

Downloaded PDF SHA-256 values (documents kept in ignored `build/datasheets/`):

* PSRAM: `88b9a9535c699a97dc8c6fd123cb58829c39812dbdd641067d4ed9988602a011`
* NOR: `809f066e62bcde10b12c2202daf05f4776929ad7dc5f9d3b5131cdcc84502bc1`

Simulation time zero represents stable device supply. Board pull-downs on the
PSRAM data pins and pull-ups on CS are assumed. The model checks driven PSRAM
inputs and the shared clock during the startup interval; it cannot verify that
those physical resistors, supply ramps or pad voltages actually exist.

| Property | ESP-PSRAM64H | W25Q128JVSIQ |
| --- | --- | --- |
| Physical capacity | 8 MiB per chip | 16 MiB |
| Startup | 150 us then consecutive 66h/99h | Reads after 20 us; writes after 5 ms |
| Input setup / hold | 2 / 2 ns | 1 / 2 ns |
| CS setup / hold | 2.5 / 20 ns | 3 / 3 ns |
| CS high | 50 ns | 10 ns after reads, 50 ns around modeled write operations |
| CS low limit | 8 us, including a stalled clock | No corresponding refresh limit |
| Output delay | 6 ns maximum tested; 2 ns fast profile | 6 ns maximum tested; 2 ns fast profile |
| Output release delay | 6 ns | 7 ns |
| Program duration | Immediate RAM writes | 0.4 ms typical, 3 ms maximum |
| 4 KiB erase duration | Not applicable | 45 ms typical, 400 ms maximum |

Clock checks use the flash 133 MHz supply-range assumption (3.0–3.6 V) and the
PSRAM 84 MHz linear-page-crossing limit. Read-03h limits are checked separately.
The actual controller test runs at **20 MHz core / 10 MHz serial clock**. These
checks do not characterize five-device loading, analog slew or the carrier.
The fast flash output profile is within its legal range, not its 1.5 ns minimum.

## What changed

`sim/models/serial_memory_datasheet_model.v` is separate from the old accelerated
functional model so existing long Linux runs keep their established performance.
The strict CI matrix uses real array capacities, with distinct writes to the last
word of all four PSRAM chips followed by readback, and a top-of-NOR read. Smaller
allocations in model unit tests and gate boot tests **fail** on out-of-allocation
access instead of silently aliasing the address modulo a tiny array.

The strict model implements SPI mode 0:

* PSRAM: 66h, 99h, 03h, 0Bh, EBh, 02h and 38h; serial versus quad address/data
  phases and dummy cycles; linear page crossing; A23 ignored by the 8 MiB part;
  unknown initial contents; reset preserves memory contents.
* NOR: 03h, 0Bh, 6Bh, 05h, 35h (fixed QE), 06h, 04h, 02h and 20h; WREN takes
  effect at CS rising; program/erase starts only after a correctly terminated
  frame and WEL; a partial final program byte aborts the entire operation.
  Page programming wraps within 256 bytes and can only clear stored bits.
  Erase aligns to the containing 4 KiB sector. BUSY expires by elapsed time,
  independently of how often software polls. Array changes become visible at
  completion; ignored commands during BUSY cannot corrupt the pending page.
* Delayed read outputs and delayed release of output enables, active-input
  setup/hold and drive checks, CS setup/hold/high time, clock period/pulse width,
  startup/reset checks, and PSRAM refresh-starvation checks.

Unsupported commands fail explicitly when the device is receptive. Valid but
unmodeled operations therefore cannot silently pass. This is deliberately not
called a complete vendor model. QPI mode, wrap-toggle mode, IDs, suspend/resume,
deep power-down, security/OTP/protection registers, flash software reset, mode 3,
power-loss effects and wear/retention are not implemented. The existing SoC does
not issue those commands. Winbond lists a vendor Verilog model, but its public
download endpoint did not return the model during this work; no vendor source
or unreviewed licensed model has been copied into the repository.

## CI experiments

`fast-checks` runs three independent memory jobs:

1. Typical program/erase duration, 6 ns read output delay.
2. Maximum program/erase duration, 6 ns read output delay.
3. Maximum program/erase duration, 2 ns read output delay.

Every job runs the model self-tests first. These exercise flash commit semantics,
page wrap, one-to-zero programming, missing WEL, malformed program termination,
BUSY command rejection, elapsed completion without polls, erase, WRDI, linear
PSRAM page crossing and retained contents after reset. Output timing/release is
checked directly. Deliberately bad inputs must fail with the exact expected
reason (power-up, reset, input setup/hold, CS timing, clock, unsupported opcode,
undriven input or model allocation). A simulator crash is not accepted as a
successful negative test.

Reproduce with `make test-memory-model` and `make test-memory-datasheet`.
Set `DATASHEET_WORST=0` for typical latency or `DATASHEET_OUTPUT=2.0` for the fast
output profile. The maximum-latency test simulates over 400 ms; there is no
poll-count shortcut.

`serial-boot-pins` runs the production staged wrapper and ROM against these same
strict chip models. The unchanged GDS workflow's `gl_test` uses the same testbench
with its generated gate netlist. It boots the checked-in 88-word CPU diagnostic
from NOR, copies it through the real pins to PSRAM, executes it, checks UART
`OK\n` and RAM signature `0x5a5aa5a5`, then resets with a bad checksum and requires
UART `E`. No internal DUT force, diagnostic-mode override or ROM replacement is
used. `test/requirements.txt` pins cocotb 2.0.1 for both jobs; without it the
upstream GL action defaults to the incompatible 1.8 API. The existing GL action
uses **unit cell delays**, not extracted SDF; routed
STA and physical verification remain separate required gates. A passing RTL test
must not be reported as a passing gate-level test.

## Finding: separate NOR write readiness

The controller's 150 us PSRAM initialization delay does not cover the NOR's
5 ms write-inhibit interval. The ROM only reads NOR, so boot is unaffected.
The strict write test deliberately waits until 5 ms; an independent negative
test demonstrates that early writes are rejected. The current controller has
no separate hardware write-readiness guard. Any firmware using its programming
registers must wait for tPUW, or a later RTL change must add that guard. This is
an explicit interface limitation, not a condition hidden by the passing test.

These experiments do not close the provisional external I/O STA budgets. Actual
pad/carrier delays, fanout, ringing and supply sequencing still require board
information or measurement. Linux acceptance is also a separate qualification;
the short boot program does not replace it.
