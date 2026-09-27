#!/usr/bin/env python3
"""Run the 5×4 speed GDS campaigns in sequence without a route timeout."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFESTS = (
    ROOT / "experiments/speed-5x4-physical.json",
    ROOT / "experiments/speed-5x4-timing.json",
)


def main() -> int:
    failures = 0
    for manifest in MANIFESTS:
        print(f"Starting full-GDS queue: {manifest.name}", flush=True)
        code = subprocess.call(
            [sys.executable, "-u", str(ROOT / "experiments/run_physical_queue.py"),
             str(manifest)],
            cwd=ROOT,
        )
        if code:
            failures += 1
            print(f"{manifest.name}: queue exit {code}; continuing to next campaign",
                  flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
