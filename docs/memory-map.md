# Physical memory map in the integrated RTL

| Device | Byte addresses | Size | Implemented behavior |
|---|---:|---:|---|
| Boot ROM | `0x0000_0000..0x0000_0fff` | 4 KiB window | 11 populated words; out-of-image access faults |
| CLINT-like timer | `0x0200_0000..0x0200_ffff` | 64 KiB | `msip`, `mtimecmp`, `mtime` at standard offsets |
| UART | `0x1000_0000..0x1000_0fff` | 4 KiB | 16550-like byte registers at 4-byte spacing |
| NOR control | `0x1000_1000..0x1000_1fff` | 4 KiB | address/data/command/status registers; serialized with memory SPI |
| NOR flash | `0x2000_0000..0x20ff_ffff` | 16 MiB | standard SPI `03h` reads; ordinary writes fault |
| PSRAM | `0x8000_0000..0x81ff_ffff` | 32 MiB | four 8 MiB banks, standard SPI `03h`/`02h` |

The bus gives each selected slave a byte offset within its window. The PSRAM bridge uses offset bits 24:23 to select one of four chips and bits 22:0 for the chip address. Each request reads an aligned 32-bit word; byte strobes select individual PSRAM writes. The SPI bridge completes each write as a separate one-byte transaction. This is functional but slow; it has no cache or burst buffer.

The NOR control registers are at offsets `+0x0` (24-bit byte address, full-word write), `+0x4` (one-byte program data), `+0x8` (command write or last status read), and `+0xc` (diagnostic status). Commands are `1` for one-byte page program, `2` for aligned 4 KiB sector erase, and `3` for status read. Program and erase issue `06h` write enable, the operation command, and `05h` status polls until WIP clears; the bus response waits for completion or a poll timeout. Ordinary writes to the flash read window fault. This does not yet include a protected image layout, validation, or UART update firmware.

The ROM accepts a bounded word count and checksum in a 16-byte flash header, copies the payload to PSRAM, and jumps there. The test image contains 88 words. It is not a Linux bootloader.
