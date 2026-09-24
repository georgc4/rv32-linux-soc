# Architecture sketch (provisional)

```text
  instruction fetch ─┐
                     ├─ arbitration ─ physical_bus ─ PSRAM controller ─ 4 chips
  data / page walks ─┘                     ├───────── flash controller ─ NOR
                                          ├───────── UART
                                          ├───────── timer / interrupts
                                          └───────── immutable boot ROM
```

The CPU issues **physical** requests after translation. Sv32 applies to instruction fetch and loads/stores in applicable privilege modes; ordinary M-mode and bare accesses bypass it, with MPRV data-access semantics to be handled explicitly. Separate instruction and data ingress require arbitration before the existing single-outstanding `physical_bus`. Page-table walks also use physical memory and must not recursively translate. This structure deliberately keeps PSRAM/flash protocol state outside the core.

Exploratory ISA target: RV32IMA_Zicsr_Zifencei, M/S/U privilege, Sv32, traps, `MRET`/`SRET`, delegation, timer and external interrupts, `FENCE`/`FENCE.I`/`SFENCE.VMA`. The exact implemented subset, Linux configuration, and handling of misaligned accesses and PTE A/D bits require a pinned kernel and tests. `A` includes LR/SC and AMOs; serial memory must preserve an atomic word transaction across read-modify-write. A single hart makes this simpler but does not remove architecturally required reservation behavior. A 32-bit physical bus is a design choice and needs a defined fault policy for Sv32 PTE physical addresses beyond implemented RAM/MMIO.

`physical_bus` contract: one accepted request outstanding; `valid && ready` accepts it. Payload must remain stable while stalled. The selected slave receives byte **offset** within its window plus write data and byte strobes. A response occurs no earlier than the next cycle and remains valid until `resp_ready`. Unmapped requests complete with `resp_err=1`. Reset cancels an in-flight request. Current windows are parameters for simulation, not a committed SoC map. Sizes must be powers of two; bases must be size-aligned and nonoverlapping. There is no timeout yet: a slave that never responds hangs the bus, an item for later fault handling.

Current implementation: `rtl/soc/soc_top.v` connects the CPU, Sv32 walker, physical interconnect, ROM, CLINT-like timer, UART, and serial memory bridge. `tt_um_rv32_linux_soc.v` maps these signals to the Tiny Tapeout logical interface. The CPU implements the tested RV32I/M/A operations, selected machine and supervisor CSRs, `ECALL`, `MRET`, `SRET`, interrupts, and traps. The walker handles 4 KiB pages and 4 MiB superpages, permissions, page faults, and A/D updates without a TLB. `FENCE`, `FENCE.I`, and `SFENCE.VMA` require no cache flush in this implementation. Unit tests exercise machine traps and a real M-to-S handoff with translated fetch and store. The integrated ROM image remains a diagnostic; the SoC test runs it with `DIAGNOSTIC_MODE=1`, while the wrapper defaults to architectural trap behavior (`DIAGNOSTIC_MODE=0`).

**Linux capability is unproven.** No Linux kernel, SBI firmware, device tree, initramfs, shell, or fabricated execution has been tested. The current machine/supervisor implementation is not a full privileged-spec compliance claim. Privilege protection/PMP, comprehensive interrupt and CSR tests, full ISA compliance, exception corner cases, image update firmware, and physical timing remain. The multiplier/divider runs in 32 steps. Yosys `synth` reports roughly 15,253 generic cells for the CPU and 21,228 for the full logical top. Generic cells are not mapped SKY130 area, power, or timing figures and cannot establish shuttle tile fit. Atomics use a virtual-address reservation and a serialized single-master bus; architectural reservation edge cases need further review.
