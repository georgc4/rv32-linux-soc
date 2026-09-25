#!/usr/bin/env python3
"""Derive reproducible Linux 6.12 boot-time experiment configs."""

import argparse
from pathlib import Path

BASE = Path(__file__).with_name("kernel-6.12.111.config")
CHANGES = {
    "no-plist": ("DEBUG_PLIST",),
    "no-plist-no-vm-pgtable": ("DEBUG_PLIST", "DEBUG_VM_PGTABLE"),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("variant", choices=CHANGES)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = BASE.read_text()
    for name in CHANGES[args.variant]:
        before = f"CONFIG_{name}=y"
        if data.count(before) != 1:
            raise RuntimeError(f"expected exactly one {before} in {BASE}")
        data = data.replace(before, f"# CONFIG_{name} is not set")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(data)
    print(args.output)


if __name__ == "__main__":
    main()
