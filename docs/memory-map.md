# Physical memory map in the integrated RTL

| Device | Byte addresses | Size | Implemented behavior |
|---|---:|---:|---|
| Boot ROM | `0x0000_0000..0x0000_0fff` | 4 KiB window | 11 populated words; out-of-image access faults |
| CLINT-like timer | `0x0200_0000..0x0200_ffff` | 64 KiB | `msip`, `mtimecmp`, `mtime` at standard offsets |
| UART | `0x1000_0000..0x1000_0fff` | 4 KiB | 16550-like byte registers at 4-byte spacing |
| NOR flash | `0x2000_0000..0x20ff_ffff` | 16 MiB | standard SPI `03h` reads; ordinary writes fault |
| PSRAM | `0x8000_0000..0x81ff_ffff` | 32 MiB | four 8 MiB banks, standard SPI `03h`/`02h` |

The bus gives each selected slave a byte offset within its window. The PSRAM bridge uses offset bits 24:23 to select one of four chips and bits 22:0 for the chip address. Each request reads an aligned 32-bit word; byte strobes select individual PSRAM writes. The SPI bridge completes each write as a separate one-byte transaction. This is functional but slow; it has no cache or burst buffer.

The flash controller has no erase/program commands, image verification, or UART update path. The ROM currently copies exactly 88 diagnostic words from flash to PSRAM and jumps there. It is not a Linux bootloader.
