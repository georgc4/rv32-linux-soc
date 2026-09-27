# Glossary and common confusions

| Term | Meaning here |
|---|---|
| **A/D bits** | Accessed/Dirty bits in an Sv32 leaf PTE; adapter writes them back when needed. |
| **ABC / Yosys** | Logic optimization and synthesis/mapping tools; mapped cell area is before physical design. |
| **Ash** | BusyBox's shell, the first interactive userspace milestone. |
| **CLINT / PLIC** | Local timer/software interrupts and platform external interrupt controller. Both are deliberately small subsets. |
| **CS# / DQ / SCK** | Active-low chip select, bidirectional serial data lanes, and serial clock for external memories. |
| **DRC** | Geometry design-rule check against a specified PDK deck/options; zero violations is scoped to that deck and layout. |
| **GDS** | Final mask-geometry exchange file from a physical run; its existence alone is not signoff. |
| **LVS** | Layout-versus-schematic/netlist connectivity comparison. It does not measure speed or noise margin. |
| **Mapped area** | Sum of technology-mapped standard-cell areas; distinct from placeable core or routed instance area. |
| **MDU** | Iterative multiply/divide unit supporting RV32M. |
| **MPRV, SUM, MXR** | `mstatus` controls affecting translation effective privilege and page permissions. |
| **PTE / TLB** | Page-table entry / small translation cache. Four direct-mapped entries are integrated by default. |
| **RVSB / LNX1** | This project's flash header and second-stage manifest magics, respectively. Neither is a secure-boot signature. |
| **SBI** | Supervisor Binary Interface calls from Linux to the resident M-mode loader; only BASE and TIME subset are provided. |
| **Signoff** | Complete evidence on a selected exact GDS and operating condition, including physical rule checks and timing/power/IO reviews. |
| **Sv32** | RISC-V 32-bit virtual-memory scheme with two-level page tables and 4 KiB pages/4 MiB superpages. |
| **WNS** | Worst negative setup slack in a particular timing report/corner/stage; an unconstrained path is not represented by a good WNS. |

For a debugging trace, follow `pc`/privilege/SATP → core state → Sv32 state/TLB → bus target → serial bridge command/CS/DQ → response → trap or retirement. For UART issues, follow UART register access, IIR/LSR state, PLIC claim/complete, and the physical RX/TX pins separately. The full Linux bench already prints many of these markers; [`tests-and-models.md`](../verification/tests-and-models.md) describes them.
