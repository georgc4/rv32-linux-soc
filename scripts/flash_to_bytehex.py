#!/usr/bin/env python3
"""Convert the populated NOR span to byte-wide $readmemh input.

The SPI flash model initializes its full 16 MiB to erased 0xff; the file only
needs to override bytes through the end of the packed kernel.
"""
import json
import hashlib
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: flash_to_bytehex.py flash.bin flash.serial.hex")
flash_path, hex_path = map(Path, sys.argv[1:])
meta = json.loads(flash_path.with_suffix(flash_path.suffix + ".json").read_text())
if flash_path.stat().st_size != 0x1000000:
    raise SystemExit("expected a full 16 MiB NOR image")
if hashlib.sha256(flash_path.read_bytes()).hexdigest() != meta["sha256"]:
    raise SystemExit("NOR image SHA-256 differs from its manifest")
used = meta["kernel_offset"] + meta["kernel_file_bytes"]
if not 0 < used <= 0x1000000:
    raise SystemExit("invalid occupied flash span")
with flash_path.open("rb") as source, hex_path.open("w") as dest:
    remaining = used
    while remaining:
        chunk = source.read(min(1 << 20, remaining))
        if not chunk:
            raise SystemExit("short NOR image")
        dest.write("".join(f"{byte:02x}\n" for byte in chunk))
        remaining -= len(chunk)
print(f"wrote {used} flash bytes to {hex_path}")
