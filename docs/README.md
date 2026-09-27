# Engineering handbook

This is the current, source-grounded guide to the RV32 Linux SoC. It describes the checked-in RTL and software as of the revision that contains this page. An experiment result applies only to its recorded Git commit, flash image, PDK, tool versions, constraints, and checks. The RTL is the authority for implementation details; the generated image and run logs are the authority for a particular test result.

## Reading paths

| If you want to understand… | Start here | Continue with |
|---|---|---|
| The entire computer | [System architecture](system/architecture.md) | [Bus and address map](system/bus-and-address-map.md), [boot chain](boot/boot-chain.md) |
| An instruction from fetch to retirement | [CPU core](rtl/cpu-core.md) | [MDU and privilege](rtl/mdu-and-privilege.md), [Sv32](rtl/sv32.md) |
| A specific instruction or byte crossing modules | [Transaction walkthroughs](rtl/transaction-walkthroughs.md) | [Debugging and reproduction](verification/debugging-and-reproduction.md) |
| A Linux load from external memory | [Sv32](rtl/sv32.md) | [Serial memory](rtl/serial-memory.md), [physical bus](system/bus-and-address-map.md) |
| A character at the serial terminal | [Peripherals](rtl/peripherals.md) | [Platform integration and pins](rtl/integration-and-pins.md), [verification](verification/tests-and-models.md) |
| How Linux is built and boots | [Boot chain](boot/boot-chain.md) | [Linux image and programs](boot/linux-image-and-programs.md) |
| What is known about fabrication | [Physical flow and signoff](physical/flow-and-evidence.md) | [Power, clock, and IO](physical/power-clock-and-io.md), [register-file layout](physical/register-file-layout.md) |
| How to design the custom bitcell | [Register-file layout](physical/register-file-layout.md) | [Bitcell design procedure](physical/bitcell-design-procedure.md) |
| Which viewers and diagrams to open | [Tools and views](tools-and-views.md) | [RTL source map](reference/source-map.md) |
| How design choices are measured | [Experiment method](experiments/method.md) | [Results](../experiments/RESULTS.md), [next-session plan](../experiments/NEXT-SESSION.md) |
| Where a function lives | [Source map](reference/source-map.md) | [Glossary](reference/glossary.md) |

## Evidence vocabulary

- **Implemented** means the behavior is present in a named source file. It does not imply that every corner case has been proven.
- **Simulated** means a named testbench exercised it. The serial Linux acceptance test models every SPI transfer at the pins, but it is digital and does not model analog signal integrity.
- **Mapped** means Yosys converted logic to SKY130 standard cells. Its cell area is not floorplan area or routed area.
- **Routed** means a physical run produced GDS. A routed file still needs the separate DRC, LVS, antenna, and timing checks listed in [physical flow](physical/flow-and-evidence.md).
- **Board verified** would mean a real FPGA or demoboard test. Neither board path should be inferred from simulation alone.

## Current design boundary

The production path is `tt_um_rv32_linux_soc` → `soc_top` → core, Sv32, bus, peripherals, and serial bridge. It uses four external 8 MiB PSRAM chips and one 16 MiB NOR chip. A 20 MHz clock and 50 ns target underlie the firmware, device tree, UART reset divisor, and shuttle experiments. The custom transistor bitcell and OpenRAM trials are research branches; neither is wired into the production register file.

The older top-level pages in `docs/` record the project’s evolution. Prefer this handbook for the current hierarchy, especially where old pages mention an earlier TLB size, userspace milestone, or provisional pinout. Architecture decision records in [`adr/`](adr/) preserve why earlier choices were made. Experiment logs and JSON under ignored `build/experiments/` are more precise than narrative snapshots for any individual run.

## What this handbook deliberately does not claim

There is no measured chip power, IR-drop, electromigration, silicon frequency, analog IO margin, or successful FPGA board bring-up in this repository. The 8T bitcell has no completed array, extracted characterization, or signoff. A nominal 50 ns constraint is a design target; it is not a guarantee that a routed chip meets 20 MHz. Each physical experiment must be judged on its own final artifacts.
