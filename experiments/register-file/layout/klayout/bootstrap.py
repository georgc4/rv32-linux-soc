"""Create the one-time editable KLayout bitcell source from PDK device geometry.

Run with KLayout's embedded Python (see README). This script deliberately refuses
to overwrite the GDS: subsequent edits to that file are the design source.
"""

from pathlib import Path
import sys

import pya


repo = Path(__file__).resolve().parents[4]
source = repo / "build/register-file/layout/rf8t_devices.gds"
destination = Path(__file__).with_name("rf8t_bitcell.gds")
if not source.is_file():
    raise SystemExit(f"Generate the device geometry first: {source}")
if destination.exists():
    raise SystemExit(f"Refusing to overwrite editable layout: {destination}")

layout = pya.Layout()
layout.read(str(source))
if layout.dbu != 0.001:
    raise SystemExit(f"Unexpected database unit: {layout.dbu}")

devices = {
    "sky130_fd_pr__pfet_01v8_N3YQBX": "PFET_W042_L015",
    "sky130_fd_pr__nfet_01v8_VFZKS6": "NFET_W065_L015",
    "sky130_fd_pr__nfet_01v8_NY4RLA": "NFET_W084_L015",
}
for old_name, new_name in devices.items():
    cell = layout.cell(old_name)
    if cell is None:
        raise SystemExit(f"Missing PDK geometry: {old_name}")
    cell.name = new_name

old_top = layout.cell("rf8t_devices")
if old_top is None:
    raise SystemExit("Missing device palette top cell")
layout.delete_cell(old_top.cell_index())

# Coordinates are a draft placement only. All transistor terminals remain
# disconnected; neither this placement nor its bounding box is array ready.
top = layout.create_cell("RF8T_BITCELL")
placements = (
    ("PFET_W042_L015", 0, 3000),      # PQ
    ("PFET_W042_L015", 2300, 3000),   # PQB
    ("NFET_W065_L015", 0, 0),         # NQ
    ("NFET_W065_L015", 2300, 0),      # NQB
    ("NFET_W084_L015", -1900, 0),     # WAQ
    ("NFET_W084_L015", 4200, 0),      # WAQB
    ("NFET_W065_L015", 0, -3000),     # RN
    ("NFET_W065_L015", 2300, -3000),  # RQ
)
for cell_name, x, y in placements:
    top.insert(pya.CellInstArray(layout.cell(cell_name).cell_index(), pya.Trans(x, y)))

layout.write(str(destination))
print(f"Created editable {destination}")
print(f"Top: {top.name}; device instances: {len(placements)}")
