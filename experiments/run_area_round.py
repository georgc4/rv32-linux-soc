#!/usr/bin/env python3
"""Run the commit-pinned state-sharing Linux and physical trials unattended."""

from __future__ import annotations

import fcntl
import json
import os
import shutil
import subprocess
import sys
import threading
from datetime import datetime, timezone
from pathlib import Path

from runner import ROOT


SESSION = ROOT / "build/experiments/area-round-live"
IMAGE = "build/experiments/images/no-plist-no-vm-pgtable/flash.bin"
ACCEPTANCE = "experiments/next-state-5x4.json"
PHYSICAL = (
    "experiments/next-state-8x2.json",
    "experiments/next-jumper-repair-8x2.json",
)


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def vm_free_kib() -> int:
    output = subprocess.check_output(
        ["podman", "machine", "ssh", "df", "-Pk", "/var"],
        cwd=ROOT, text=True, timeout=30,
    )
    return int(output.splitlines()[-1].split()[3])


def main() -> int:
    SESSION.mkdir(parents=True, exist_ok=True)
    lock = (SESSION / "scheduler.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("area round is already running", flush=True)
        return 2
    lock.write(f"{os.getpid()}\n")
    lock.flush()
    state_lock = threading.Lock()
    state = {"status": "running", "started_utc": now(), "pid": os.getpid(), "jobs": {}}

    def save() -> None:
        with state_lock:
            temporary = SESSION / "status.json.tmp"
            temporary.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
            temporary.replace(SESSION / "status.json")

    def job(name: str, command: list[str], physical: bool) -> None:
        key = name.replace("/", "-")
        log = SESSION / f"{key}.log"
        if shutil.disk_usage(ROOT).free < 7 * 1024**3:
            error = "macOS free disk below 7 GiB"
        elif physical and vm_free_kib() < 3 * 1024**2:
            error = "Podman VM free disk below 3 GiB"
        else:
            error = None
        if error:
            with state_lock:
                state["jobs"][name] = {"status": "blocked_disk", "error": error,
                                       "ended_utc": now()}
            save()
            print(f"{now()} {name}: {error}", flush=True)
            return
        with log.open("w", buffering=1) as output:
            process = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                       stderr=subprocess.STDOUT)
            with state_lock:
                state["jobs"][name] = {"status": "running", "pid": process.pid,
                                       "started_utc": now(), "command": command,
                                       "log": str(log.relative_to(ROOT))}
            save()
            print(f"{now()} {name}: started pid={process.pid}", flush=True)
            code = process.wait()
        with state_lock:
            state["jobs"][name].update({"status": "finished" if code == 0 else "failed",
                                        "returncode": code, "ended_utc": now()})
        save()
        print(f"{now()} {name}: exit={code}", flush=True)

    def acceptance_lane() -> None:
        job("acceptance", [sys.executable, "experiments/runner.py", "run",
                           ACCEPTANCE, "--all", "--phase", "acceptance",
                           "--flash-image", IMAGE, "--max-cycles", "25000000000",
                           "--timeout-hours", "8"], False)

    def physical_lane() -> None:
        for manifest in PHYSICAL:
            name = f"physical:{Path(manifest).stem}"
            job(name, [sys.executable, "experiments/run_physical_queue.py",
                       manifest, "--timeout-hours", "12"], True)

    save()
    threads = [threading.Thread(target=acceptance_lane),
               threading.Thread(target=physical_lane)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    with state_lock:
        state["status"] = "finished"
        state["ended_utc"] = now()
    save()
    return 0 if all(job["status"] == "finished" for job in state["jobs"].values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
