# Physical memory map

The current `physical_bus` **test configuration** is an address decoder example. It does not reserve the final SoC addresses.

| Test window | Byte addresses | Capacity | Slave offset | Present hardware |
|---|---:|---:|---:|---|
| UART | `0x1000_0000..0x1000_0fff` | 4 KiB | base subtracted | simulation model only |
| Flash | `0x2000_0000..0x20ff_ffff` | 16 MiB | base subtracted | simulation model only |
| PSRAM | `0x8000_0000..0x81ff_ffff` | 32 MiB | base subtracted | simulation model only |

The four 8 MiB PSRAM chips will each need a separate chip select and a bank decode. Physical addresses enter the controller; the controller chooses chip 0–3 and the 23-bit per-chip address. A flash *read window* is useful, but executing directly from it is optional: boot firmware can copy code to PSRAM. Flash writes/erase require command operations and protection checks, not generic memory writes; the test model does not implement those semantics.

Still unassigned: reset ROM location and size, timer/interrupt registers, flash control registers, UART register interface, firmware-reserved RAM, Linux load address, device tree, and any shadow/alias windows. ROM must be reachable at the CPU reset vector. `Sv32` virtual addresses are process/kernel mappings and are separate from this physical map. Final addresses will be recorded only after the boot and Linux device-tree plan is tested.
