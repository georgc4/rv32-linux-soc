#!/usr/bin/env python3
"""View a Mac-hosted experiment ODB on the Ubuntu iMac's own desktop."""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "build/mac-experiments-runs"
IMAGE = "ghcr.io/librelane/librelane:3.0.14"


def desktop_environment() -> dict[str, str]:
    result = subprocess.check_output(["systemctl", "--user", "show-environment"], text=True)
    values = dict(line.split("=", 1) for line in result.splitlines() if "=" in line)
    if not values.get("DISPLAY") or not values.get("XAUTHORITY"):
        raise RuntimeError("the iMac desktop must be logged in with Xwayland active")
    if not Path(values["XAUTHORITY"]).is_file():
        raise RuntimeError("the iMac Xauthority file is missing")
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", help="full experiment run ID or unique prefix")
    args = parser.parse_args()
    if not RUNS.is_mount():
        parser.error(f"read-only Mac experiment mount is not active: {RUNS}")
    matches = [path for path in RUNS.iterdir()
               if path.is_dir() and path.name.startswith(args.run)]
    if len(matches) != 1:
        parser.error("run ID/prefix must match exactly one experiment")
    saved = matches[0] / "latest.odb"
    checkpoints = [saved] if saved.is_file() else list(
        (matches[0] / "pnr-stage/runs/wokwi").rglob("*.odb"))
    if not checkpoints:
        parser.error("no unpacked ODB checkpoint exists for this run")
    odb = max(checkpoints, key=lambda path: path.stat().st_mtime_ns)
    desktop = desktop_environment()
    auth = Path(desktop["XAUTHORITY"])
    relative = odb.relative_to(RUNS)
    command = ["docker", "run", "--rm", "--user", f"{os.getuid()}:{os.getgid()}",
               "--mount", "type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,readonly",
               "--mount", f"type=bind,src={auth},dst={auth},readonly",
               # Bind the parent ext4 directory so Docker's root daemon need not
               # stat the user-only FUSE mount itself. The container runs as us.
               "--mount", f"type=bind,src={ROOT / 'build'},dst=/build,readonly,bind-propagation=rslave",
               "--env", f"DISPLAY={desktop['DISPLAY']}",
               "--env", f"XAUTHORITY={auth}",
               "--env", "QT_X11_NO_MITSHM=1",
               "--entrypoint", "openroad", IMAGE,
               "-no_init", "-gui", "-db", str(Path("/build/mac-experiments-runs") / relative)]
    print(f"Opening Mac checkpoint {relative} on the iMac desktop", flush=True)
    return subprocess.run(command, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
