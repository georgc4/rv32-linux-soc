# First-pass transistor sizing for the 8T bitcell

This is a starting point for a 1.8 V SKY130 1R1W cell. The reference SPICE
netlist, schematic, and KLayout device cells agree on the drawn dimensions.
No write margin, hold margin, read delay, or array yield is established yet.

| Devices | Function | Starting W / L (µm) | What to change if it fails |
| --- | --- | --- | --- |
| PQ, PQB | Cross-coupled pullups | 0.42 / 0.15 | Increase only if hold/noise margin requires it; larger pullups fight writes. |
| NQ, NQB | Cross-coupled pulldowns | 0.65 / 0.15 | Increase for hold/noise margin; check write difficulty and area. |
| WAQ, WAQB | Write access | 0.84 / 0.15 | Increase if a write cannot overcome the opposite pullup at worst corner. |
| RN, RQ | Isolated read discharge stack | 0.65 / 0.15 | Increase if the precharged RBL does not discharge within the read window. |

Use the regular `sky130_fd_pr__nfet_01v8` and
`sky130_fd_pr__pfet_01v8` models. For an ordinary custom transistor, the
published minimum channel width is **0.42 µm**. The PDK generator used here
permits **0.15 µm** channel length for these 1.8 V FETs. The much smaller
special SRAM devices are restricted to foundry hard IP, so they are not a
shortcut for this custom bitcell.

The initial access/pullup *width* ratio is 0.84/0.42 = 2; the
pulldown/access ratio is 0.65/0.84 ≈ 0.77. Treat these as geometry labels,
not guaranteed current ratios: PMOS and NMOS strengths, node voltage,
parasitics, and corner differ. The separate read port avoids disturbing Q/QB
through the read bitline, so the usual 6T read access/pulldown rule does not
directly size this cell.

Recommended order for an area-focused design:

1. Lay out one cell with the starting sizes and run DRC, extraction, and LVS.
2. Simulate writes of both polarities at low supply, high temperature, and
   the corners that make access weak relative to the opposing pullup. Check
   both selected and half-selected cells.
3. Simulate hold/noise margin and leakage at the supply/temperature extremes.
4. Simulate read discharge with the **extracted** RBL load for a full column
   and the intended sense/precharge timing. Include the two-series-FET stack.
5. Change one device class at a time, rerun the corners, and record area and
   delay. Candidate width steps are 0.42 → 0.65 → 0.84 → 1.0 µm. Keep L at
   0.15 µm initially; only lengthen after a measured leakage/variation issue.

The likely first tradeoff is write access versus pullup strength. If writes
fail, strengthen WAQ/WAQB or weaken PQ/PQB; if hold fails, strengthen the
latch while confirming writes still pass. If reads fail, size RN/RQ and the
precharge/sense path together. Tiling may motivate shared diffusion and taps;
re-extract after each topology change because it changes capacitance and
series resistance.

Official PDK references: [periphery design rules](https://skywater-pdk.readthedocs.io/en/main/rules/periphery.html),
[device details and SRAM IP restriction](https://skywater-pdk.readthedocs.io/en/main/rules/device-details.html).
