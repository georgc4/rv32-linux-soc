#!/usr/bin/env python3
"""Validate image headers and record actual flash/RAM size requirements."""
import hashlib
import json
import pathlib
import struct
import sys

out = pathlib.Path(sys.argv[1])
paths = {name: out / name for name in ("Image", "rv32-linux-soc.dtb", "initramfs.cpio", "busybox", "digit_demo", "acceptance_smoke")}
kernel = paths["Image"].read_bytes()
dtb = paths["rv32-linux-soc.dtb"].read_bytes()

assert len(kernel) >= 64 and kernel[56:60] == b"RSC\x05", "bad RISC-V Image header"
load_offset, runtime_size = struct.unpack_from("<QQ", kernel, 8)
assert load_offset == 0x400000, "RV32 Image is not placed 4 MiB after RAM base"
assert runtime_size >= len(kernel), "kernel runtime size is smaller than file"
assert struct.unpack_from(">I", dtb)[0] == 0xD00DFEED, "bad DTB magic"
assert struct.unpack_from(">I", dtb, 4)[0] == len(dtb), "bad DTB size"
assert paths["initramfs.cpio"].read_bytes()[:6] in (b"070701", b"070702"), "bad initramfs"
for name in ("busybox", "digit_demo", "acceptance_smoke"):
    elf = paths[name].read_bytes()
    assert elf[:5] == b"\x7fELF\x01" and struct.unpack_from("<H", elf, 18)[0] == 243, name

flash_bytes = 16 * 1024 * 1024
ram_bytes = 32 * 1024 * 1024
firmware_flash_allowance = 256 * 1024
dtb_flash_allowance = 4 * 1024
firmware_ram_reservation = 4 * 1024 * 1024
flash_room = flash_bytes - firmware_flash_allowance - dtb_flash_allowance
ram_room = ram_bytes - firmware_ram_reservation

manifest = {
    "kernel_version": "6.12.111",
    "busybox_version": "1.37.0",
    "kernel_load_address": f"0x{0x80000000 + load_offset:08x}",
    "kernel_runtime_bytes": runtime_size,
    "kernel_file_bytes": len(kernel),
    "flash_kernel_room_bytes": flash_room,
    "kernel_fits_flash_allowance": len(kernel) <= flash_room,
    "kernel_fits_post_firmware_ram": runtime_size <= ram_room,
    "artifacts": {
        name: {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        for name, path in paths.items()
    },
}
(out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps({k: v for k, v in manifest.items() if k != "artifacts"}, indent=2))
if not manifest["kernel_fits_flash_allowance"] or not manifest["kernel_fits_post_firmware_ram"]:
    sys.exit("image does not fit the provisional flash or RAM allowance")
