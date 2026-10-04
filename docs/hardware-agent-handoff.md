# Hardware agent handoff: Tang Nano 20K 3923 on the Ubuntu iMac

Prepared 2026-10-03 (Pacific). Owner assembles and measures the circuit; the hardware agent prepares the FPGA tools, bitstreams, diagnostics, image programming, and reproducible evidence. Start with the companion [circuit assembly guide](hardware-circuit-build-guide.md).

## Assignment to paste into the hardware agent

> Bring up our RV32 Linux SoC on the delivered Tang Nano 20K **PCB 3923**, permanently connected by USB to the Ubuntu iMac. Read `docs/hardware-agent-handoff.md` and `docs/hardware-circuit-build-guide.md`. Access the iMac through `ssh imac` from the Mac; `imac` in `~/.zshrc` wraps that connection. Help me build and check the circuit in small stages. Use four ESP-PSRAM64H chips and one W25Q128JVSIQ-TR. Build the qualified main RTL at `99cc34f07a6a0e0db938a1165639ea3b473e9bb4`, then prove real external-memory Linux boot and a command received through the physical UART. Keep FPGA experiments on a dedicated branch/worktree. Record the board, wiring, tool versions, source/image/bitstream hashes, timing reports, measurements, and UART logs. Start with host/tool inventory, a reproducible full-SoC FPGA fit, and a memory-disconnected clock/UART test while I assemble the memory carrier. Advance hardware stages only when the corresponding wiring and measurements are confirmed. Do not silently replace the external memories with onboard SDRAM or alter the production architecture to make a test pass.

## Confirmed starting point

| Item | Status |
|---|---|
| FPGA board | Owner confirms **3923**, not the provisional 3921 used in older repo notes |
| PSRAM | Four Espressif **ESP-PSRAM64H**, 8 MiB each, Adafruit 4677 / DigiKey 1528-4677-ND |
| Boot NOR | Winbond **W25Q128JVSIQ-TR**, 16 MiB, DigiKey 256-W25Q128JVSIQTRCT-ND |
| Bench host | `ssh imac` works; hostname `lx-imac`; Ubuntu 26.04 LTS, x86_64 |
| Existing remote checkout | `/home/carlos/rv32-linux-soc`, branch `codex/acceptance-pareto`, observed HEAD `e1a5edde95acf54e3d9c9753a2dbeae1d34d1c9e` |
| Host tools at handoff | `openFPGALoader`, `yosys`, `nextpnr-himbaechel`, `verilator`, `iverilog` were **not found on the noninteractive SSH PATH**; this does not exclude other installations or containers |
| USB at handoff | No FPGA programmer or `/dev/serial/by-id` device appeared in the inventory; repeat after connection |
| Hardware qualification | No FPGA fit, programmed bitstream, or successful physical memory/Linux test established yet |

The iMac already stores physical-design archives and has a Mac experiment mount. Preserve those directories and services. Its checkout is older than qualified main; a successful SSH connection is not evidence of matching source.

## Preserve the qualified baseline

Use **main commit `99cc34f07a6a0e0db938a1165639ea3b473e9bb4`** as the source baseline. The [main GDS workflow](https://github.com/georgc4/rv32-linux-soc/actions/runs/37164332128) passed GDS, precheck, gate-level test, and viewer. The [main Linux acceptance workflow](https://github.com/georgc4/rv32-linux-soc/actions/runs/37164332137) passed both strict digital memory profiles, using 2 ns / 6 ns output delays and 0x5A / 0xA5 initial PSRAM contents.

Both acceptance runs took **13,877,255,869 cycles**. At 20 MHz that is approximately **11 minutes 34 seconds** of cycle-equivalent time through the acceptance command. Allow a 20-minute initial hardware observation window, retain intermediate progress, and investigate a stall rather than repeatedly resetting during a quiet copy. The older roughly 9.9-billion-cycle experiment is not this qualified baseline.

These results prove the recorded simulations and ASIC flow gates. They do not establish FPGA timing, electrical memory timing, or breadboard reliability. The gate-level test was unit-delay, not a full extracted-delay board model.

On the iMac, inspect first, then create a separate worktree if it does not already exist:

```sh
ssh imac
cd /home/carlos/rv32-linux-soc
git status --short
git remote -v
git worktree list
git fetch origin
git worktree add -b codex/fpga-bringup ../rv32-linux-soc-fpga \
  99cc34f07a6a0e0db938a1165639ea3b473e9bb4
cd /home/carlos/rv32-linux-soc-fpga
```

Do not rerun `worktree add` over an existing branch/directory; inspect and reuse the matching hardware checkout. Fetch/import this handoff's documentation commit separately: it adds the two guides and `fpga/tang_nano_20k_3923.cst`; it does not change the baseline SoC RTL. Record both commits.

## FPGA implementation and Ubuntu setup

1. Inventory the FPGA package marking, USB IDs, serial interfaces, installed tools, available disk, and permissions. Save `uname`, `/etc/os-release`, `lsusb`, `/dev/serial/by-id`, `groups`, and tool versions. Use `ssh imac 'command'` for automation; the zsh helper is convenient interactively but is not needed in scripts.
2. Install a supported Linux Gowin synthesis/place-and-route flow, or a pinned Yosys + nextpnr-himbaechel + Apicula flow that supports the exact device. The schematic specifies **GW2AR-LV18QN88C8/I7**; verify the actual marking and the tool's device spelling. Do not assume the distribution's generic nextpnr package includes Gowin support. Record versions and installation procedure.
3. Install the native Linux programmer and serial tools. Check `openFPGALoader --list-boards` for `tangnano20k`. Use the programmer's documented udev rules and serial group permissions; reconnect/re-login where required. Avoid making every USB/TTY device world-writable. Keep one process owning the programmer/console at a time.
4. Build a standalone pin-safe clock/UART diagnostic first. The full-SoC build can proceed independently while the carrier is assembled. Report LUT/register/BRAM use, placement success, unconstrained paths, and achieved timing at 20 MHz. A source simulation is not an FPGA fit.
5. For the production build, select the baseline **`src/*.v`** and the FPGA wrapper; do not mix in duplicate modules from `rtl/`. Exclude simulation memory models. Existing wrapper `fpga/tang_nano_20k_3921_soc.v`, top `tang_nano_20k_3921_soc`, directly instantiates `soc_top` and six tristate pads. Its legacy name is not a pin constraint: pair it with the new **3923 CST**, or rename the wrapper on the hardware branch without changing its behavior. Keep `DIAGNOSTIC_MODE=0` and `PSRAM_POWERUP_CYCLES=3000` for production acceptance.
6. Preserve `firmware/boot_rom.hex` and its synthesis working-directory resolution. SHA-256 is `b068293a2a31ebd3444a3a58f567c9e88b14b8bf88aab73a681dad9b9fac229d`. Check that ROM initialization reaches the synthesized design. Existing `fpga/tang_nano_20k_3921.sdc` specifies the 50 ns clock; supplement external I/O timing for the FPGA implementation using the memory datasheets and measured wiring. Do not describe that clock-only file as complete I/O timing closure.

If FPGA fitting requires a logic change, identify the specific limitation and propose a separately tested change. Preserve the qualified design for comparison. Onboard SDRAM can support a separate diagnostic, but cannot count as validation of our external-memory controller.

### Clock, reset, console, and programming

The 3923 schematic connects MS5351 CLK0 to FPGA pin 10, FPGA UART TX pin 69 to BL616 RX, and FPGA UART RX pin 70 to BL616 TX. There is no extra USB-UART module required. SoC reset is our external active-low input on **J5-18 / FPGA 71**, not an assumed onboard reset button.

Identify the serial interface by unplug/replug comparison. Open it at **115200, 8N1, no flow control, local echo off**, with timestamped logging. Sipeed documents entering the BL616 console with Ctrl-X, Ctrl-C, Enter. In that console:

```text
pll_clk O0=20M -s
pll_clk
choose uart
```

`O0` is letter O followed by zero. Confirm firmware accepts the commands. Verify the resulting clock with a scope or a known clock-divider diagnostic; do not probe fine-pitch FPGA leads by hand. Hold the SoC in reset until clock and memory power are stable. The board also has a 27 MHz oscillator on a different pin: do not accidentally build against that clock.

After checking the installed programmer's board support and the bitstream's provenance, the normal volatile load form is:

```sh
openFPGALoader -b tangnano20k build/fpga/soc.fs
```

This is a command template; `soc.fs` must first be built. Per [openFPGALoader documentation](https://trabucayre.github.io/openFPGALoader/guide/first-steps.html), `-f` targets persistent FPGA configuration flash. **Neither operation writes our separate 16 MiB Winbond Linux flash.** Start with SRAM loading and disconnected memories. Before connected cold-power tests, establish a safe persistent FPGA boot configuration or physical isolation: an SRAM-only test disappears at power loss and the factory bitstream may return.

## Hardware stages and exit criteria

| Stage | Agent work / owner work | Evidence needed before advancing |
|---|---|---|
| 0: identity and carrier | Confirm 3923 header orientation and actual chip markings; owner assembles passive carrier per companion guide | Annotated photos, pin-by-pin continuity, supply choice/current budget, no shorts |
| 1: FPGA alone | Build/load clock-divider and UART echo diagnostic with memory connector detached | Repeatable programming, verified 20 MHz source, physical UART TX and RX, known safe memory-pin states |
| 2: one PSRAM | Owner connects PSRAM0 only; agent runs a separate bounded-transaction tester | Correct initialization, single-SPI and production quad read/write, address/data patterns and idle-retention checks |
| 3: four PSRAMs | Add one chip at a time; run the same controller and bank-select mapping | Independent data in each 8 MiB bank; no aliases, boundary/byte-enable tests, long stress run |
| 4: NOR and boot smoke | Connect flash; read identity/status, program a small boot payload and verify readback | Correct ID/capacity, reliable single/quad reads, production ROM copies payload into PSRAM and emits expected UART output |
| 5: full Linux | Program the pinned full flash image; load production SoC; release reset after stable power/clock | Real cold boot to `ASH> `, actual RX command `/bin/acceptance_smoke`, TX response `ASH_PROGRAM_OK` |
| 6: repeatability | Run at least 10 reset boots and 10 full power-cycle boots, then memory/CPU stress | Per-run pass/fail, timing and voltage measurements, preserved logs; proposed engineering target, not already achieved |

Use production-controller quad tests as well as a simple SPI tester. A NOR ID read alone does not prove quad routing. For PSRAM test walking ones/zeros, address-derived patterns, 0x00/FF/55/AA, pseudorandom data, byte lanes, and delayed readback. Verify all bank boundaries at physical bases **0x80000000, 0x80800000, 0x81000000, 0x81800000**, ending at **0x81FFFFFF**, and the 1 KiB page boundaries within each chip. Destructive whole-RAM tests run in a dedicated tester/firmware environment, not over a running Linux kernel.

Production timing is **20 MHz core, approximately 10 MHz active serial clock**; measure actual waveforms. The PSRAM maximum CS-low interval is **8 µs**, including pauses. Do not lower the whole SoC clock as a generic debug remedy: this changes initialization, UART/timebase behavior and can violate that interval. A slower standalone tester must still calculate its transaction length and obey CS limits. Use the datasheet reset sequence; four data wires do not mean that the controller uses QPI command framing.

For a small production-ROM test, inspect `make image-smoke`, `scripts/make_flash_image.py`, and `sim/programs/rv32i_smoke.S` at the pinned revision. It packages an RVSB header plus payload; the smoke firmware reports `OK` and stores its signature. **Its existing terminal `ebreak` is intended for diagnostic simulation:** for a standalone production-core bench payload, implement an explicit success/failure loop or trap handler in the firmware and test it first. Do not assume `ebreak` halts a production core. Keep `DIAGNOSTIC_MODE=0`; record the diagnostic firmware separately from the unchanged Linux image.

The existing `make test-physical-uart` checks pin-level UART behavior with a small test harness. It is useful regression coverage, not full staged-source FPGA or board qualification.

## Pinned Linux image and external NOR programming

Extract the already-tested image in the hardware worktree rather than rebuilding Linux during first bring-up:

```sh
python3 - <<'PY'
from pathlib import Path
import hashlib, lzma
data = lzma.decompress(Path('sim/fixtures/linux-acceptance/flash.bin.xz').read_bytes())
expected = '590ed63886833648537907532aac191c210e3eb4e36e300c99c4de4707e6f615'
assert len(data) == 16_777_216
assert hashlib.sha256(data).hexdigest() == expected
out = Path('build/hardware/flash.bin')
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(data)
print(out, len(data), expected)
PY
```

Program that binary at **NOR offset zero**, using a verified 3.3 V external flash programmer or a separate FPGA flash-programmer bitstream that the agent must implement/test. Check available hardware before choosing a method. The image's RVSB/LNX1 headers and offsets are already packaged; do not program only the kernel `Image`, compressed `.xz`, or ASCII `.hex`. Back up existing NOR contents before erasure, then verify a full binary readback against the image hash. Do not change protection/OTP bits indiscriminately.

External programming must electrically isolate competing drivers. **Holding SoC reset does not tristate its SCK and chip-select outputs.** Use removable bus links or a proven all-outputs-Hi-Z configuration, and prevent programmer/board supply backfeeding. Restore the normal bus before boot. Observe the NOR power-up write delay and busy polling from its datasheet; the production boot path reads NOR and does not itself solve flash-programmer timing.

Expected UART milestones are `L` from the loader, `B` before Linux entry, `RV32 Linux userspace ready`, then `ASH> `. Send `/bin/acceptance_smoke` followed by newline and save `ASH_PROGRAM_OK`. ROM `E` indicates header/checksum failure; loader `H`, `D`, `K`, `T` indicate header/bounds, DTB checksum, kernel checksum, or unexpected trap respectively. An acceptance marker printed by the simulator harness is not a byte expected from the physical chip.

## Measurement and debugging priorities

First measure rails and confirm the clock/console. Then capture SCK, the selected CS, and the appropriate DQ group. Verify only one memory is selected; measure turnaround and sample edge at the receiving chip. An 8-channel analyzer cannot capture SCK + five selects + six DQs simultaneously: select channels for the failing transaction, and use a scope for voltage/ringing. Software CRCs do not replace analog measurements.

PSRAM power-up requires more than a delay counter: confirm the actual pins stay in their required states throughout supply ramp and FPGA configuration. Pull resistor values in the build guide are initial engineering choices, not measured guarantees. If stock FPGA startup, weak internal pulls, or rail sequencing violate those states, implement a safe persistent configuration and/or proper isolation/power sequencing before claiming cold-boot success.

Keep a diagnostic hierarchy: cable/USB access → FPGA clock and serial bridge → GPIO mapping → power and chip-select behavior → single SPI → quad SPI → per-bank RAM → ROM payload → Linux. Do not start by changing CPU RTL for a missing flash response. If single SPI works but quad fails, inspect the split IO2/IO3 groups, direction changes, and mode first.

## Deliverables and record keeping

Commit build scripts, source manifests, board-specific constraints, diagnostic firmware, tests, and the evolving bench journal on `codex/fpga-bringup`. Add suitable build/simulation regressions to CI before proposing production RTL changes. Keep large captures under ignored `build/hardware/` with paths/hashes recorded in a committed manifest; copy important evidence to durable storage before cleanup.

For every claimed pass record: source commit and dirty diff, FPGA device/PCB, tool versions, exact source list, CST/SDC/ROM/flash/bitstream hashes, utilization and timing report, actual clock, wiring revision/photo, supply source and loaded voltage, initialization/transaction traces, UART log, cold/reset boot distinction, and failure count. Include unsuccessful attempts and the decision they motivated. Hardware validation supplements ASIC signoff; any production RTL change must rerun the appropriate simulation and GDS gates.

First report should state: iMac tool readiness; whether the exact SoC fits and meets FPGA timing; verified header orientation/power plan; which assembly stage the owner can complete next; and any specific missing adapter, programmer, or measurement tool. Do useful software work while waiting for physical assembly.

## Source references

- [Sipeed 3923 schematic](https://dl.sipeed.com/fileList/TANG/Nano_20K/2_Schematic/Tang_Nano_20K_3923_Schematics.pdf): six PDF pages, main sheet dated 2025-08-28, rev 1.3. SHA-256 `0b8ea0722c7f04a1785071f55e564a14d1a9923d7a33a6162663aba45b3f332f`. Main/header page 1, power page 2, BL616 page 3, MS5351 page 6. Printed sheet IDs are inconsistent; use PDF page positions.
- [Sipeed BL616 clock/console instructions](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/unbox.html).
- [Espressif PSRAM datasheet, hosted with Adafruit 4677](https://cdn-shop.adafruit.com/product-files/4677/4677_esp-psram64_esp-psram64h_datasheet_en.pdf), v1.0: pinout printed p2, startup p3, transactions pp6–15, timing p19.
- [Winbond W25Q128JV datasheet](https://www.winbond.com/resource-files/w25q128jv%20revf%2003272018%20plus.pdf), rev F: package-S pinout printed p5, ordering pp74–75.
- Repo [boot chain](boot/boot-chain.md), [FPGA wrapper](../fpga/tang_nano_20k_3921_soc.v), [3923 CST](../fpga/tang_nano_20k_3923.cst). At qualified main, also read `docs/verification/datasheet-memory-models.md` and `scripts/linux_datasheet_ci.py`.
