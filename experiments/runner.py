#!/usr/bin/env python3
"""Run immutable Git-revision synthesis, SKY26d PNR, and Linux acceptance trials."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import os
import re
import shutil
import signal
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "build" / "experiments" / "runs"
MATRIX_DEFAULTS = {
    "abc_delay_ps": [None],
    "synth_strategy": ["AREA 0"],
    "synth_abc_area_use_nf": [False],
    "clock_period_ns": [50.0],
    "placement_density_pct": [60.0],
    "hold_margin_ns": [0.1],
    "grt_hold_margin_ns": [0.05],
}
RTL_SOURCES = [
    "rtl/soc/soc_top.v", "rtl/cpu/rv32i_core.v", "rtl/cpu/rv32_priv_unit.v",
    "rtl/cpu/rv32_mdu.v", "rtl/interconnect/physical_bus.v",
    "rtl/interconnect/sv32_bus_adapter.v", "rtl/peripherals/boot_rom.v",
    "rtl/peripherals/clint_timer.v", "rtl/peripherals/uart16550_lite.v",
    "rtl/peripherals/plic_lite.v", "rtl/memory/serial_mem_bridge.v",
]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def git(*args: str, cwd: Path = ROOT) -> str:
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def planned_runs(manifest: Path) -> list[dict]:
    data = json.loads(manifest.read_text())
    if set(data) - {"name", "revisions", "matrix", "flash_image"}:
        raise ValueError("manifest contains unsupported top-level keys")
    if not data.get("revisions"):
        raise ValueError("manifest needs at least one revision")
    supplied = data.get("matrix", {})
    if set(supplied) - set(MATRIX_DEFAULTS):
        raise ValueError("manifest matrix contains unsupported knobs")
    matrix = {key: supplied.get(key, default) for key, default in MATRIX_DEFAULTS.items()}
    if any(not isinstance(values, list) or not values for values in matrix.values()):
        raise ValueError("every matrix entry must be a nonempty list")
    flow_hash = hashlib.sha256(b"".join(
        path.read_bytes() for path in (
            ROOT / "experiments/runner.py", ROOT / "tt/stage_sky26d.py",
            ROOT / "tt/run_sky130_synth.sh", ROOT / "sim/tests/linux_serial_boot_tb.v",
            ROOT / "sim/models/serial_spi_model.v",
        ))).hexdigest()
    pdk_root = Path(os.environ.get("PDK_ROOT", Path.home() / ".volare")) / "sky130A"
    pdk_source = pdk_root / "SOURCES"
    liberty = pdk_root / "libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    pdk_identity = {
        "source": pdk_source.read_text().strip() if pdk_source.is_file() else "unavailable",
        "liberty_sha256": sha256(liberty) if liberty.is_file() else "unavailable",
    }
    image_path = ROOT / data["flash_image"] if data.get("flash_image") else None
    image_sha256 = sha256(image_path) if image_path is not None else None
    runs = []
    for revision in data["revisions"]:
        commit = git("rev-parse", "--verify", f"{revision['ref']}^{{commit}}")
        for values in itertools.product(*matrix.values()):
            config = dict(zip(matrix, values))
            if config["abc_delay_ps"] is not None and (
                not isinstance(config["abc_delay_ps"], int) or config["abc_delay_ps"] < 0
            ):
                raise ValueError("abc_delay_ps must be null or a nonnegative integer")
            if config["synth_strategy"] not in [f"{kind} {level}"
                                                for kind in ("AREA", "DELAY")
                                                for level in range(4)] + ["DELAY 4"]:
                raise ValueError("invalid LibreLane synth strategy")
            if not 0 < config["clock_period_ns"] or not 0 < config["placement_density_pct"] < 100:
                raise ValueError("clock period and placement density are outside allowed ranges")
            canonical = json.dumps({"commit": commit, "config": config,
                                    "flow_sha256": flow_hash,
                                    "pdk_identity": pdk_identity,
                                    "image_sha256": image_sha256}, sort_keys=True,
                                   separators=(",", ":"))
            run_id = f"{commit[:12]}-{hashlib.sha256(canonical.encode()).hexdigest()[:12]}"
            runs.append({"id": run_id, "name": revision.get("label", revision["ref"]),
                         "commit": commit, "config": config, "flow_sha256": flow_hash,
                         "pdk_identity": pdk_identity,
                         "image_sha256": image_sha256})
    if len({run["id"] for run in runs}) != len(runs):
        raise ValueError("matrix contains duplicate experiments")
    return runs


def write_result(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def run_logged(command: list[str], cwd: Path, log_path: Path,
               timeout_seconds: float, env: dict | None = None) -> tuple[str, int | None]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", buffering=1) as log:
        print(f"COMMAND {json.dumps(command)}", file=log, flush=True)
        print(f"START {utc_now()}", file=log, flush=True)
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            print(f"TIMEOUT {utc_now()}", file=log, flush=True)
            return "timeout", None
        print(f"EXIT {code} {utc_now()}", file=log, flush=True)
        return ("pass" if code == 0 else "failed"), code


def ensure_worktree(run_dir: Path, commit: str) -> Path:
    source = run_dir / "source"
    if source.exists():
        if git("rev-parse", "HEAD", cwd=source) != commit:
            raise RuntimeError(f"existing worktree has wrong commit: {source}")
    else:
        subprocess.run(["git", "worktree", "add", "--detach", str(source), commit],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    return source


def mapped_cells(module_name: str, modules: dict) -> int:
    count = 0
    for cell in modules[module_name]["cells"].values():
        kind = cell["type"]
        if kind.startswith("sky130_fd_sc_hd__"):
            count += 1
        elif kind in modules:
            count += mapped_cells(kind, modules)
        else:
            raise RuntimeError(f"unknown mapped cell/module type: {kind}")
    return count


def synthesize(run: dict, run_dir: Path, source: Path, timeout: float) -> dict:
    output = run_dir / "synth"
    env = os.environ.copy()
    env["RTL_ROOT"] = str(source)
    env["SYNTH_RUN_DIR"] = str(output)
    delay = run["config"]["abc_delay_ps"]
    if delay is None:
        env.pop("ABC_DELAY_PS", None)
    else:
        env["ABC_DELAY_PS"] = str(delay)
    status, code = run_logged(["bash", str(ROOT / "tt/run_sky130_synth.sh")],
                              source, run_dir / "synth-command.log", timeout, env)
    result = {"status": status, "returncode": code, "log": "synth-command.log"}
    yosys_log = output / "yosys.log"
    netlist = output / "tt_um_rv32_linux_soc_mapped.json"
    if yosys_log.exists():
        matches = re.findall(r"Chip area for top module .*?: ([0-9.]+)",
                             yosys_log.read_text(errors="replace"))
        if matches:
            result["mapped_area_um2"] = float(matches[-1])
    if netlist.exists():
        modules = json.loads(netlist.read_text())["modules"]
        result["mapped_cells"] = mapped_cells("tt_um_rv32_linux_soc", modules)
    return result


def collect_pnr_metrics(stage: Path) -> dict:
    run_root = stage / "runs" / "wokwi"
    result = {}
    resolved = run_root / "resolved.json"
    if resolved.is_file():
        revision = re.search(r"ciel/sky130/versions/([0-9a-f]{40})",
                             resolved.read_text(errors="replace"))
        if revision:
            result["physical_pdk_revision"] = revision.group(1)
    for path in sorted(run_root.glob("*/or_metrics_out.json"),
                       key=lambda p: int(p.parent.name.split("-", 1)[0])):
        values = json.loads(path.read_text())
        if "design__instance__area__stdcell" in values:
            result["instance_area_um2"] = values["design__instance__area__stdcell"]
            result["area_stage"] = path.parent.name
        if "design__core__area" in values:
            result["core_area_um2"] = values["design__core__area"]
        if "design__instance__utilization__stdcell" in values:
            result["utilization"] = values["design__instance__utilization__stdcell"]
        for key, value in values.items():
            if key.startswith("timing__setup__wns__corner:"):
                result["setup_wns_ns"] = value
                result["timing_stage"] = path.parent.name
            if key.startswith("timing__setup_r2r__ws__corner:"):
                result["setup_r2r_ws_ns"] = value
    return result


def place_and_route(run: dict, run_dir: Path, source: Path, timeout: float) -> dict:
    config = run["config"]
    stage = run_dir / "pnr-stage"
    command = [sys.executable, str(ROOT / "tt/stage_sky26d.py"),
               "--rtl-root", str(source), "--stage", str(stage),
               "--clock-period-ns", str(config["clock_period_ns"]),
               "--density-pct", str(config["placement_density_pct"]),
               "--synth-strategy", config["synth_strategy"],
               "--hold-margin-ns", str(config["hold_margin_ns"]),
               "--grt-hold-margin-ns", str(config["grt_hold_margin_ns"])]
    if config["synth_abc_area_use_nf"]:
        command.append("--synth-abc-area-use-nf")
    status, code = run_logged(command, ROOT, run_dir / "pnr-stage.log", 600)
    if status != "pass":
        return {"status": status, "returncode": code, "log": "pnr-stage.log"}
    python = ROOT / "build/sky130/venv/bin/python"
    if not python.is_file():
        raise FileNotFoundError(f"LibreLane 3.0.14 runtime missing: {python}")
    env = os.environ.copy()
    env["PATH"] = str(python.parent) + os.pathsep + env.get("PATH", "")
    env.setdefault("PDK_ROOT", str(Path.home() / ".volare"))
    env.setdefault("DYLD_FALLBACK_LIBRARY_PATH", "/opt/homebrew/lib")
    tool = stage / "tt/tt_tool.py"
    status, code = run_logged([str(python), str(tool), "--create-user-config"],
                              stage, run_dir / "pnr-config.log", 600, env)
    if status != "pass":
        return {"status": status, "returncode": code, "log": "pnr-config.log"}
    status, code = run_logged([str(python), str(tool), "--harden"],
                              stage, run_dir / "pnr.log", timeout, env)
    gds = list((stage / "runs" / "wokwi").rglob("*.gds"))
    result = {"status": status if status != "pass" or gds else "failed",
              "returncode": code, "log": "pnr.log", "gds_present": bool(gds)}
    result["librelane_version"] = subprocess.check_output(
        [str(python), "-c", "from importlib.metadata import version; print(version('librelane'))"],
        text=True).strip()
    result.update(collect_pnr_metrics(stage))
    return result


def cached_acceptance(commit: str, image_hash: str, harness_hash: str,
                      model_hash: str) -> tuple[str, dict] | None:
    for path in sorted(RUNS.glob("*/result.json")):
        prior = json.loads(path.read_text())
        stage = prior.get("stages", {}).get("acceptance", {})
        log = path.parent / "acceptance.log"
        if (prior.get("commit") == commit and stage.get("status") == "pass"
                and stage.get("image_sha256") == image_hash
                and stage.get("harness_sha256") == harness_hash
                and stage.get("serial_model_sha256") == model_hash
                and log.is_file()):
            content = log.read_text(errors="replace")
            if ("ACCEPTANCE ash_program=pass" in content and
                    "PASS BusyBox ash executed /bin/acceptance_smoke" in content):
                return prior["id"], stage
    return None


def run_acceptance(run_dir: Path, source: Path, flash_image: Path,
                   timeout: float, max_cycles: int) -> dict:
    image = flash_image.resolve()
    if not image.is_file():
        raise FileNotFoundError(f"flash image missing: {image}")
    image_hash = sha256(image)
    harness_hash = sha256(ROOT / "sim/tests/linux_serial_boot_tb.v")
    model_hash = sha256(ROOT / "sim/models/serial_spi_model.v")
    commit = git("rev-parse", "HEAD", cwd=source)
    cached = cached_acceptance(commit, image_hash, harness_hash, model_hash)
    if cached is not None:
        source_id, stage = cached
        return {**stage, "reused_from_run": source_id,
                "log": f"../{source_id}/acceptance.log"}
    linux_build = source / "build/linux"
    linux_build.mkdir(parents=True, exist_ok=True)
    local_image = linux_build / "flash.bin"
    shutil.copyfile(image, local_image)
    image_meta = image.with_suffix(image.suffix + ".json")
    if not image_meta.is_file():
        raise FileNotFoundError(f"flash image manifest missing: {image_meta}")
    shutil.copyfile(image_meta, local_image.with_suffix(local_image.suffix + ".json"))
    if sha256(local_image) != image_hash:
        raise RuntimeError("flash image changed during experiment setup")
    hex_file = linux_build / "flash.serial.hex"
    subprocess.run([sys.executable, str(ROOT / "scripts/flash_to_bytehex.py"),
                    str(local_image), str(hex_file)], cwd=source, check=True,
                   stdout=subprocess.DEVNULL)
    binary_dir = run_dir / "verilator"
    command = ["verilator", "--binary", "--timing", "-O3", "-j", "4", "-Wno-fatal",
               "-CFLAGS", "-O3", "--top-module", "linux_serial_boot_tb",
               "--Mdir", str(binary_dir),
               str(ROOT / "sim/tests/linux_serial_boot_tb.v"),
               str(ROOT / "sim/models/serial_spi_model.v")]
    command += [str(source / path) for path in RTL_SOURCES]
    status, code = run_logged(command, source, run_dir / "acceptance-compile.log", 1800)
    result = {"status": status, "returncode": code, "image_sha256": image_hash,
              "harness_sha256": harness_hash,
              "serial_model_sha256": model_hash,
              "log": "acceptance.log"}
    if status != "pass":
        result["log"] = "acceptance-compile.log"
        return result
    binary = binary_dir / "Vlinux_serial_boot_tb"
    status, code = run_logged([str(binary), f"+max_cycles={max_cycles}",
                               "+report_first=100000000", "+report_step=100333333"],
                              source, run_dir / "acceptance.log", timeout)
    text = (run_dir / "acceptance.log").read_text(errors="replace")
    marker = re.search(r"ACCEPTANCE ash_program=pass cycles=(\d+).*?rx_bytes=(\d+)", text)
    proven = (status == "pass" and marker is not None and
              "SHELL_PROMPT cycles=" in text and
              "PASS BusyBox ash executed /bin/acceptance_smoke" in text)
    result.update({"status": "pass" if proven else ("failed" if status == "pass" else status),
                   "returncode": code})
    if marker:
        result["cycles"] = int(marker.group(1))
        result["uart_rx_bytes"] = int(marker.group(2))
    return result


def run_one(run: dict, phase: str, flash_image: Path | None,
            timeout_hours: float, max_cycles: int) -> bool:
    run_dir = RUNS / run["id"]
    result_path = run_dir / "result.json"
    if result_path.exists():
        result = json.loads(result_path.read_text())
        if (result["commit"] != run["commit"] or result["config"] != run["config"]
                or result["flow_sha256"] != run["flow_sha256"]
                or result["pdk_identity"] != run["pdk_identity"]
                or result.get("image_sha256") != run["image_sha256"]):
            raise RuntimeError(f"result ID collision: {run['id']}")
    else:
        result = {**run, "created_utc": utc_now(), "stages": {}}
        write_result(result_path, result)
    source = ensure_worktree(run_dir, run["commit"])
    stages = ["synth", "pnr", "acceptance"] if phase == "all" else [phase]
    passed = True
    for stage_name in stages:
        if stage_name in result["stages"]:
            raise RuntimeError(f"{run['id']} already has {stage_name}; use a new config/revision")
        print(f"{run['id']} {stage_name}: started", flush=True)
        started = utc_now()
        try:
            if stage_name == "synth":
                value = synthesize(run, run_dir, source, 1800)
            elif stage_name == "pnr":
                value = place_and_route(run, run_dir, source, timeout_hours * 3600)
            else:
                if flash_image is None:
                    raise ValueError("--flash-image is required for acceptance")
                if run["image_sha256"] is None:
                    raise ValueError("manifest flash_image is required for acceptance")
                if sha256(flash_image.resolve()) != run["image_sha256"]:
                    raise ValueError("flash image differs from the planned SHA-256")
                value = run_acceptance(run_dir, source, flash_image,
                                       timeout_hours * 3600, max_cycles)
        except Exception as exc:
            value = {"status": "error", "error": f"{type(exc).__name__}: {exc}"}
        value["started_utc"] = started
        value["ended_utc"] = utc_now()
        result["stages"][stage_name] = value
        write_result(result_path, result)
        print(f"{run['id']} {stage_name}: {value['status']}", flush=True)
        if value["status"] != "pass":
            passed = False
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    plan = sub.add_parser("plan", help="show commit/config experiment IDs")
    plan.add_argument("manifest", type=Path)
    execute = sub.add_parser("run", help="run one immutable experiment stage")
    execute.add_argument("manifest", type=Path)
    selection = execute.add_mutually_exclusive_group(required=True)
    selection.add_argument("--id", help="full ID or unique prefix from plan")
    selection.add_argument("--all", action="store_true", help="run the complete matrix")
    execute.add_argument("--phase", choices=["synth", "pnr", "acceptance", "all"], required=True)
    execute.add_argument("--flash-image", type=Path)
    execute.add_argument("--timeout-hours", type=float, default=8.0)
    execute.add_argument("--max-cycles", type=int, default=20_000_000_000)
    args = parser.parse_args()
    runs = planned_runs(args.manifest)
    if args.action == "plan":
        for run in runs:
            print(run["id"], run["name"], run["commit"], json.dumps(run["config"], sort_keys=True))
        return 0
    if args.timeout_hours <= 0 or args.max_cycles <= 0:
        parser.error("timeout and max-cycles must be positive")
    chosen = runs if args.all else [run for run in runs if run["id"].startswith(args.id)]
    if len(chosen) != (len(runs) if args.all else 1):
        parser.error("--id must match exactly one experiment")
    if args.phase in ("acceptance", "all") and args.flash_image is None:
        parser.error("--flash-image is required for acceptance")
    passed = True
    for run in chosen:
        passed = run_one(run, args.phase, args.flash_image,
                         args.timeout_hours, args.max_cycles) and passed
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
