#!/usr/bin/env python3
"""Build an ignored, reviewable Tiny Tapeout 8x2 physical-flow workspace."""

import argparse
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
TEMPLATE_REV = "83d305501d505b157cd6e9ba87bc8ffd949526fd"
TOOLS_REV = "01d5d2814fa9dd61e9d211e0b235a4a592a9316a"


def checkout(url: str, path: Path, revision: str) -> None:
    if not path.exists():
        subprocess.run(["git", "clone", "--depth", "1", url, str(path)], check=True)
    actual = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
    if actual != revision:
        subprocess.run(["git", "-C", str(path), "fetch", "--depth", "1", "origin", revision], check=True)
        subprocess.run(["git", "-C", str(path), "checkout", "--detach", revision], check=True)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--rtl-root", type=Path, default=ROOT)
parser.add_argument("--stage", type=Path, default=BUILD / "sky130" / "ttsky26d-stage")
parser.add_argument("--template-cache", type=Path, default=BUILD / "ttsky-template")
parser.add_argument("--tools-cache", type=Path, default=BUILD / "tt-support-tools")
parser.add_argument("--clock-period-ns", type=float, default=50.0)
parser.add_argument("--density-pct", type=float, default=60.0)
parser.add_argument("--synth-strategy", choices=[f"{kind} {level}" for kind in ("AREA", "DELAY")
                                                  for level in range(4)] + ["DELAY 4"],
                    default="AREA 0")
parser.add_argument("--synth-abc-area-use-nf", action="store_true")
parser.add_argument("--hold-margin-ns", type=float, default=0.1)
parser.add_argument("--grt-hold-margin-ns", type=float, default=0.05)
args = parser.parse_args()

rtl_root = args.rtl_root.resolve()
stage = args.stage.resolve()
template = args.template_cache.resolve()
tools = args.tools_cache.resolve()
if not 0 < args.clock_period_ns or not 0 < args.density_pct < 100:
    parser.error("clock period must be positive and density must be between 0 and 100")
if args.hold_margin_ns < 0 or args.grt_hold_margin_ns < 0:
    parser.error("hold margins must be nonnegative")
if not (rtl_root / "rtl/soc/tt_um_rv32_linux_soc.v").is_file():
    parser.error(f"RTL source tree missing at {rtl_root}")

checkout("https://github.com/TinyTapeout/ttsky-verilog-template.git", template, TEMPLATE_REV)
checkout("https://github.com/TinyTapeout/tt-support-tools.git", tools, TOOLS_REV)
if stage.exists():
    if (stage / "runs" / "wokwi").exists():
        raise SystemExit(f"Refusing to erase physical results in {stage}; archive them first")
    shutil.rmtree(stage)
shutil.copytree(template, stage, ignore=shutil.ignore_patterns(".git"))

sources = sorted(rtl_root.glob("rtl/**/*.v"))
for source in sources:
    shutil.copy2(source, stage / "src" / source.name)
(stage / "src" / "project.v").unlink()
(stage / "tt").symlink_to(tools, target_is_directory=True)
(stage / "firmware").mkdir()
shutil.copy2(rtl_root / "firmware" / "boot_rom.hex", stage / "firmware" / "boot_rom.hex")

config_path = stage / "src" / "config.json"
config = json.loads(config_path.read_text())
config["CLOCK_PERIOD"] = args.clock_period_ns
config["PL_TARGET_DENSITY_PCT"] = args.density_pct
config["SYNTH_STRATEGY"] = args.synth_strategy
config["SYNTH_ABC_AREA_USE_NF"] = args.synth_abc_area_use_nf
config["PL_RESIZER_HOLD_SLACK_MARGIN"] = args.hold_margin_ns
config["GRT_RESIZER_HOLD_SLACK_MARGIN"] = args.grt_hold_margin_ns
config_path.write_text(json.dumps(config, indent=2) + "\n")

pinout = {
    "ui[0]": "UART RX",
    "uo[0]": "Memory SCK",
    "uo[1]": "PSRAM 0 CS#",
    "uo[2]": "PSRAM 1 CS#",
    "uo[3]": "PSRAM 2 CS#",
    "uo[4]": "PSRAM 3 CS#",
    "uo[5]": "NOR CS#",
    "uo[6]": "UART TX",
    "uo[7]": "Memory ready",
    "uio[0]": "Shared IO0",
    "uio[1]": "Shared IO1",
    "uio[2]": "PSRAM IO2",
    "uio[3]": "PSRAM IO3",
    "uio[4]": "NOR IO2",
    "uio[5]": "NOR IO3",
}
lines = [
    "project:",
    '  title: "RV32 Linux SoC"',
    '  author: "georgc4"',
    '  description: "RV32 Linux SoC with external quad PSRAM and NOR"',
    '  language: "Verilog"',
    "  clock_hz: 20000000",
    '  tiles: "8x2"',
    '  top_module: "tt_um_rv32_linux_soc"',
    "  source_files:",
]
lines += [f'    - "{source.name}"' for source in sources]
lines += ["pinout:"]
for bus in ("ui", "uo", "uio"):
    lines += [f'  {bus}[{bit}]: "{pinout.get(f"{bus}[{bit}]", "")}"' for bit in range(8)]
lines += ["yaml_version: 6"]
(stage / "info.yaml").write_text("\n".join(lines) + "\n")
(stage / "docs" / "info.md").write_text(
    "# RV32 Linux SoC physical baseline\n\n"
    "This provisional 8x2 Tiny Tapeout workspace copies the current production RTL. "
    "Review pin and floorplan choices before submission.\n"
)
(stage / "baseline.json").write_text(
    json.dumps(
        {
            "rtl_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=rtl_root, text=True).strip(),
            "template_commit": TEMPLATE_REV,
            "support_tools_commit": TOOLS_REV,
            "tile_shape": "8x2",
            "clock_period_ns": args.clock_period_ns,
            "placement_density_pct": args.density_pct,
            "synth_strategy": args.synth_strategy,
            "synth_abc_area_use_nf": args.synth_abc_area_use_nf,
            "hold_margin_ns": args.hold_margin_ns,
            "grt_hold_margin_ns": args.grt_hold_margin_ns,
        },
        indent=2,
    )
    + "\n"
)
subprocess.run(["git", "init", "-q", "-b", "main"], cwd=stage, check=True)
subprocess.run(
    ["git", "remote", "add", "origin", subprocess.check_output(
        ["git", "remote", "get-url", "origin"], cwd=rtl_root, text=True
    ).strip()],
    cwd=stage,
    check=True,
)
subprocess.run(["git", "add", "-A"], cwd=stage, check=True)
subprocess.run(
    ["git", "-c", "user.name=Physical Baseline", "-c", "user.email=baseline@example.invalid",
     "commit", "-qm", "Stage current RTL for SKY26d 8x2 baseline"],
    cwd=stage,
    check=True,
)
print(stage)
