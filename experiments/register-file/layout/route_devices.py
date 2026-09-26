#!/usr/bin/env python3
"""Route the first spread-out 8T layout using parsed Magic PCell terminals.

This is a connectivity prototype; compacting the device array is separate work.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "build/register-file/layout"
SCALE = 0.005  # Micrometres per coordinate in the generated SKY130 .mag files.

NETS = {
    "Q": ["PQ.D", "NQ.D", "WAQ.D", "PQB.G", "NQB.G", "RQ.G"],
    "QB": ["PQB.D", "NQB.D", "WAQB.D", "PQ.G", "NQ.G"],
    "VDD": ["PQ.S", "PQB.S", "NWELL_TAP.S"],
    "VSS": ["NQ.S", "NQB.S", "RQ.S", "PSUB_TAP.S"],
    "BL": ["WAQ.S"],
    "BLB": ["WAQB.S"],
    "WWL": ["WAQ.G", "WAQB.G"],
    "RBL": ["RN.D"],
    "RWL": ["RN.G"],
    "RN_INT": ["RN.S", "RQ.D"],
}


def box(x0: float, y0: float, x1: float, y1: float, layer: str) -> str:
    return f"box values {x0:.3f}um {y0:.3f}um {x1:.3f}um {y1:.3f}um\npaint {layer}\n"


def main() -> None:
    parent = (OUT / "rf8t_devices.mag").read_text()
    placements = {}
    for cell, name, tx, ty in re.findall(
        r"use (\S+)\s+(\S+)\s+timestamp \d+\s+transform 1 0 (\d+) 0 1 (\d+)", parent
    ):
        placements[name] = (cell, int(tx), int(ty))
    assert len(placements) == 8, placements
    terminals = {}
    for instance, (cell, tx, ty) in placements.items():
        leaf = (OUT / f"{cell}.mag").read_text()
        for x, y, pin in re.findall(r"rlabel \S+ (-?\d+) (-?\d+) -?\d+ -?\d+ \d+ ([DSG])", leaf):
            terminals[f"{instance}.{pin}"] = ((tx + int(x)) * SCALE, (ty + int(y)) * SCALE)
    assert len(terminals) == 24, terminals

    terminals["NWELL_TAP.S"] = (5.5, 4.8)
    terminals["PSUB_TAP.S"] = (41.5, 4.8)
    tcl = ["load rf8t_devices\n", "drc off\n"]
    tcl += [
        box(1.0, 2.5, 11.0, 7.0, "nwell"),
        box(5.05, 4.35, 5.95, 5.25, "nsc"),
        box(5.415, 4.715, 5.585, 4.885, "m1c"),
        box(5.05, 4.35, 5.95, 5.25, "metal1"),
        box(41.05, 4.35, 41.95, 5.25, "psc"),
        box(41.415, 4.715, 41.585, 4.885, "m1c"),
        box(41.05, 4.35, 41.95, 5.25, "metal1"),
    ]
    external = {"BL", "BLB", "WWL", "RBL", "RWL", "VDD", "VSS"}
    port_index = 1
    for index, (net, pins) in enumerate(NETS.items()):
        ybus = 14.0 + 1.2 * index
        breakouts = []
        for pin in pins:
            x, y = terminals[pin]
            side = pin.split(".")[1]
            xb = x + (-0.85 if side == "D" else 0.85 if side == "S" else 0)
            breakouts.append(xb)
            # PCell port metal1 -> individually spaced via1 -> metal2 riser.
            tcl.append(box(min(x, xb) - 0.08, y - 0.08, max(x, xb) + 0.08, y + 0.08, "metal1"))
            tcl.append(box(xb - 0.20, y - 0.20, xb + 0.20, y + 0.20, "metal1"))
            tcl.append(box(xb - 0.20, y - 0.20, xb + 0.20, y + 0.20, "metal2"))
            tcl.append(box(xb - 0.13, y - 0.13, xb + 0.13, y + 0.13, "via1"))
            tcl.append(box(xb - 0.11, min(y, ybus) - 0.17, xb + 0.11, max(y, ybus) + 0.17, "metal2"))
            tcl.append(box(xb - 0.20, ybus - 0.20, xb + 0.20, ybus + 0.20, "metal2"))
            tcl.append(box(xb - 0.20, ybus - 0.20, xb + 0.20, ybus + 0.20, "metal3"))
            tcl.append(box(xb - 0.14, ybus - 0.14, xb + 0.14, ybus + 0.14, "via2"))
        xmin, xmax = min(breakouts), max(breakouts)
        tcl.append(box(xmin - 0.50, ybus - 0.20, xmax + 0.50, ybus + 0.20, "metal3"))
        if net != "RN_INT":
            tcl.append(f"box values {xmin-0.50:.3f}um {ybus-0.20:.3f}um {xmin+0.50:.3f}um {ybus+0.20:.3f}um\n")
            tcl.append(f"label {net} c metal3\n")
            if net in external:
                tcl.append(f"port make {port_index}\n")
                tcl.append(f"port class {'output' if net == 'RBL' else 'input'}\n")
                if net in ("VDD", "VSS"):
                    tcl.append(f"port use {'power' if net == 'VDD' else 'ground'}\n")
                port_index += 1
    tcl += [
        "drc on\n", "box values 0um 0um 45um 30um\n", "drc check\n", "drc catchup\n", "drc count total\n", "puts \"DRC_WHY=[drc listall why]\"\n",
        "extract all\n", "ext2spice lvs\n", "ext2spice -o rf8t_routed.spice\n",
        "gds write rf8t_routed.gds\n", "feedback save rf8t_feedback.txt\n",
        "puts \"FEEDBACK=[feedback count]\"\n", "save rf8t_routed\n", "quit -noprompt\n",
    ]
    (OUT / "route.tcl").write_text("".join(tcl))
    print(f"Routed {len(terminals)} transistor terminals to {len(NETS)} nets")


if __name__ == "__main__":
    main()
