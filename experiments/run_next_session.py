#!/usr/bin/env python3
"""Run the committed next-session manifests unattended in two heavy lanes."""

from __future__ import annotations

import argparse
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


SESSION = ROOT / "build/experiments/next-session-live"
IMAGE = "build/experiments/images/no-plist-no-vm-pgtable/flash.bin"
ARCHITECTURE = "experiments/next-architecture-5x4.json"
PHYSICAL_FIRST = (
    "experiments/next-5x4-baseline.json",
    "experiments/next-5x4-hold.json",
    "experiments/next-5x4-clock.json",
    "experiments/next-8x2-strategy.json",
)
PHYSICAL_AFTER_ACCEPTANCE = (
    ARCHITECTURE,
    "experiments/next-architecture-8x2.json",
)
MIN_MAC_FREE_BYTES = 7 * 1024**3
MIN_VM_FREE_KIB = 3 * 1024**2


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def vm_free_kib() -> int:
    result = subprocess.run(["podman", "machine", "ssh", "df", "-Pk", "/var"],
                            cwd=ROOT, capture_output=True, text=True,
                            check=True, timeout=30)
    return int(result.stdout.splitlines()[-1].split()[3])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", action="store_true", help="print the two lanes only")
    args = parser.parse_args()
    if args.plan:
        print("acceptance:", ARCHITECTURE)
        for manifest in PHYSICAL_FIRST:
            print("physical:", manifest)
        print("physical: wait for acceptance lane")
        for manifest in PHYSICAL_AFTER_ACCEPTANCE:
            print("physical:", manifest)
        return 0

    SESSION.mkdir(parents=True, exist_ok=True)
    lock_file = (SESSION / "scheduler.lock").open("w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("next-session scheduler is already running", flush=True)
        return 2
    lock_file.write(f"{os.getpid()}\n")
    lock_file.flush()
    (SESSION / "scheduler.pid").write_text(f"{os.getpid()}\n")
    state_lock = threading.Lock()
    acceptance_done = threading.Event()
    state = {"started_utc": now(), "pid": os.getpid(), "jobs": {}, "status": "running"}

    def save() -> None:
        with state_lock:
            temporary = SESSION / "status.json.tmp"
            temporary.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
            temporary.replace(SESSION / "status.json")

    def run_job(lane: str, manifest: str) -> int:
        key = f"{lane}:{Path(manifest).stem}"
        if shutil.disk_usage(ROOT).free < MIN_MAC_FREE_BYTES:
            error = "macOS free disk below 7 GiB; refusing another heavy job"
        elif lane == "physical" and vm_free_kib() < MIN_VM_FREE_KIB:
            error = "Podman VM free disk below 3 GiB; refusing another PNR job"
        else:
            error = None
        if error:
            with state_lock:
                state["jobs"][key] = {"status": "blocked_disk", "error": error,
                                      "ended_utc": now()}
            save()
            print(f"{now()} {key}: {error}", flush=True)
            return 2
        log = SESSION / f"{key.replace(':', '-')}.log"
        command = ([sys.executable, "experiments/runner.py", "run", manifest,
                    "--all", "--phase", "acceptance", "--flash-image", IMAGE,
                    "--max-cycles", "25000000000", "--timeout-hours", "8"]
                   if lane == "acceptance" else
                   [sys.executable, "experiments/run_physical_queue.py", manifest,
                    "--timeout-hours", "3"])
        with log.open("w", buffering=1) as output:
            process = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                       stderr=subprocess.STDOUT)
            with state_lock:
                state["jobs"][key] = {"status": "running", "pid": process.pid,
                                      "started_utc": now(), "manifest": manifest,
                                      "log": str(log.relative_to(ROOT)),
                                      "command": command}
            save()
            print(f"{now()} {key}: started pid={process.pid} log={log}", flush=True)
            code = process.wait()
        with state_lock:
            state["jobs"][key].update({"status": "finished" if code == 0 else "failed",
                                       "returncode": code, "ended_utc": now()})
        save()
        print(f"{now()} {key}: exit={code}", flush=True)
        return code

    def acceptance_lane() -> None:
        try:
            run_job("acceptance", ARCHITECTURE)
        finally:
            acceptance_done.set()

    def physical_lane() -> None:
        for manifest in PHYSICAL_FIRST:
            run_job("physical", manifest)
        print(f"{now()} physical: waiting for acceptance lane", flush=True)
        acceptance_done.wait()
        for manifest in PHYSICAL_AFTER_ACCEPTANCE:
            run_job("physical", manifest)

    save()
    print(f"{now()} scheduler started pid={os.getpid()}", flush=True)
    threads = [threading.Thread(target=acceptance_lane, name="acceptance"),
               threading.Thread(target=physical_lane, name="physical")]
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
