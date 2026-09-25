#!/usr/bin/env python3
"""Refresh the Tiny Tapeout src/ snapshot from the canonical RTL tree."""

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = sorted((ROOT / "rtl").glob("**/*.v"))
DEST = ROOT / "src"
DEST.mkdir(exist_ok=True)
for source in SOURCES:
    shutil.copy2(source, DEST / source.name)
print(f"Copied {len(SOURCES)} RTL files to {DEST}")
