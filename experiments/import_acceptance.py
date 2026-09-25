#!/usr/bin/env python3
"""Attach a completed local serial acceptance run to an immutable experiment."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

from runner import (ROOT, RTL_SOURCES, RUNS, ensure_worktree,
                    planned_runs, sha256, write_result)


CHECKED_SOURCES = [
    *RTL_SOURCES,
    "firmware/boot_rom.hex",
    "sim/tests/linux_serial_boot_tb.v",
    "sim/models/serial_spi_model.v",
]
COMMAND = "/bin/acceptance_smoke\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--id", required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--flash-image", type=Path, required=True)
    parser.add_argument("--flash-hex", type=Path,
                        default=ROOT / "build/linux/flash.serial.hex")
    args = parser.parse_args()
    matches = [run for run in planned_runs(args.manifest)
               if run["id"].startswith(args.id)]
    if len(matches) != 1:
        parser.error("--id must match exactly one planned experiment")
    run = matches[0]
    run_dir = RUNS / run["id"]
    result_path = run_dir / "result.json"
    if not result_path.is_file():
        parser.error("run the experiment's synthesis or PNR stage first")
    result = json.loads(result_path.read_text())
    if any(result.get(key) != run[key]
           for key in ("commit", "config", "flow_sha256",
                       "pdk_identity", "image_sha256")):
        parser.error("experiment result does not match the current plan")
    if "acceptance" in result["stages"]:
        parser.error("acceptance stage already recorded")

    log = args.log.resolve()
    binary = args.binary.resolve()
    image = args.flash_image.resolve()
    flash_hex = args.flash_hex.resolve()
    if not all(path.is_file() for path in (log, binary, image, flash_hex)):
        parser.error("log, binary, flash image, and serial hex must exist")
    if sha256(image) != run["image_sha256"]:
        parser.error("flash image differs from the planned image hash")

    source = ensure_worktree(run_dir, run["commit"])
    source_hashes = {}
    latest_source_mtime = 0
    for relative in CHECKED_SOURCES:
        working = ROOT / relative
        pinned = source / relative
        if sha256(working) != sha256(pinned):
            parser.error(f"working source differs from commit: {relative}")
        source_hashes[relative] = sha256(working)
        latest_source_mtime = max(latest_source_mtime, working.stat().st_mtime)
    if binary.stat().st_mtime < latest_source_mtime:
        parser.error("simulator binary predates one of its RTL/harness sources")

    content = log.read_text(errors="replace")
    start = re.search(r"^RUN start_utc=([^ ]+)", content, re.MULTILINE)
    marker = re.search(r"^ACCEPTANCE ash_program=pass cycles=(\d+).*?rx_bytes=(\d+)",
                       content, re.MULTILINE)
    tokens = ["RV32 Linux userspace ready", "SHELL_PROMPT cycles=",
              "SHELL_INPUT cycles=", "ACCEPTANCE ash_program=pass",
              "PASS BusyBox ash executed /bin/acceptance_smoke",
              "RUN_EXIT code=0"]
    positions = [content.find(token) for token in tokens]
    if not start or not marker or any(pos < 0 for pos in positions) or positions != sorted(positions):
        parser.error("log lacks ordered userspace, shell, program, and clean-exit evidence")
    if int(marker.group(2)) < len(COMMAND):
        parser.error("guest consumed fewer UART bytes than the shell command")
    start_time = datetime.fromisoformat(start.group(1)).timestamp()
    if any(path.stat().st_mtime > start_time
           for path in (binary, image, flash_hex)):
        parser.error("simulator binary or flash input was modified after run start")
    if log.stat().st_mtime < start_time:
        parser.error("log predates the recorded run start")
    with image.open("rb") as image_stream, flash_hex.open("rt") as hex_stream:
        for hex_line in hex_stream:
            byte = image_stream.read(1)
            if not byte or hex_line != f"{byte[0]:02x}\n":
                parser.error("serial hex does not match the planned flash image")

    log_copy = run_dir / "acceptance.log"
    binary_copy = run_dir / "acceptance-binary"
    if log_copy.exists() or binary_copy.exists():
        parser.error("refusing to replace existing acceptance evidence")
    shutil.copyfile(log, log_copy)
    shutil.copyfile(binary, binary_copy)
    result["stages"]["acceptance"] = {
        "status": "pass", "provenance": "verified_local_run_import",
        "cycles": int(marker.group(1)),
        "uart_rx_bytes": int(marker.group(2)),
        "image_sha256": run["image_sha256"],
        "harness_sha256": source_hashes["sim/tests/linux_serial_boot_tb.v"],
        "serial_model_sha256": source_hashes["sim/models/serial_spi_model.v"],
        "source_files_sha256": source_hashes,
        "binary_sha256": sha256(binary_copy),
        "source_log_sha256": sha256(log),
        "serial_hex_sha256": sha256(flash_hex),
        "importer_sha256": sha256(Path(__file__)),
        "log": "acceptance.log", "binary": "acceptance-binary",
        "started_utc": start.group(1),
        "ended_utc": datetime.fromtimestamp(log.stat().st_mtime, timezone.utc).isoformat(),
    }
    write_result(result_path, result)
    print(f"{run['id']} acceptance: imported pass at cycle {marker.group(1)}")


if __name__ == "__main__":
    main()
