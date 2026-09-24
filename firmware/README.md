# Firmware

`boot_rom.S` is the immutable 27-word first stage. `make regen-rom` assembles it to `boot_rom.hex`, inferred as logic by `rtl/peripherals/boot_rom.v`. It checks an RVSB header, copies a bounded payload from NOR into PSRAM, verifies a 32-bit word sum, and jumps to physical `0x80000000`. A bad image emits `E` over UART and loops.

`linux_loader_entry.S` and `linux_loader.c` are the resident M-mode Linux loader. `make image-linux-flash` compiles them, packs them with the DTB and Linux Image, and writes the 16 MiB `build/linux/flash.bin`. The loader copies and verifies both payloads, enters S-mode, and handles SBI v0.2 BASE and TIME calls. See [boot flow](../docs/boot-flow.md) for addresses and the tested handoff. `make test-linux-handoff` tests a small kernel-shaped S-mode payload; Linux itself has not run in the RTL simulator.

`make image-smoke` still builds the small diagnostic flash image. The flash controller can erase and program NOR through memory-mapped commands, but no UART updater or recovery protocol exists.
