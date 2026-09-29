#!/usr/bin/env python3
"""Collect the prepared PS4 trial without depending on an interactive SSH session."""
import fcntl
import argparse
import json
import shlex
import subprocess
import sys
import time
from pathlib import Path

from runner import ROOT, RUNS, check_physical_artifacts, collect_pnr_metrics, utc_now, write_result
from run_physical_queue import archive_stage

SESSION = ROOT / "build/experiments/locality-campaign"
STATUS = SESSION / "ps4-worker.json"


def remote(command, **kwargs):
    return subprocess.run(
        ["ssh", "-o", "ConnectTimeout=15", "-o", "ServerAliveInterval=30",
         "-o", "ServerAliveCountMax=3", "imac", "ssh ps4 " + shlex.quote(command)],
        **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", type=Path, default=STATUS)
    args = parser.parse_args()
    status_path = args.status.resolve()
    with status_path.with_suffix(".collector.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        state = json.loads(status_path.read_text())
        root = state["remote_root"]
        control = state.get("control_dir", root)
        directory = RUNS / state["run"]["id"]
        stage = directory / "pnr-stage"
        state["collector_pid"] = __import__("os").getpid()
        while True:
            try:
                probe = remote(f"if test -f {control}/worker-exit.code; then cat {control}/worker-exit.code; "
                               f"elif kill -0 $(cat {control}/worker.pid) 2>/dev/null; then echo running; "
                               "else echo lost; fi", capture_output=True, text=True, timeout=45)
                if probe.returncode:
                    raise RuntimeError(probe.stderr.strip())
                value = probe.stdout.strip()
                if value.isdigit():
                    code = int(value)
                    break
                if value == "lost":
                    state.update(status="needs_attention", error="Worker exited without completion marker")
                    write_result(status_path, state)
                    return 2
                if value != "running":
                    raise RuntimeError(f"Unexpected worker response: {value!r}")
                state.update(status="running", updated_utc=utc_now())
                state.pop("error", None)
            except (subprocess.SubprocessError, RuntimeError) as exc:
                state.update(status="connection_unavailable", error=str(exc), updated_utc=utc_now())
            write_result(status_path, state)
            time.sleep(30)

        state.update(status="collecting", returncode=code, updated_utc=utc_now())
        write_result(status_path, state)
        # Transfer first to a temporary archive; interrupted copies cannot overwrite checkpoints.
        archive = directory / "ps4-results.tar.gz"
        temporary = directory / "ps4-results.tar.gz.tmp"
        remote_stage = root + str(stage)
        with temporary.open("wb") as output:
            remote(f"set -o pipefail; tar cf - -C {shlex.quote(remote_stage)} runs | gzip -1",
                   stdout=output, check=True)
        subprocess.run(["tar", "-tzf", str(temporary)], stdout=subprocess.DEVNULL, check=True)
        temporary.replace(archive)
        subprocess.run(["tar", "-xzf", str(archive), "-C", str(stage)], check=True)
        with (directory / "pnr.log").open("wb") as output:
            remote(f"cat {control}/worker.log", stdout=output, check=True)
        gds = stage / "runs/wokwi/final/gds/tt_um_rv32_linux_soc.gds"
        pnr = {"status": "pass" if code == 0 and gds.is_file() else "failed",
               "returncode": code, "log": "pnr.log", "gds_present": gds.is_file(),
               "execution_host": "ps4", "architecture": state["architecture"],
               "container_image_id": state["image_id"], "librelane_version": "3.0.14",
               "started_utc": state["started_utc"], "ended_utc": utc_now()}
        # The worker uses a copied manual PDK, so resolved paths lack Ciel's revision directory.
        pnr["physical_pdk_revision"] = state["run"]["pdk_identity"]["source"].split()[1]
        pnr.update(collect_pnr_metrics(stage))
        if gds.is_file():
            pnr["checks"] = check_physical_artifacts(directory, stage, pnr.get("physical_pdk_revision"), None)
            if any(check["status"] != "pass" for check in pnr["checks"].values()):
                pnr["status"] = "failed"
        with (directory / "result.lock").open("a+") as result_lock:
            fcntl.flock(result_lock, fcntl.LOCK_EX)
            result = json.loads((directory / "result.json").read_text())
            if "pnr" in result["stages"]:
                raise RuntimeError("Refusing to overwrite an existing PNR result")
            result["stages"]["pnr"] = pnr
            write_result(directory / "result.json", result)
        archive_stage(directory)
        archive.unlink()  # The validated zstd archive now preserves the same checkpoints.
        subprocess.run([sys.executable, str(ROOT / "experiments/visualize.py")], cwd=ROOT, check=True)
        state.update(status="finished", pnr=pnr["status"], ended_utc=utc_now())
        write_result(status_path, state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
