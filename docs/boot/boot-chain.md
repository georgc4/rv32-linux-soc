# From reset to an interactive shell

**Sources:** [`boot_rom.S`](../../firmware/boot_rom.S), [`linux_loader_entry.S`](../../firmware/linux_loader_entry.S), [`linux_loader.c`](../../firmware/linux_loader.c), [`pack_linux_flash.py`](../../scripts/pack_linux_flash.py), [`linux/init`](../../linux/init).

```mermaid
flowchart LR
  RESET[Reset PC 0] --> ROM[27-word ROM]
  ROM -->|RVSB header/checksum| LOADER[M-mode loader in PSRAM]
  LOADER -->|LNX1 manifest/checksums| IMAGE[Linux Image at 0x80400000]
  LOADER -->|mret, a0/a1| KERNEL[Linux S-mode]
  IMAGE --> KERNEL
  KERNEL --> INIT[Embedded /init]
  INIT --> ASH[BusyBox ash on ttyS0]
  ASH --> PROGRAM[/bin/acceptance_smoke]
```

## Flash layout

| NOR offset | Contents | Validation |
|---:|---|---|
| `0x000000` | 16-byte `RVSB` header: magic `0x52565342`, firmware word count, additive word checksum, reserved word | ROM checks magic, count 1–65535, checksum |
| `0x000010` | M-mode loader payload | ROM copies to `0x8000_0000` and jumps |
| `0x040000` | 24-byte `LNX1` manifest: magic `0x31584e4c`, kernel file size/sum, DTB size/sum, kernel runtime bytes | Loader validates bounds and sums |
| `0x040020` | DTB | Copied to `0x803f_0000` |
| `0x041000` | RISC-V Linux `Image` | Copied to `0x8040_0000` |

`pack_linux_flash.py` writes a full 16 MiB binary filled with `0xff` outside populated regions and a JSON metadata file containing the SHA-256 and sizes. `--trim` is for a smaller simulation artifact. It checks the RISC-V Image magic, 4 MiB load offset, runtime extent, DTB magic/size, slot boundaries, and NOR capacity. The 32-bit additive sums catch many transfer/copy errors but provide no authenticity or tamper resistance. There is no secure boot key or signed-image verification.

## ROM and M-mode loader

The CPU starts at physical zero. The immutable ROM reads NOR through the serial bridge at `0x2000_0000`. It validates `RVSB`, copies word by word to PSRAM at `0x8000_0000`, sums words, then jumps to the loader. On failure it writes ASCII `E` to the SoC UART and loops. A flash read and PSRAM write occur for every copied word; this is an actual boot copy, not a host preload.

The loader's linker script starts at `0x8000_0000` and asserts it fits below `0x8004_0000`. Its entry assembly initializes `gp`, the stack, clears BSS, and installs an M-mode trap entry with a saved register frame. It prints `L`, reads the LNX1 manifest from NOR, checks sizes/alignment, copies DTB and kernel with additive checksums, and zeroes the kernel's runtime tail (`memsz-file size`). It prints `B` before entering Linux. Failures print `H` (header/bounds), `D` (DTB checksum), `K` (kernel checksum), or `T` (unexpected trap). The loader sets a far-future `mtimecmp`, arranges delegation, sets the kernel entry in `mepc`, passes hart ID 0 in `a0` and DTB address in `a1`, and executes `mret` into S-mode with `satp=0` initially.

The loader remains resident as a minimal SBI implementation. An S-mode ECALL traps to M-mode; the handler reports SBI base information and implements the TIME extension `set_timer`. Machine timer IRQ pushes a supervisor timer-pending bit, which Linux services. Unsupported SBI extensions return an error; this is not a complete firmware stack. The loader's reserved lower 4 MiB of RAM is excluded from Linux's usable memory by the device tree.

## Linux and user program

The kernel uses the DTB's single RV32IMA hart, Sv32 MMU, 20 MHz timebase, 32 MiB RAM, one-source PLIC, and 16550 UART. The image has an embedded gzip initramfs. `/init` mounts devtmpfs, proc, and sysfs, emits `RV32 Linux userspace ready`, then replaces itself with interactive BusyBox ash using `/dev/console` and prompt `ASH> `. The complete acceptance gate waits for that prompt, sends `/bin/acceptance_smoke` as **UART RX frames**, and recognizes `ASH_PROGRAM_OK` on **UART TX**. This exercises firmware, Linux, serial memories, MMU, interrupts, UART, shell command parsing, and a userspace executable in one digital simulation. It does not establish electrical board behavior.

## Why it takes billions of cycles

ROM/loader copying contributes many serial flash reads and PSRAM writes. Kernel decompression and startup then execute code and touch pages in external PSRAM; the uncached word-serial bridge makes each instruction/data access costly. Page-table walks add more serial requests, and a smaller direct-mapped TLB increases misses. Timer events consume CPU time when handled, but `mtime` itself increments in hardware with no executed instruction. The [boot performance baseline](../boot-performance-baseline.md) and experiment logs give measured cycle markers; do not infer a single dominant stage from one marker or host runtime alone.
