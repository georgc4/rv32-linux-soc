#!/usr/bin/env python3
"""Stage SKY26d RTL and describe the UART pins used by that RTL revision."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__, add_help=False)
parser.add_argument("--rtl-root", type=Path, default=ROOT)
parser.add_argument("--stage", type=Path, default=ROOT / "build/sky130/ttsky26d-stage")
args, _ = parser.parse_known_args()

dirty_sources = subprocess.check_output(
    ["git", "status", "--porcelain", "--", "rtl", "firmware"],
    cwd=args.rtl_root, text=True
).strip()
if dirty_sources:
    parser.error("commit RTL and firmware before staging so baseline.json names the actual sources")

wrapper = (args.rtl_root / "rtl/soc/tt_um_rv32_linux_soc.v").read_text()
new_uart_pins = (re.search(r"\.uart_rx\(ui_in\[3\]\)", wrapper) is not None
                 and re.search(r"assign\s+uo_out\[4\]\s*=\s*uart_tx", wrapper) is not None)
old_uart_pins = (re.search(r"\.uart_rx\(ui_in\[0\]\)", wrapper) is not None
                 and re.search(r"assign\s+uo_out\s*=\s*\{initialized,\s*uart_tx,",
                               wrapper) is not None)
if not (new_uart_pins or old_uart_pins):
    parser.error("unrecognized ASIC UART pin mapping; update staging metadata")

subprocess.run([sys.executable, str(ROOT / "tt/stage_sky26d.py"),
                *sys.argv[1:]], check=True)
if new_uart_pins:
    stage = args.stage.resolve()
    info = stage / "info.yaml"
    content = info.read_text()
    changes = {
        '  ui[0]: "UART RX"': '  ui[0]: ""',
        '  ui[3]: ""': '  ui[3]: "UART RX"',
        '  uo[4]: "PSRAM 3 CS#"': '  uo[4]: "UART TX"',
        '  uo[6]: "UART TX"': '  uo[6]: "PSRAM 3 CS#"',
    }
    for before, after in changes.items():
        if content.count(before) != 1:
            raise RuntimeError(f"staged info.yaml lacks expected pin label: {before}")
        content = content.replace(before, after)
    info.write_text(content)
    baseline = stage / "baseline.json"
    metadata = json.loads(baseline.read_text())
    metadata["uart_rx_pin"] = "ui_in[3]"
    metadata["uart_tx_pin"] = "uo_out[4]"
    metadata["psram3_cs_pin"] = "uo_out[6]"
    baseline.write_text(json.dumps(metadata, indent=2) + "\n")
    subprocess.run(["git", "add", "info.yaml", "baseline.json"],
                   cwd=stage, check=True)
    subprocess.run(["git", "-c", "user.name=Physical Baseline",
                    "-c", "user.email=baseline@example.invalid",
                    "commit", "--amend", "--no-edit", "-q"],
                   cwd=stage, check=True)
