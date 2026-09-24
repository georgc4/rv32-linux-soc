#!/usr/bin/env python3
"""Pack the RVSB firmware, DTB, and RV32 Image for the 16 MiB NOR."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

FLASH_SIZE = 0x1000000
FW_SLOT_END = 0x40000
MANIFEST_OFF = 0x40000
DTB_OFF = 0x40020
KERNEL_OFF = 0x41000
RVSB = 0x52565342
LNX1 = 0x31584E4C


def pad_words(data):
    return data + b"\x00" * (-len(data) % 4)


def word_sum(data):
    return sum(struct.unpack(f"<{len(data) // 4}I", data)) & 0xFFFFFFFF


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("firmware", type=Path)
    p.add_argument("kernel", type=Path)
    p.add_argument("dtb", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--trim", action="store_true", help="omit unused 0xff tail for simulation")
    args = p.parse_args()

    fw = pad_words(args.firmware.read_bytes())
    image = pad_words(args.kernel.read_bytes())
    dtb = pad_words(args.dtb.read_bytes())
    if not fw or len(fw) > 65535 * 4 or 16 + len(fw) > FW_SLOT_END:
        p.error("firmware does not fit ROM first-stage slot")
    if len(dtb) > KERNEL_OFF - DTB_OFF:
        p.error("DTB does not fit its flash slot")
    if not image or KERNEL_OFF + len(image) > FLASH_SIZE:
        p.error("kernel exceeds NOR capacity")
    if image[56:60] != b"RSC\x05":
        p.error("kernel lacks a RISC-V Image header")
    load_off, runtime = struct.unpack_from("<QQ", image, 8)
    if load_off != 0x400000 or runtime < len(image) or runtime > 0x1c00000 or runtime & 3:
        p.error("kernel RAM placement or runtime extent is invalid")
    if struct.unpack_from(">II", dtb)[0] != 0xD00DFEED:
        p.error("DTB magic is invalid")
    if struct.unpack_from(">I", dtb, 4)[0] > len(dtb):
        p.error("DTB size field exceeds its file")

    fw_header = struct.pack("<4I", RVSB, len(fw) // 4, word_sum(fw), 0)
    manifest = struct.pack("<6I", LNX1, len(image), word_sum(image),
                           len(dtb), word_sum(dtb), runtime)
    blob = bytearray(b"\xff" * (KERNEL_OFF + len(image) if args.trim else FLASH_SIZE))
    blob[:len(fw_header)] = fw_header
    blob[len(fw_header):len(fw_header) + len(fw)] = fw
    blob[MANIFEST_OFF:MANIFEST_OFF + len(manifest)] = manifest
    blob[DTB_OFF:DTB_OFF + len(dtb)] = dtb
    blob[KERNEL_OFF:KERNEL_OFF + len(image)] = image
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(blob)
    meta = {
        "bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest(),
        "firmware_bytes": len(fw), "firmware_entry": "0x80000000",
        "manifest_offset": MANIFEST_OFF, "dtb_offset": DTB_OFF,
        "kernel_offset": KERNEL_OFF, "kernel_ram_address": "0x80400000",
        "kernel_file_bytes": len(image), "kernel_runtime_bytes": runtime,
    }
    args.output.with_suffix(args.output.suffix + ".json").write_text(json.dumps(meta, indent=2) + "\n")
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
