# Serial Linux boot: measured baseline and next trials

This note records measurements from the full quad-serial simulation of the
Linux 6.12.111 image (flash SHA-256
`d7ca41e95c47af4ae02fe69c3fd0f56c9b33e41545bc2a0b8a95a23cac485b0c`).
The first run used RTL commit `19cb40a50abec1db30baf7332790ac22d1c009c8`.
It reached `/init` and the userspace ready marker, then entered a UART/PLIC
interrupt loop before the ash prompt. Commit
`410115b594b197e2c49539377d8368e5a45d3a9c` adds an acknowledged UART
transmit-empty interrupt, but its full run reproduced the loop after the
userspace marker. The subsequent analysis found that CSR writes to `mip` and
`sip` could copy a live external interrupt bit into the software-pending
latch. Commit `8b2424d1772dea68066f662f3578a466f4087943` fixes this and
adds a directed regression; its full serial acceptance run is in progress.
The regression fails against the preceding RTL with `software_mip=0x220`
after an MIP timer-bit set while live SEIP is high, and passes with the fix.

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

The serial protocol itself gives a useful lower bound. Even the shortest
one-byte PSRAM write takes 16 serial steps, or 32 core cycles; a full-word
write takes 44 cycles and a read takes 56, before setup, response, bus, CPU,
or software overhead. Thus 204.1 million PSRAM transactions require **at
least 6.53 billion cycles** in the serial shift states alone, at least half
of the observed 13.043 billion cycles. The 1.217 million NOR reads add at
least 117 million shift cycles (48 steps each). These bounds do not identify
the remaining cycles, but they rule out timer handlers as the primary cost.

| Boot phase in the first run | Cycle span | What the trace establishes |
|---|---:|---|
| Firmware loads the kernel from NOR into PSRAM | 0–0.70 billion | NOR reads rise to 1.217 million, then stop. |
| Kernel starts through serial-console registration | 0.70–9.74 billion | PSRAM traffic continues; sparse PC samples include `inflate_fast` and `memcpy`, among many init functions. |
| Serial-console registration through `/init` | 9.74–12.36 billion | Samples and warnings include the debug plist self-test; page-table debug validation appears at 12.22 billion. |
| `/init` through userspace ready marker | 12.36–12.82 billion | Initramfs files are already available; shell startup follows. |

The trace does not delimit the initramfs unpack operation precisely, so it
cannot support a percentage of boot time attributed to that copy/decompress
phase. The 2.62 billion cycles between serial-console registration and
`/init` include other known work, notably the plist and page-table debug
paths; initramfs unpack may also occur in that interval.

The kernel already uses `CONFIG_HZ=16`, disables high-resolution timers, and
enables idle tick suppression. During steady kernel initialization, the trace
shows about 80 timer traps per 100 million cycles, matching 16 Hz at the
20 MHz core timebase. Reducing tick frequency further is a possible image
trial, but changing the hardware timebase alone would invalidate the device
tree and SBI time assumptions. It is not the first performance lever.

At the userspace-ready marker, the trace recorded about 201 million PSRAM
requests for 136 million retired instructions, or roughly 1.48 PSRAM
transactions per retired instruction. The CPU fetches instructions over this
same serial path and has no instruction cache (`FENCE.I` is currently a no-op
for that reason). A small, correctly invalidated instruction read buffer or
short serial burst is therefore a higher-value RTL trial than a lower timer
rate. The CS-low maximum and mapped area constrain its line size; it needs a
full serial acceptance run and physical measurement before adoption.

As a sizing estimate, a 16-byte quad read would use the current 20-step
command/address/dummy preamble plus 32 data steps: 52 serial steps, or 104
core cycles at the current divide-by-two SCK. Four separate 4-byte reads need
4 × 56 = 224 shift cycles. At 20 MHz, the 16-byte transaction is about
5.2 µs, below the [ESP-PSRAM64H 8 µs CE-low maximum](https://www.mouser.com/datasheet/2/737/4677_esp_psram64_esp_psram64h_datasheet_en-1900786.pdf).
A 32-byte read would take at least 168 core cycles, or 8.4 µs, before
additional setup/hold time, so it is not a safe first line size. These are
protocol estimates, not measured cache speedups; misses, branches, coherence,
and area determine the actual outcome.

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
