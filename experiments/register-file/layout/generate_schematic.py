#!/usr/bin/env python3
"""Render the 8T bit-cell reference SPICE as a compact transistor schematic."""

from __future__ import annotations

from html import escape
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXPECTED = {
    "PQ": ("Q", "QB", "VDD", "VDD"),
    "NQ": ("Q", "QB", "VSS", "VSS"),
    "PQB": ("QB", "Q", "VDD", "VDD"),
    "NQB": ("QB", "Q", "VSS", "VSS"),
    "WAQ": ("Q", "WWL", "BL", "VSS"),
    "WAQB": ("QB", "WWL", "BLB", "VSS"),
    "RN": ("RBL", "RWL", "RN_INT", "VSS"),
    "RQ": ("RN_INT", "Q", "VSS", "VSS"),
}


def read_devices() -> dict[str, tuple[str, str, str]]:
    devices = {}
    for line in (HERE / "rf8t_reference.spice").read_text().splitlines():
        if not line.startswith("X"):
            continue
        parts = line.split()
        name = parts[0][1:]
        assert tuple(parts[1:5]) == EXPECTED[name], (name, parts[1:5])
        kind = "PMOS" if "pfet" in parts[5] else "NMOS"
        width = parts[6].split("=", 1)[1]
        length = parts[7].split("=", 1)[1]
        devices[name] = kind, width, length
    assert set(devices) == set(EXPECTED)
    return devices


def main() -> None:
    devices = read_devices()
    parts = ["""<svg xmlns="http://www.w3.org/2000/svg" width="1380" height="720" viewBox="-80 0 1380 720">
<style>
text{font-family:Inter,Arial,sans-serif;fill:#e5e7eb}
.title{font-size:28px;font-weight:700}.subtitle{font-size:15px;fill:#94a3b8}
.dev{font-size:19px;font-weight:700}.detail{font-size:12px;fill:#cbd5e1}
.net{font-size:16px;font-weight:700}.note{font-size:14px;fill:#94a3b8}
</style>
<rect x="-80" width="1380" height="720" fill="#0b1220"/>
<text class="title" x="55" y="53">8T register-file bitcell · 1 read / 1 write</text>
<text class="subtitle" x="55" y="80">Electrical schematic derived from rf8t_reference.spice · one stored bit</text>
"""]

    def line(x1, y1, x2, y2, color="#e5e7eb", width=3):
        parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>')

    def label(value, x, y, color="#e5e7eb", anchor="middle", css="net"):
        parts.append(f'<text class="{css}" x="{x}" y="{y}" text-anchor="{anchor}" style="fill:{color}">{escape(value)}</text>')

    def dot(x, y, color="#e5e7eb"):
        parts.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{color}"/>')

    def fet(name, x, y, gate_net):
        kind, width, length = devices[name]
        color = "#fb7185" if kind == "PMOS" else "#60a5fa"
        fill = "#3d1b2a" if kind == "PMOS" else "#142c4c"
        parts.append(f'<rect x="{x-60}" y="{y}" width="120" height="66" rx="10" fill="{fill}" stroke="{color}" stroke-width="2.5"/>')
        line(x-112, y+33, x-60, y+33, "#fbbf24", 3)
        label(gate_net, x-119, y+39, "#fbbf24", "end")
        label(name, x, y+28, color, css="dev")
        label(f'{kind}  {width}/{length} µm', x, y+50, css="detail")

    # Shared supplies and external bitlines.
    line(360, 135, 610, 135, "#fb7185", 4)
    label("VDD + n-well", 485, 123, "#fb7185")
    line(360, 605, 1090, 605, "#38bdf8", 4)
    label("VSS + substrate", 725, 635, "#38bdf8")
    for x, net in [(120, "BL"), (850, "BLB"), (1090, "RBL")]:
        label(net, x, 133, "#4ade80")
        line(x, 145, x, 240, "#4ade80")

    # Two cross-coupled CMOS inverters store Q and QB.
    for x, upper, lower, output, gate in [
        (360, "PQ", "NQ", "Q", "QB"),
        (610, "PQB", "NQB", "QB", "Q"),
    ]:
        fet(upper, x, 190, gate)
        fet(lower, x, 465, gate)
        line(x, 135, x, 190, "#fb7185")
        line(x, 256, x, 355)
        line(x, 355, x, 465)
        line(x, 531, x, 605, "#38bdf8")
        dot(x, 355)
        label(output, x+17, 343, "#c4b5fd", "start")

    # Differential write access transistors, with one shared wordline.
    for x, name, output, output_x in [
        (120, "WAQ", "Q", 360),
        (850, "WAQB", "QB", 610),
    ]:
        fet(name, x, 240, "WWL")
        line(x, 306, x, 355)
        line(min(x, output_x), 355, max(x, output_x), 355)

    # Decoupled two-NMOS read stack: Q controls discharge of RBL.
    fet("RN", 1090, 240, "RWL")
    fet("RQ", 1090, 465, "Q")
    line(1090, 306, 1090, 400)
    line(1090, 400, 1090, 465)
    line(1090, 531, 1090, 605, "#38bdf8")
    dot(1090, 400)
    label("RN_INT", 1070, 390, "#c4b5fd", "end", "note")

    # Functional group captions and the net-label convention.
    label("WRITE ACCESS", 110, 690, "#94a3b8", "start", "note")
    label("CROSS-COUPLED STORAGE", 365, 690, "#94a3b8", "start", "note")
    label("DECOUPLED READ", 1010, 690, "#94a3b8", "start", "note")
    label("Matching gate labels denote the same net. PMOS bodies → VDD; NMOS bodies → VSS.", 55, 665, "#94a3b8", "start", "note")
    parts.append("</svg>\n")
    output = HERE / "rf8t_schematic.svg"
    output.write_text("\n".join(parts))
    print(output)


if __name__ == "__main__":
    main()
