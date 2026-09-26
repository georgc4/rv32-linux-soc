#!/usr/bin/env python3
"""Run the exploratory SKY130 bit-cell schematic at TT/SS/FF corners."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "build" / "register-file" / "spice"
PDK = Path(os.environ.get("PDK_ROOT", Path.home() / ".volare/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71"))
MODEL = PDK / "sky130A/libs.tech/ngspice/sky130.lib.spice"
TEMPLATE = (HERE / "rf8t.spice.in").read_text()


def main() -> None:
    if not MODEL.is_file():
        raise SystemExit(f"missing SKY130 model: {MODEL}; set PDK_ROOT")
    OUT.mkdir(parents=True, exist_ok=True)
    for corner in ("tt", "ss", "ff"):
        deck = OUT / f"rf8t-{corner}.spice"
        log = OUT / f"rf8t-{corner}.log"
        deck.write_text(TEMPLATE.replace("@PDK_MODEL@", str(MODEL)).replace("@CORNER@", corner))
        subprocess.run(["ngspice", "-b", "-o", str(log), str(deck)], check=True, cwd=OUT)
        measurements = {}
        for key in ("stored_one", "read_one_rbl", "stored_zero", "read_zero_rbl"):
            m = re.search(rf"^{key}\s*=\s*([\deE+.-]+)", log.read_text(), re.MULTILINE)
            if not m:
                raise SystemExit(f"{corner}: missing {key}; see {log}")
            measurements[key] = float(m.group(1))
        print(corner, measurements)
        if not (measurements["stored_one"] > 1.35 and measurements["read_one_rbl"] < 0.45
                and measurements["stored_zero"] < 0.45 and measurements["read_zero_rbl"] > 1.35):
            raise SystemExit(f"{corner}: bit-cell write/read check failed; see {log}")


if __name__ == "__main__":
    main()
