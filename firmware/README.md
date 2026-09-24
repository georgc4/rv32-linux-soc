# Firmware

`boot_rom.S` is the immutable 27-word first stage. `make regen-rom` assembles it to `boot_rom.hex`, which is inferred as logic by `rtl/peripherals/boot_rom.v`. It checks an RVSB header, copies a bounded payload from NOR into PSRAM, verifies a 32-bit word sum, and jumps to physical `0x8000_0000`. A bad image emits `E` over UART and loops.

`make image-smoke` builds `build/rv32i_smoke.flash.bin` from the diagnostic payload. The header format and ROM path are documented in `docs/boot-flow.md`. The flash controller can erase and program NOR through memory-mapped commands, but no UART updater, M-mode SBI runtime, Linux loader, or device tree exists yet.
