#!/usr/bin/env python3
"""Build an ignored, reviewable Tiny Tapeout 8x2 physical-flow workspace."""

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
TEMPLATE = BUILD / "ttsky-template"
TOOLS = BUILD / "tt-support-tools"
STAGE = BUILD / "sky130" / "ttsky26d-stage"
TEMPLATE_REV = "83d305501d505b157cd6e9ba87bc8ffd949526fd"
TOOLS_REV = "01d5d2814fa9dd61e9d211e0b235a4a592a9316a"


def checkout(url: str, path: Path, revision: str) -> None:
    if not path.exists():
        subprocess.run(["git", "clone", "--depth", "1", url, str(path)], check=True)
    actual = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
    if actual != revision:
        subprocess.run(["git", "-C", str(path), "fetch", "--depth", "1", "origin", revision], check=True)
        subprocess.run(["git", "-C", str(path), "checkout", "--detach", revision], check=True)


checkout("https://github.com/TinyTapeout/ttsky-verilog-template.git", TEMPLATE, TEMPLATE_REV)
checkout("https://github.com/TinyTapeout/tt-support-tools.git", TOOLS, TOOLS_REV)
if STAGE.exists():
    if (STAGE / "runs" / "wokwi").exists():
        raise SystemExit(f"Refusing to erase physical results in {STAGE}; archive them first")
    shutil.rmtree(STAGE)
shutil.copytree(TEMPLATE, STAGE, ignore=shutil.ignore_patterns(".git"))

sources = sorted(ROOT.glob("rtl/**/*.v"))
for source in sources:
    shutil.copy2(source, STAGE / "src" / source.name)
(STAGE / "src" / "project.v").unlink()
(STAGE / "tt").symlink_to(TOOLS, target_is_directory=True)
(STAGE / "firmware").mkdir()
shutil.copy2(ROOT / "firmware" / "boot_rom.hex", STAGE / "firmware" / "boot_rom.hex")

config_path = STAGE / "src" / "config.json"
config = json.loads(config_path.read_text())
config["CLOCK_PERIOD"] = 50  # 20 MHz declared device-tree clock.
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
(STAGE / "info.yaml").write_text("\n".join(lines) + "\n")
(STAGE / "docs" / "info.md").write_text(
    "# RV32 Linux SoC physical baseline\n\n"
    "This provisional 8x2 Tiny Tapeout workspace copies the current production RTL. "
    "Review pin and floorplan choices before submission.\n"
)
(STAGE / "baseline.json").write_text(
    json.dumps(
        {
            "rtl_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "template_commit": TEMPLATE_REV,
            "support_tools_commit": TOOLS_REV,
            "tile_shape": "8x2",
            "clock_period_ns": 50,
        },
        indent=2,
    )
    + "\n"
)
subprocess.run(["git", "init", "-q", "-b", "main"], cwd=STAGE, check=True)
subprocess.run(
    ["git", "remote", "add", "origin", subprocess.check_output(
        ["git", "remote", "get-url", "origin"], cwd=ROOT, text=True
    ).strip()],
    cwd=STAGE,
    check=True,
)
subprocess.run(["git", "add", "-A"], cwd=STAGE, check=True)
subprocess.run(
    ["git", "-c", "user.name=Physical Baseline", "-c", "user.email=baseline@example.invalid",
     "commit", "-qm", "Stage current RTL for SKY26d 8x2 baseline"],
    cwd=STAGE,
    check=True,
)
print(STAGE)
