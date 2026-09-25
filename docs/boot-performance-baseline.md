# Serial Linux boot: measured baseline and next trials

This note records measurements from the full quad-serial simulation of the
Linux 6.12.111 image (flash SHA-256
`d7ca41e95c47af4ae02fe69c3fd0f56c9b33e41545bc2a0b8a95a23cac485b0c`).
The first run used RTL commit `19cb40a50abec1db30baf7332790ac22d1c009c8`.
It reached `/init` and the userspace ready marker, then entered a UART/PLIC
interrupt loop before the ash prompt. Commit
`410115b594b197e2c49539377d8368e5a45d3a9c` adds an acknowledged UART
transmit-empty interrupt; its full acceptance result is tracked separately.

| Event in first run | Simulated core cycle |
|---|---:|
| `ttyS0` registered | 9,740,488,704 |
| `Run /init as init process` | 12,362,453,993 |
| `RV32 Linux userspace ready` | 12,821,128,202 |
| UART/PLIC loop observed, no further timer progress | 12.84–13.04 billion |

At 13.043 billion cycles, the first run had accepted 204.1 million PSRAM
transactions and 1.217 million NOR reads. Dividing elapsed cycles by those
transactions gives about 64 core cycles per transaction overall. This is a
throughput indicator, **not** an exact attribution of cycles: CPU work and
interrupt service are included in the numerator. The bridge performs one
command per 32-bit PSRAM access, with 28 serial steps for a quad read and two
core cycles per step, plus setup and turnaround. NOR reads stop increasing
after the kernel image is loaded; the later work is served from PSRAM.

The kernel already uses `CONFIG_HZ=16`, disables high-resolution timers, and
enables idle tick suppression. During steady kernel initialization, the trace
shows about 80 timer traps per 100 million cycles, matching 16 Hz at the
20 MHz core timebase. Reducing tick frequency further is a possible image
trial, but changing the hardware timebase alone would invalidate the device
tree and SBI time assumptions. It is not the first performance lever.

Sparse PC samples include `inflate_fast` and `memcpy` in earlier
initialization. Later watchdog traces resolve into `plist_test_check` and
`plist_check_list` around 10–11 billion cycles, radix-tree deletion and
`kernfs` creation afterward. `CONFIG_DEBUG_PLIST=y` runs a built-in initcall
that repeatedly changes and scans a 241-node list; the image also enables
`CONFIG_DEBUG_VM_PGTABLE=y`, and the page-table validation message appears at
12.22 billion cycles. These are concrete software-work candidates on a
machine where every list or page-table memory reference is serial. The
watchdog warnings report long init work; they do not establish that timer
handling itself consumed most cycles.

## Ordered experiments after shell acceptance

1. Build separate image revisions disabling `CONFIG_DEBUG_PLIST` and then
   `CONFIG_DEBUG_VM_PGTABLE`; retain the same RTL and serial test. Compare
   cycles to `/init`, ash prompt, and the program marker. Keep the image hash
   in each experiment ID.
2. Add cycle attribution for PSRAM reads/writes, NOR reads, and a dephased
   guest-PC histogram. Use this to decide how much time remains in timer,
   decompression, copy, and other init paths after debug tests are removed.
3. If serial access still dominates, evaluate a small read buffer or burst
   transaction path against mapped area and routed fit. Preserve the four
   PSRAM chips and the real serial protocol in acceptance simulation.

The interactive [experiment dashboard](../experiments/README.md) records
source commits, image hashes, mapped area, physical results, and the ash
program gate. A candidate joins its Pareto frontier only after both routed
PNR and full serial acceptance pass.
