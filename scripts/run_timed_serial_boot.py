#!/usr/bin/env python3
"""Run the full serial boot simulation with a real wall-clock deadline."""

import argparse
from datetime import datetime, timezone
from pathlib import Path
import signal
import subprocess
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--deadline-utc", required=True)
    parser.add_argument("--max-cycles", type=int, required=True)
    parser.add_argument("--report-first", type=int, default=100_000_000)
    parser.add_argument("--report-step", type=int, default=100_333_333)
    args = parser.parse_args()

    deadline = datetime.fromisoformat(args.deadline_utc.replace("Z", "+00:00"))
    if deadline.tzinfo is None or args.max_cycles <= 0:
        parser.error("deadline must include a timezone and max-cycles must be positive")
    deadline = deadline.astimezone(timezone.utc)
    seconds_left = deadline.timestamp() - time.time()
    if seconds_left <= 0:
        parser.error("deadline has already passed")

    args.log.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(args.binary),
        f"+max_cycles={args.max_cycles}",
        f"+report_first={args.report_first}",
        f"+report_step={args.report_step}",
    ]
    with args.log.open("w", buffering=1) as log:
        now = datetime.now(timezone.utc).isoformat()
        print(f"RUN start_utc={now} deadline_utc={deadline.isoformat()} ",
              f"max_cycles={args.max_cycles} report_step={args.report_step}",
              file=log, flush=True)
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            return_code = process.wait(timeout=max(0, deadline.timestamp() - time.time()))
        except subprocess.TimeoutExpired:
            process.send_signal(signal.SIGINT)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            print(f"WALL_TIMEOUT deadline_utc={deadline.isoformat()}", file=log, flush=True)
            return 124
        print(f"RUN_EXIT code={return_code}", file=log, flush=True)
        return return_code


if __name__ == "__main__":
    raise SystemExit(main())
