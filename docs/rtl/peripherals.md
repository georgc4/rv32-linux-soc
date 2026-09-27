# MMIO peripherals and interrupts

**Sources:** [`uart16550_lite.v`](../../rtl/peripherals/uart16550_lite.v), [`clint_timer.v`](../../rtl/peripherals/clint_timer.v), [`plic_lite.v`](../../rtl/peripherals/plic_lite.v), [`boot_rom.v`](../../rtl/peripherals/boot_rom.v). All use the bus request/response contract and receive window-relative byte addresses.

## UART at `0x1000_0000`

This is a small 16550-compatible subset intended for the Linux `ns16550a` driver. Registers are eight bits wide in the low byte of a 32-bit word, with a four-byte stride (`reg-shift=2`). The hardware always transmits/receives 8 data bits, no parity, one stop bit. LCR is readable/writable and its DLAB bit controls divisor access, but arbitrary parity/word-length/break settings do not reconfigure the physical framing. There is no FIFO, hardware flow control, modem signaling, or loopback. A second received byte before the first is consumed sets overrun.

| Offset | Read | Write or side effect |
|---:|---|---|
| `0x00` | RBR (clears RX valid), or DLL when DLAB=1 | THR starts TX, or DLL when DLAB=1; THR write waits while TX busy |
| `0x04` | IER, or DLM when DLAB=1 | Enable RX bit 0 and TX bit 1, or set DLM |
| `0x08` | IIR: `0x04` RX, `0x02` TX, `0x01` none | FCR bit 1 clears RX valid/overrun; no FIFO is created |
| `0x0c` | LCR | Stores LCR; bit 7 is DLAB |
| `0x10` | MCR | Stores MCR; modem outputs are not implemented |
| `0x14` | LSR | Bit 0 data ready, bit 1 overrun, bits 5/6 TX idle; read clears overrun |
| `0x18` | MSR reads zero | No modem inputs |
| `0x1c` | Scratch | Stores scratch byte |

RX passes through two flip-flops before start-bit detection. Sampling waits half a bit for start confirmation, then one bit per data bit and the stop bit. TX drives start low, eight LSB-first bits, and stop high. The reset divisor is 11 and the RTL's bit period is `16 × divisor = 176` SoC clocks. At 20 MHz this is approximately 113,636 baud, close enough to nominal 115200 for the intended link, subject to real clock accuracy and host tolerance. The Linux device tree specifies a 20 MHz UART clock and 115200 current speed. The UART IRQ is `(IER.RX && rx_valid) || (IER.TX && tx_irq_pending)`; reading IIR clears the TX pending condition in the corresponding case. The exact IIR/THRE behavior matters to Linux interrupt operation and is covered by directed and full Linux tests.

## CLINT-like timer at `0x0200_0000`

One 64-bit `mtime` increments on **every SoC clock**. `mtimecmp` resets to all ones; timer IRQ asserts when `mtime >= mtimecmp`. `msip` is a one-bit software interrupt source. The low/high halves of `mtimecmp` are at `+0x4000/+0x4004`; `mtime` at `+0xbff8/+0xbffc`; `msip` at `+0x0`. Writes merge enabled byte lanes. The privilege unit's `time/timeh` CSR reads this same counter. At 20 MHz, one tick is 50 ns. Linux's periodic scheduling depends on its configured timer frequency and SBI timer calls; the hardware counter does not spend CPU cycles merely incrementing. Timer **interrupt handling** and SPI memory transactions consume CPU/boot cycles. The firmware writes `mtimecmp` high to all ones before low then high to avoid a transient compare in the past.

## PLIC-like controller at `0x0c00_0000`

The sole source is UART IRQ, source ID 1. Priority is three bits at `+0x4`; pending bit 1 at `+0x1000`; enable bit 1 at `+0x2000`; supervisor context-0 threshold at `+0x200000`; claim/complete at `+0x200004`. An IRQ is claimable only while the level source is high, enabled, priority exceeds threshold, and it is not already in service. A claim read returns 1 and marks it in service; a completion write of 1 clears that state. The PLIC sends supervisor external IRQ to the core. The UART IRQ also directly reaches the core's machine external input, so software must configure delegation/enables consistently. There are no additional interrupt sources, contexts, edge latches, or nested claim queues.

## ROM at `0x0000_0000`

The bus reserves 4 KiB, but [`boot_rom.hex`](../../firmware/boot_rom.hex) contains 27 initialized words (108 bytes). `boot_rom.v` loads that file with `$readmemh`. Reads outside the populated words, unaligned requests, and writes error. Its program validates a NOR flash header, copies the loader into PSRAM, and jumps there. The ROM has no update mechanism in RTL. See [boot chain](../boot/boot-chain.md).
