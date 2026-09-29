#!/usr/bin/env python3
"""Collect the PS4's independent, commit-pinned Linux acceptance simulation."""
import fcntl
import json
import os
import re
import subprocess
import sys
import time

from collect_ps4_worker import remote, SESSION
from runner import ROOT, RUNS, utc_now, write_result


def main():
    status_path = SESSION / "ps4-acceptance.json"
    with (SESSION / "ps4-acceptance-collector.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        state = json.loads(status_path.read_text())
        root = state["remote_root"]
        directory = RUNS / state["run"]["id"]
        state["collector_pid"] = os.getpid()
        while True:
            try:
                probe = remote(f"if test -f {root}/acceptance-exit.code; then cat {root}/acceptance-exit.code; "
                               f"elif kill -0 $(cat {root}/acceptance.pid) 2>/dev/null; then echo running; "
                               "else echo lost; fi", capture_output=True, text=True, timeout=45)
                if probe.returncode:
                    raise RuntimeError(probe.stderr.strip())
                value = probe.stdout.strip()
                if value.isdigit():
                    code = int(value)
                    break
                if value != "running":
                    state.update(status="needs_attention", error=f"Worker state: {value}")
                    write_result(status_path, state)
                    return 2
                state.update(status="running", updated_utc=utc_now())
                state.pop("error", None)
            except (subprocess.SubprocessError, RuntimeError) as exc:
                state.update(status="connection_unavailable", error=str(exc), updated_utc=utc_now())
            write_result(status_path, state)
            time.sleep(30)
        state.update(status="collecting", returncode=code)
        write_result(status_path, state)
        for source, target in [("acceptance.log", "acceptance-ps4.log"),
                               ("acceptance-compile.log", "acceptance-ps4-compile.log"),
                               ("acceptance-worker.log", "acceptance-ps4-worker.log")]:
            temporary = directory / (target + ".tmp")
            with temporary.open("wb") as output:
                remote(f"if test -f {root}/{source}; then cat {root}/{source}; fi",
                       stdout=output, check=True)
            temporary.replace(directory / target)
        text = (directory / "acceptance-ps4.log").read_text(errors="replace")
        marker = re.search(r"ACCEPTANCE ash_program=pass cycles=(\d+).*?rx_bytes=(\d+)", text)
        passed = code == 0 and marker is not None and "SHELL_PROMPT cycles=" in text and \
            "PASS BusyBox ash executed /bin/acceptance_smoke" in text
        result = {"status": "pass" if passed else "timeout" if code == 124 else "failed",
                  "returncode": code, "image_sha256": state["run"]["image_sha256"],
                  "harness_sha256": state["harness_sha256"],
                  "serial_model_sha256": state["serial_model_sha256"],
                  "execution_host": "ps4", "architecture": state["architecture"],
                  "container_image_id": state["image_id"], "log": "acceptance-ps4.log",
                  "compile_log": "acceptance-ps4-compile.log",
                  "started_utc": state["started_utc"], "ended_utc": utc_now()}
        if marker:
            result.update(cycles=int(marker.group(1)), uart_rx_bytes=int(marker.group(2)))
        write_result(directory / "acceptance-ps4-result.json", result)
        with (directory / "result.lock").open("a+") as result_lock:
            fcntl.flock(result_lock, fcntl.LOCK_EX)
            aggregate = json.loads((directory / "result.json").read_text())
            if "acceptance" not in aggregate["stages"]:
                aggregate["stages"]["acceptance"] = result
                write_result(directory / "result.json", aggregate)
            # Preserve separately if the Mac has already produced an acceptance result.
        subprocess.run([sys.executable, str(ROOT / "experiments/visualize.py")], cwd=ROOT, check=True)
        state.update(status="finished", acceptance=result["status"], ended_utc=utc_now())
        write_result(status_path, state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
