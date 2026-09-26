#!/usr/bin/env python3
"""Run a commit-pinned PNR sweep sequentially and archive each large workspace."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from runner import RUNS, planned_runs, reuse_verified_acceptance, run_one, utc_now


def archive_stage(run_dir: Path) -> None:
    stage = run_dir / "pnr-stage"
    if not stage.is_dir():
        return
    archive = run_dir / "pnr-stage.tar.zst"
    if archive.exists():
        raise RuntimeError(f"refusing to overwrite {archive}")
    temporary = run_dir / "pnr-stage.tar.zst.tmp"
    with subprocess.Popen(["tar", "-cf", "-", "-C", str(run_dir), "pnr-stage"],
                          stdout=subprocess.PIPE) as tar:
        with temporary.open("wb") as output:
            compressed = subprocess.run(["zstd", "-T2", "-3", "-q"],
                                        stdin=tar.stdout, stdout=output, check=True)
        tar.stdout.close()
        if tar.wait() != 0:
            raise RuntimeError(f"tar failed for {stage}")
    subprocess.run(["zstd", "-tq", str(temporary)], check=True)
    temporary.rename(archive)
    shutil.rmtree(stage)
    print(f"{utc_now()} archived {stage} ({archive.stat().st_size / 1048576:.1f} MiB)",
          flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--timeout-hours", type=float, default=3.0)
    args = parser.parse_args()
    if args.timeout_hours <= 0:
        parser.error("timeout must be positive")
    runs = planned_runs(args.manifest)
    print(f"{utc_now()} queued {len(runs)} physical runs", flush=True)
    failures = 0
    for index, run in enumerate(runs, 1):
        run_dir = RUNS / run["id"]
        result_path = run_dir / "result.json"
        prior = json.loads(result_path.read_text()) if result_path.is_file() else {}
        print(f"{utc_now()} [{index}/{len(runs)}] {run['name']} {run['id']}", flush=True)
        if "pnr" not in prior.get("stages", {}):
            run_one(run, "pnr", None, args.timeout_hours, 20_000_000_000)
        result = json.loads(result_path.read_text())
        pnr = result["stages"]["pnr"]
        if pnr["status"] != "pass":
            failures += 1
        if "acceptance" not in result["stages"] and run["image_sha256"]:
            try:
                reuse_verified_acceptance(run["commit"], run["image_sha256"])
            except RuntimeError:
                print(f"{utc_now()} no verified ash pass for exact commit/image; "
                      "acceptance remains pending", flush=True)
            else:
                run_one(run, "reuse-acceptance", None, args.timeout_hours,
                        20_000_000_000)
        archive_stage(run_dir)
        if pnr.get("log") in ("pnr-stage.log", "pnr-config.log") and \
                pnr["status"] != "pass":
            print(f"{utc_now()} stopping after staging/configuration failure", flush=True)
            return 2
    print(f"{utc_now()} physical queue complete: {len(runs)-failures} passed, "
          f"{failures} failed", flush=True)
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
