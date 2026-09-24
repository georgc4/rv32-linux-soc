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

Implementation sequence: original minimal RV32I core with instruction/data interface; then M and A; then privileged CSRs/traps and Sv32; then controllers and firmware. Reuse is limited to test infrastructure and documented software tools unless separately proposed and accepted.
