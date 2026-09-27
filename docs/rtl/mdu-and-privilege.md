# Iterative MDU and privileged state

**Sources:** [`rv32_mdu.v`](../../rtl/cpu/rv32_mdu.v), [`rv32_priv_unit.v`](../../rtl/cpu/rv32_priv_unit.v).

## Multiply/divide unit

The MDU implements all eight RV32M `funct3` operations. The core starts it with two 32-bit operands and waits in `MDU_WAIT`; the unit pulses `done` when a result is available. It uses a 64-bit `work` shift register, a stationary 32-bit operand, a six-bit count, original operands/sign bits, and control. This replaced separate wide multiply/divide datapaths to save mapped area.

For multiplication, `work[31:0]` initially holds the multiplier and the upper half is zero. Each iteration adds the stationary multiplicand to the upper half if `work[0]` is one, then shifts the combined 65-bit value right. After 32 iterations the low half is MUL; the high half is MULHU. MULH and MULHSU apply signed correction to the unsigned high half using the original operands. The conditional addition is 33 bits so its carry is retained during the shift. The unit does not build a full combinational 32×32 multiplier.

For division, operands are converted to magnitudes when signed operations require it. The same `work` register holds remainder in its upper half and quotient in its lower half. Each iteration shifts the trial remainder, compares/subtracts the stationary divisor, and writes one quotient bit. The selected quotient or remainder is sign-corrected at completion. Divide-by-zero is detected at launch: quotient becomes all ones and remainder becomes the dividend, matching the integer ISA behavior. Signed overflow and signed/unsigned edge cases are covered by directed tests; consult the RTL and [`rv32_mdu_tb.v`](../../sim/tests/rv32_mdu_tb.v) for exact case coverage. The active algorithm runs 32 iterations; handshake overhead is additional.

## Privilege model

The privilege unit stores machine, supervisor, and user mode (`3`, `1`, `0`), `mstatus`, interrupt enable/pending/delegation, trap vectors, scratch, EPC/cause/tval, `satp`, and counter-enable state. It supplies the core's current mode and Sv32's `satp`/`mstatus`. It also reads `time/timeh` from the CLINT's 64-bit counter; those CSRs do not own a second timer. `misa` reports RV32IMA with S and U. Vendor/architecture/implementation/hart IDs return zero. CSR addresses and writes are checked against current privilege, read-only encoding, TVM, and counter-enable rules.

| CSR group | Main implemented registers |
|---|---|
| Supervisor | `sstatus`, `sie`, `stvec`, `sscratch`, `sepc`, `scause`, `stval`, `sip`, `satp`, `scounteren` |
| Machine | `mstatus`, `misa`, `medeleg`, `mideleg`, `mie`, `mtvec`, `mcounteren`, `mscratch`, `mepc`, `mcause`, `mtval`, `mip` |
| Counters/IDs | `time`, `timeh`, zero-valued `mvendorid`, `marchid`, `mimpid`, `mhartid` |

The source applies explicit writable masks. For example, `satp` retains the mode and PPN fields supported by Sv32; `medeleg` and `mideleg` only accept implemented cause bits. A CSR instruction uses read, write, set, or clear semantics; writes to read-only addresses are illegal. The current mode must meet the CSR address's privilege encoding. MRET restores prior mode and machine interrupt enable; SRET does the supervisor equivalents. The core checks TSR/TVM/TW around SRET, SFENCE.VMA, WFI, and `satp` access where applicable.

For an exception or interrupt, the unit decides machine versus supervisor destination using delegation and current mode, writes EPC/cause/tval, updates interrupt-enable stack bits, and computes the trap vector. Interrupt vectors add `4*cause` only in vectored mode; synchronous exceptions use the base. Supported priority in RTL is machine external, machine software, machine timer, then supervisor external/software/timer after pending, enable, delegation, and global-enable filtering. CLINT drives machine timer/software; the UART level can drive machine external directly and reaches supervisor external through the PLIC. The M-mode loader delegates supervisor timer and external causes needed by Linux while keeping S-mode ECALL in M-mode for SBI.

The unit is a deliberately bounded implementation, not a claim of full privileged-ISA compliance. A new kernel configuration or platform feature should be checked against the CSR case statement, masks, interrupt priority, and directed privilege tests before relying on it.
