#!/usr/bin/env python3
"""Move completed PNR stage archives from the Mac to the iMac after SHA-256 verification."""

from __future__ import annotations

import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "build/experiments/runs"
REMOTE_ROOT = "/home/carlos/rv32-linux-soc"
MANIFEST = ROOT / "build/experiments/archive-offload-sha256.txt"
FILE_LIST = ROOT / "build/experiments/archive-offload-files.txt"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    archives = sorted(RUNS.glob("*/pnr-stage.tar.zst"))
    if not archives:
        print("No local completed PNR archives to offload")
        return 0
    records = [(archive, sha256(archive), archive.stat()) for archive in archives]
    MANIFEST.write_text("".join(
        f"{digest}  {archive.relative_to(ROOT)}\n"
        for archive, digest, _ in records))
    FILE_LIST.write_text("".join(
        f"{archive.relative_to(ROOT)}\n" for archive, _, _ in records)
        + f"{MANIFEST.relative_to(ROOT)}\n")
    subprocess.run(["rsync", "-a", "--partial", f"--files-from={FILE_LIST}",
                    "./", f"imac:{REMOTE_ROOT}/"], cwd=ROOT, check=True)
    subprocess.run(["ssh", "imac", "cd /home/carlos/rv32-linux-soc && "
                    "sha256sum --status --check "
                    "build/experiments/archive-offload-sha256.txt"], check=True)
    for archive, digest, original in records:
        current = archive.stat()
        if (current.st_size, current.st_mtime_ns) != (original.st_size, original.st_mtime_ns):
            raise RuntimeError(f"archive changed during transfer; keeping local copy: {archive}")
        marker = archive.with_suffix(".remote.json")
        marker.write_text(json.dumps({
            "host": "imac",
            "path": f"{REMOTE_ROOT}/{archive.relative_to(ROOT)}",
            "sha256": digest,
            "bytes": current.st_size,
            "verified_utc": datetime.now(timezone.utc).isoformat(),
        }, indent=2) + "\n")
        archive.unlink()
    print(f"Offloaded and verified {len(records)} archives "
          f"({sum(item[2].st_size for item in records) / 1e9:.2f} GB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
