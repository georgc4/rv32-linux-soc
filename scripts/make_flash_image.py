#!/usr/bin/env python3
"""Wrap a first-stage binary for the immutable RVSB boot ROM."""

import argparse
import struct
from pathlib import Path

MAGIC = 0x52565342
MAX_WORDS = 65535


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("payload", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    payload = args.payload.read_bytes()
    if not payload:
        parser.error("payload is empty")
    payload += bytes((-len(payload)) % 4)
    word_count = len(payload) // 4
    if word_count > MAX_WORDS:
        parser.error(f"payload exceeds {MAX_WORDS} words")
    checksum = sum(struct.unpack(f"<{word_count}I", payload)) & 0xFFFFFFFF
    header = struct.pack("<4I", MAGIC, word_count, checksum, 0)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(header + payload)
    print(f"{args.output}: {word_count} words, checksum 0x{checksum:08x}")


if __name__ == "__main__":
    main()
