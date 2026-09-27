# Register file and exploratory 8T bitcell

**Production status:** the CPU still uses four banks of RTL register arrays mapped to standard cells. The custom 8T layout and OpenRAM macros are experiments and have no integration into `soc_top`.

## Why a macro is difficult at this size

There are 31 mutable architectural words, 32 bits each, one write port, and one asynchronous time-shared read port. A compiled SRAM generally adds bitlines, decoders, sense/precharge circuits, write drivers, output/control registers, taps, and timing margins. The generated SKY130 32×32 1RW+1R OpenRAM macro measures **72,569.868 µm²** by LEF/Liberty versus **37,442.160 µm²** for a standalone standard-cell 1R1W RF comparison. The internal OpenRAM bank alone is 27,887.947 µm², but is not a complete usable synchronous macro. A 40×32 shared RF/TLB trial did not produce a characterized result. The 32×32 macro has independent Magic DRC and Netgen LVS failures, so its GDS is not suitable for integration. [OpenRAM trial details](../../experiments/register-file/openram/README.md) list versions, dimensions, errors, and reproduction.

The core's current read is asynchronous and explicitly split across `FETCH_RESP` and `READ_RS2`. A synchronous macro would require another timing state or different fetch/operand sequencing, plus new Linux acceptance and timing checks. Sharing a macro with the four-entry TLB would add arbitration, tag comparison, and latency; storage bits alone do not establish a saving. Any macro proposal must compare **full integrated routed area and boot cycles**, not just bitcell pitch.

## 8T topology and pins

The reference electrical schematic is [`rf8t_reference.spice`](../../experiments/register-file/layout/rf8t_reference.spice), with a generated [SVG schematic](../../experiments/register-file/layout/rf8t_schematic.svg). Two cross-coupled inverters hold Q/QB: PQ/PQB pullups to VDD and NQ/NQB pulldowns to VSS. WAQ/WAQB are the two WWL-controlled write pass transistors between Q/QB and differential BL/BLB. RN/RQ form an isolated two-NMOS read discharge stack from precharged RBL to VSS, gated by RWL and stored Q. The read path does not directly connect the storage node to RBL. An external precharge/sense path is required; a bitcell alone is not a RAM.

| Device pair | Role | Initial drawn W/L (µm) |
|---|---|---:|
| PQ, PQB | Cross-coupled PMOS pullups | 0.42 / 0.15 |
| NQ, NQB | Cross-coupled NMOS pulldowns | 0.65 / 0.15 |
| WAQ, WAQB | Differential write access | 0.84 / 0.15 |
| RN, RQ | Isolated read stack | 0.65 / 0.15 |

These dimensions are a **starting geometry**, not characterized drive ratios. The width ratios are WA/PQ=2 and NQ/WA≈0.77, but PMOS/NMOS mobility, threshold, bias, series resistance, and extracted parasitics prevent interpreting those as current ratios. Stronger WA helps overwrite the latch but grows wordline/bitline capacitance. Stronger PQ/NQ can improve hold but fight a write; stronger RN/RQ speeds read discharge but increases read-bitline capacitance and area. Test both write polarities, half-select disturb, data retention/noise margin, leakage, and full-column read delay over the intended PVT corners. Include extracted parasitics, precharge timing, and sense threshold. Change one device class at a time and record the measured tradeoff. [Sizing guide](../../experiments/register-file/layout/klayout/SIZING.md) has the explicit sweep plan and PDK references.

## Editable layout and present checks

[`klayout/rf8t_bitcell.gds`](../../experiments/register-file/layout/klayout/rf8t_bitcell.gds) is an **editable starter** with eight real PDK-generated device instances grouped into three reusable KLayout cells. They are positioned but unconnected; the starter lacks routing, wells/taps, pin labels, and array tiling. It is not DRC/LVS clean or array-ready. Open with [`klayout/open.sh`](../../experiments/register-file/layout/klayout/open.sh); editing a named device cell changes all instances, whereas flattening breaks that shared hierarchy. Match Q, QB, BL, BLB, WWL, RBL, RWL, VDD, and VSS to the SPICE reference, tie PMOS wells to VDD and NMOS substrate to VSS, and add pin geometry and array-edge/tap strategy before extraction.

The older [`magic/rf8t_routed.mag`](../../experiments/register-file/layout/magic/rf8t_routed.mag) is a separate spread-out routed prototype. Its extracted Netgen LVS matched the reference, but its Magic DRC found violations. [`check_layout.sh`](../../experiments/register-file/layout/check_layout.sh) copies the source into ignored `build/`, runs Magic DRC and extraction, exports GDS, and runs Netgen LVS. It fails if either DRC or LVS fails. A matching single-bit LVS is useful connectivity evidence, not noise-margin, timing, or array-yield proof. No custom macro can join the production PNR flow until it has its own clean DRC/LVS, extracted timing and power views, LEF/GDS/Liberty interface, and a compatible CPU timing contract. The special small-rule SKY130 SRAM devices are restricted to approved hard IP; the starter uses ordinary 1.8 V devices.
