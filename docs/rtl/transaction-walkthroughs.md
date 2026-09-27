# Tracing a transaction through the RTL

This chapter turns the structural diagrams into signal-level walks. State names are the actual localparams in the source. A waveform debugger can search these signals in `soc_top.cpu`, `.adapter`, `.bus`, and `.memory`.

## Fetching a translated instruction from PSRAM

1. In `rv32i_core.FETCH_REQ`, `i_req_valid=1` and `i_req_addr=pc`. If an enabled interrupt is pending, production mode traps before issuing the fetch.
2. In `sv32_bus_adapter.IDLE`, the adapter accepts the instruction address when no data request wins. It records `virtual_addr`, current privilege, SUM/MXR, and sees whether `satp[31]` enables translation.
3. If a TLB entry selected by the low VPN bits has matching upper VPN tag and SATP context, the adapter checks its PTE permission and forms `cached_addr`. Otherwise `WALK_REQ/WALK_RESP` read the root PTE through the physical bus. A nonleaf produces a second walk. A leaf missing A triggers `UPDATE_REQ/UPDATE_RESP` to write back the PTE.
4. `ACCESS_REQ` asserts `bus_req_valid`, `bus_req_addr`, read flag, and zero strobes. The physical bus decodes PSRAM, latches the selected target, forwards the RAM-relative byte offset, and waits.
5. `serial_mem_bridge.IDLE` latches chip index `[24:23]` and aligned address `[22:0]`, lowers one CS#, and starts `EBh`. `SETUP/HIGH/LOW` send command/address then release DQ to sample eight quad data nibbles. `read_shift` accumulates the word, which is reordered to bus endianness. `GAP` releases CS#, and `DONE` holds response valid.
6. The physical bus returns the word; the adapter's `ACCESS_RESP` captures it and `DONE` presents `i_resp_valid`. The CPU's `FETCH_RESP` latches `instr` and rs1 value, then reads rs2 in `READ_RS2`. An instruction fetch therefore crosses the bridge once on a TLB hit and additionally for PTE traffic on a miss.

## Store byte to PSRAM

In `EXEC`, the core forms effective address with the shared adder, sets one `store_strb` bit according to address low bits, and shifts source data into that byte lane. It latches aligned bus address/data/strobe for `DATA_REQ`. The Sv32 path checks W permission and possibly updates A/D. The bridge selects the chip and issues `38h` at the **individual byte address** with two quad data clocks for that byte. A halfword with two byte strobes becomes two separate serial commands; a full four-byte word is one 22-clock command. The response travels back to `DATA_RESP`; an error becomes a store access/page fault, otherwise the instruction retires. This explains why a byte-copying loop can be much more expensive than a word-copying loop even when it copies fewer data bytes.

## Load from NOR and boot-copy cost

The ROM's `lw` at `0x2000_0000+offset` bypasses Sv32 in M-mode. The bus selects the read-only NOR window. The bridge emits `6Bh`, 24 address bits, eight dummy clocks, and eight quad data clocks. The ROM then writes the word to PSRAM through `38h`. Its loop also fetches its own instructions from the tiny on-chip ROM, so each payload word entails at least a NOR read and a PSRAM write plus core/bus state overhead. The M-mode loader later repeats a similar NOR-to-PSRAM copy for the DTB and kernel, now fetching its own instructions from PSRAM. The testbench's `flash_req` and `ram_req` counters include page walks and runtime traffic, so they are not solely bytes copied.

## UART receive, PLIC, and Linux shell

The host drives a start bit and eight LSB-first bits into `uart_rx`. The UART double-synchronizes the pin, confirms the start at mid-bit, samples eight data bits and stop, then sets `rx_valid`. If RX interrupt enable is set, its IRQ goes high. The PLIC sees this level on source 1, checks priority, enable and threshold, then asserts supervisor external IRQ. At the next CPU fetch boundary, privilege logic records trap CSRs and vectors to the supervisor handler. Linux reads PLIC claim ID 1, reads UART RBR to consume the byte, services tty input, and writes completion ID 1 to PLIC. The command becomes bytes in ash's line editor; ash eventually executes the statically linked smoke program. The full testbench waits for each received byte to be consumed before injecting the next because there is no RX FIFO. A stuck IRQ can result from failure to clear UART pending state, complete PLIC service, or update CSR pending/delegation state; inspect these separately.

## What to probe on a failing run

| Symptom | First signals/log markers | Likely module boundary |
|---|---|---|
| Boot never reads flash | `initialized`, `spi_cs_n`, `spi_sck`, `flash_req` | Power wait, bridge reset, bus decode |
| ROM prints `E` | RVSB header words, NOR bytes, checksum, `uart_tx` | Packed image, serial read, ROM copy |
| Loader prints `H/D/K/T` | LNX1 fields, copy sums, trap cause | Manifest, DTB/Image placement, SBI/trap |
| Page fault loop | `pc`, `satp`, privilege, PTE, `walk_addr`, `stval`, `scause` | Sv32 PTE validation/permissions/A-D update |
| PLIC/UART IRQ loop | `rx_valid`, `tx_irq_pending`, `ier`, `claimable`, `in_service`, `mip/sip` | UART/PLIC/privilege pending state |
| Shell appears but command stalls | `ASH>`, injected RX bytes, `uart_rx_consumed`, UART overrun | UART pin frames, tty IRQ path |
| Physical design stops | Last LibreLane stage, DPL/DRT/antenna error, utilization and buffer count | Area/congestion/hold/antenna, not software |
