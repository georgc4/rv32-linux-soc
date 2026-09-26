# OpenRAM register-file area trials

The configs in this directory generate SKY130 1RW+1R, 32-bit SRAM macros.
They are comparisons for the 31-register CPU register file and a possible
combined register-file/TLB store; neither is integrated into the SoC.

## Measured 32 × 32 trial

OpenRAM stable `b2b069ce119d1488cbe6883b2240bceb5c7ce29a` generated
`sky130_rf_32x32_1rw1r` using the installed SKY130A PDK. Its LEF and Liberty
views report **370.16 × 196.05 µm = 72,569.868 µm²**. The macro GDS is in
the ignored `build/register-file/openram-32x32/` directory. The standalone
`rf_1r1w.v` register file mapped with Yosys to SKY130 HD cells occupies
**37,442.160 µm²** (992 mapped storage bits plus read/write logic). Thus the
generated macro is 1.94 times that baseline's area even before integration
clearance or timing adaptation.

The dual-port bitcell tile has a 3.12 × 1.975 µm pitch, or 6.162 µm² per bit.
The 32 × 32 bitcell array occupies roughly 6,310 µm² by pitch. Most of the
macro footprint is peripheral circuitry and layout space. A custom small-array
approach would need **less than about 31,300 µm²** of total periphery to beat
the standard-cell register file in raw area. That is a target, not a measured
result. Banking can reduce bitline load but may replicate or multiplex sense
amplifiers, precharge, write drivers, and decoders.

KLayout reports the generated macro's internal **bank** bounding box as
230.66 × 120.905 µm = **27,887.947 µm²**. This bank includes the bitcell
array, local port data circuits, and address decode, but excludes top-level
clocked address/data registers, control, and replica timing. The bank by
itself has no characterized SRAM interface. It leaves only about **9,554 µm²**
for all missing interface circuits before reaching the mapped RF baseline.
It suggests a carefully specialized register-file macro might save area, but
does not establish a working or signoff-clean implementation.

The bitcell exposes `BL0/BR0`, `BL1/BR1`, `WL0/WL1`, `VDD`, and `GND`.
It does not expose the internal stored value as a logic-level output.
The generated macro has synchronous read semantics, whereas the present CPU
uses asynchronous register-file reads. Any integration needs an RTL state
change and timing verification.

## Physical status

This is **not a tapeout-ready macro**. OpenRAM was run with internal DRC/LVS
disabled and analytical timing. An independent Magic check of the 32 × 32 GDS
with the installed PDK reported 151,184 DRC errors; the first included
`licon.5c`, `poly.7`, `li.1`, and `licon.1`. Extraction completed with warnings.
Netgen LVS using the installed SKY130A setup reported **netlists do not
match**, with special-device model and property differences visible in its
output. These failures require investigation before any use; the report does
not assume that they are harmless array waivers or prove a true electrical
connectivity defect. The PDK documentation also restricts small-rule SRAM
devices to specific hard IP; that applicability must be resolved with the
shuttle/foundry before using or altering this bitcell.

## Shared TLB estimate

The current Sv32 adapter has four direct-mapped entries. Its declared storage
is 4 × (1 valid + 18 VPN tag + 32 PTE + 1 level flag) + 31 context bits =
**239 bits** before synthesis pruning. A direct lookup needs two 32-bit words
per entry, about eight SRAM rows; the 31-register file can use 31 rows. The
40 × 32 config is the smallest simple shared-array trial that fits both with
one spare row. A shared array still needs TLB comparison/permission logic,
port arbitration, and additional read latency. Moving the tiny TLB into a
larger macro is unlikely to repay the area cost.

As an intentionally generous storage estimate, 239 additional copies of the
same 30.03 µm² enabled flop used for the RF would add only ~7,177 µm². The
RF plus those TLB storage cells totals ~44,619 µm², well below the 32 × 32
macro's 72,570 µm²; the shared macro would also require more rows. The
actual TLB's mapped storage may be smaller, and its comparators remain in
either implementation.

The 40 × 32 compiler trial did **not** produce a complete macro: after
placement and routing, OpenRAM 1.2.49 stopped in analytical characterization
with `Could not find bl0 net in timing paths`. No 40 × 32 area number or
physical view is claimed. The 32 × 32 macro already exceeds the mapped RF
and estimated TLB storage combined, so this failure does not change the
area decision.

## Reproduction

The configs require OpenRAM with the SKY130 technology installed and
`PDK_ROOT`, `OPENRAM_HOME`, `OPENRAM_TECH`, and `PYTHONPATH` set per the
[OpenRAM setup guide](https://github.com/VLSIDA/OpenRAM/blob/stable/docs/source/basic_setup.md).
Run `python sram_compiler.py <config-file>` from the OpenRAM root. Inspect the
generated LEF/GDS/Liberty in the selected `build/register-file/` directory.

Reference: [SKY130 SRAM device restriction](https://skywater-pdk.readthedocs.io/en/main/rules/device-details.html#sram-cells).
