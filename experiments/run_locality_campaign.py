#!/usr/bin/env python3
"""Run the pinned locality matrix sequentially when existing PNR jobs leave room."""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from runner import ROOT, RUNS, planned_runs, run_one, utc_now, write_result, reuse_verified_acceptance
from run_physical_queue import archive_stage

SESSION = ROOT / "build/experiments/locality-campaign"
CAMPAIGN = ROOT / "experiments/locality-campaign.json"


def resources():
    containers = json.loads(subprocess.check_output(
        ["podman", "ps", "--format", "json"], text=True, timeout=20))
    count = sum("librelane" in c.get("Command", []) for c in containers)
    memory = subprocess.check_output(["podman", "machine", "ssh", "cat", "/proc/meminfo"],
                                     text=True, timeout=20)
    available = int(next(s.split()[1] for s in memory.splitlines() if s.startswith("MemAvailable:")))
    disk = subprocess.check_output(["podman", "machine", "ssh", "df", "-Pk", "/var"],
                                   text=True, timeout=20)
    return {"active_pnr": count, "vm_available_gib": round(available / 1024**2, 2),
            "host_free_gib": round(shutil.disk_usage(ROOT).free / 1024**3, 2),
            "vm_free_gib": round(int(disk.splitlines()[-1].split()[3]) / 1024**2, 2)}


def has_capacity(r):
    return (r["active_pnr"] < 3 and r["vm_available_gib"] >= 5
            and r["host_free_gib"] >= 12 and r["vm_free_gib"] >= 5)


def plan():
    campaign = json.loads(CAMPAIGN.read_text())
    jobs = []
    for entry in campaign["experiments"]:
        manifest = ROOT / entry["manifest"]
        for run in planned_runs(manifest):
            jobs.append({"name": entry["name"], "manifest": str(manifest.relative_to(ROOT)),
                         "run": run, "status": "queued"})
    return jobs


def main():
    global SESSION, CAMPAIGN
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--resources", action="store_true")
    parser.add_argument("--campaign", type=Path, default=CAMPAIGN)
    parser.add_argument("--session", type=Path, default=SESSION)
    args = parser.parse_args()
    CAMPAIGN = args.campaign.resolve()
    SESSION = args.session.resolve()
    if args.resources:
        print(json.dumps(resources(), indent=2))
        return 0
    if args.plan:
        for job in plan():
            print(job["name"], job["run"]["id"], json.dumps(job["run"]["config"]))
        return 0
    SESSION.mkdir(parents=True, exist_ok=True)
    with (SESSION / "scheduler.lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit("locality campaign is already running")
        status_path = SESSION / "status.json"
        if status_path.exists():
            state = json.loads(status_path.read_text())
        else:
            state = {"started_utc": utc_now(), "jobs": plan()}
            # Freeze the source evidence separately from live working files.
            for rel in ["experiments/runner.py", "experiments/physical_profiles.py",
                        "experiments/run_locality_campaign.py", "tt/stage_sky26d.py",
                        "tt/stage_sky26d_uart.py", "tt/librelane_plugin_locality.py",
                        "tt/placement_clusters.tcl", "tt/run_sky130_synth.sh"]:
                dest = SESSION / "flow-source" / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, dest)
        state.update(pid=os.getpid(), status="starting")
        write_result(status_path, state)
        (SESSION / "scheduler.pid").write_text(str(os.getpid()) + "\n")
        for job in state["jobs"]:
            if job["status"] in ("finished", "failed"):
                continue
            run = job["run"]
            current = planned_runs(ROOT / job["manifest"])
            if run["id"] not in [r["id"] for r in current]:
                state.update(status="blocked_source_changed", active=job["name"])
                write_result(status_path, state)
                raise SystemExit("Flow or manifest changed after planning; refusing mismatched provenance")
            while True:
                try:
                    resource = resources()
                    ready = has_capacity(resource)
                except (subprocess.SubprocessError, ValueError, KeyError) as exc:
                    resource = {"error": str(exc)}
                    ready = False
                state.update(status="running" if ready else "waiting_resources",
                             resources=resource, active=job["name"], updated_utc=utc_now())
                write_result(status_path, state)
                if ready:
                    break
                time.sleep(30)
            directory = RUNS / run["id"]
            result_path = directory / "result.json"
            previous = json.loads(result_path.read_text()) if result_path.exists() else {"stages": {}}
            job.update(status="running", started_utc=utc_now())
            write_result(status_path, state)
            print(f"{utc_now()} START {job['name']} {run['id']}", flush=True)
            if "acceptance" not in previous["stages"]:
                try:
                    reuse_verified_acceptance(run["commit"], run["image_sha256"])
                except RuntimeError:
                    manifest = json.loads((ROOT / job["manifest"]).read_text())
                    accepted = run_one(run, "acceptance", ROOT / manifest["flash_image"],
                                       24, 40_000_000_000)
                    if not accepted:
                        job.update(status="failed", ended_utc=utc_now(), reason="Linux acceptance failed")
                        write_result(status_path, state)
                        continue
                else:
                    run_one(run, "reuse-acceptance", None, 24, 40_000_000_000)
            elif previous["stages"]["acceptance"]["status"] != "pass":
                job.update(status="failed", reason="Prior Linux acceptance failed")
                write_result(status_path, state)
                continue
            if "pnr" not in previous["stages"]:
                run_one(run, "pnr", None, 24, 40_000_000_000)
            result = json.loads(result_path.read_text())
            pnr = result["stages"]["pnr"]
            job.update(status="finished" if pnr["status"] == "pass" else "failed",
                       ended_utc=utc_now(), pnr=pnr["status"],
                       timing=pnr.get("timing", {}).get("status", "missing"),
                       area_um2=pnr.get("instance_area_um2"), setup_wns_ns=pnr.get("setup_wns_ns"))
            write_result(status_path, state)
            # Keep all checkpoints until the full run completes, then retain archive + latest ODB.
            archive_stage(directory)
            subprocess.run([sys.executable, str(ROOT / "experiments/visualize.py")], cwd=ROOT, check=True)
            if pnr["status"] == "error" or pnr.get("log") in ("pnr-stage.log", "pnr-config.log"):
                state.update(status="blocked_configuration")
                write_result(status_path, state)
                return 2
        state.update(status="complete", ended_utc=utc_now())
        write_result(status_path, state)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
