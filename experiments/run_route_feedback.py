"""Isolated continuation and FastRoute-feedback comparison; preserves old runs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from run_soft_partition_screens import ROOT, OUT, IMAGE, now, sha


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["qualify-partition", "screen-grt-feedback"])
    args = parser.parse_args()
    winner = OUT / "four-part-seed-60"
    screen = json.loads((winner / "result.json").read_text())
    if screen["status"] != "screen_pass" or screen["global_overflow"] != 0:
        raise RuntimeError("Partition candidate has not passed its congestion gate")
    config = json.loads((winner / "config.json").read_text())
    feedback = args.mode == "screen-grt-feedback"
    directory = OUT / ("four-part-grt-feedback-60" if feedback else "four-part-qualification")
    directory.mkdir(exist_ok=False)
    if feedback:
        state = winner / "initial-state.json"
        config["PL_ROUTABILITY_DRIVEN"] = True
        config["meta"] = {"version": 1, "flow": "Classic", "substituting_steps": {
            "OpenROAD.GlobalPlacement": "RouterFeedback.GlobalPlacement"}}
        start = "RouterFeedback.GlobalPlacement"
        stop = ["--to", "OpenROAD.GlobalRouting"]
    else:
        state = winner / "runs/screen/12-openroad-globalrouting/state_out.json"
        start = "OpenROAD.CheckAntennas"
        stop = []
        config["RUN_KLAYOUT_DRC"] = True
        for kind in ("SETUP", "HOLD", "MAX_SLEW", "MAX_CAP"):
            config[kind + "_VIOLATION_CORNERS"] = ["*"]
    cp = directory / "config.json"
    cp.write_text(json.dumps(config, indent=2) + "\n")
    command = ["podman", "run", "--rm", "--name", "rv32-" + args.mode,
               "--network", "none", "-v", f"{Path.home()}:{Path.home()}",
               "-w", str(directory)]
    plugin = ROOT / "experiments/route_feedback/librelane_plugin_route_feedback.py"
    if feedback:
        command += ["-e", "PYTHONPATH=" + str(plugin.parent)]
    command += [IMAGE, "python", "-m", "librelane", "--manual-pdk",
                "--pdk-root", str(Path.home() / ".volare"), "--design-dir", str(directory),
                "--run-tag", "wokwi", "--with-initial-state", str(state),
                "--from", start, *stop, "--jobs", "4", "--hide-progress-bar", str(cp)]
    record = {"status": "running", "started_utc": now(), "pid": os.getpid(),
              "mode": args.mode, "command": command, "qualification": False,
              "rtl_commit": screen["rtl_commit"], "source_screen": str(winner / "result.json"),
              "config_sha256": sha(cp), "initial_state_sha256": sha(state),
              "initial_odb_sha256": sha(Path(json.loads(state.read_text())["odb"])),
              "worker_sha256": sha(Path(__file__)),
              "plugin_sha256": sha(plugin) if feedback else None,
              "image_id": subprocess.check_output(
                  ["podman", "image", "inspect", IMAGE, "--format", "{{.Id}}"], text=True).strip()}
    result = directory / "result.json"
    result.write_text(json.dumps(record, indent=2) + "\n")
    with (directory / "worker.log").open("w") as log:
        rc = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
    record.update(returncode=rc, ended_utc=now(), status="failed" if rc else "flow_completed_review_required")
    run = directory / "runs/wokwi"
    if feedback:
        logs = list(run.glob("*-openroad-globalrouting/openroad-globalrouting.log"))
        if logs:
            text = logs[-1].read_text()
            totals = re.findall(r"^Total\s+\d+\s+\d+\s+[\d.]+%\s+\d+\s*/\s*\d+\s*/\s*(\d+)", text, re.M)
            lengths = re.findall(r"Total wirelength: ([\d.]+) um", text)
            record["global_overflow"] = int(totals[-1]) if totals else None
            record["wirelength_um"] = float(lengths[-1]) if lengths else None
        record["status"] = "screen_pass" if rc == 0 and record.get("global_overflow") == 0 else "screen_rejected"
    else:
        from runner import audit_final_timing
        final = run / "final/metrics.json"
        sta = list(run.glob("*-openroad-stapostpnr/state_out.json"))
        metrics = json.loads(final.read_text()) if final.exists() else (
            json.loads(sta[-1].read_text())["metrics"] if sta else {})
        record["final_timing_audit"] = audit_final_timing(metrics, run / "resolved.json")
        # A successful tool exit is not enough to assert full qualification.
        # DRC/LVS/antenna reports and final artifacts still require review.
    record["log_tail"] = (directory / "worker.log").read_text(errors="replace").splitlines()[-20:]
    result.write_text(json.dumps(record, indent=2) + "\n")


if __name__ == "__main__":
    main()
