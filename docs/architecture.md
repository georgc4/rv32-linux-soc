# Architecture

The current architecture reference is the [engineering handbook](README.md):

- [System architecture](system/architecture.md) describes the integrated hierarchy, clock/reset boundary, and memory paths.
- [Bus contract and map](system/bus-and-address-map.md) gives the physical interface and address decode.
- [CPU](rtl/cpu-core.md), [privilege/MDU](rtl/mdu-and-privilege.md), [Sv32](rtl/sv32.md), [serial memories](rtl/serial-memory.md), and [peripherals](rtl/peripherals.md) cover each hardware unit.
- [Pin integration](rtl/integration-and-pins.md) covers ASIC and FPGA wrappers.
- [RTL-derived diagrams](rtl-block-diagrams/README.md) show current source-checked partitions and mapped-area overlays.

The earlier architecture sketch described a 16-entry TLB and an earlier boot milestone. It remains available in Git history, but the current RTL has a four-entry TLB and the full serial Linux shell/program acceptance gate.
