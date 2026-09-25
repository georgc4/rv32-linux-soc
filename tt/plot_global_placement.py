#!/usr/bin/env python3
"""Approximate local cell density from a LibreLane global-placement DEF."""

import argparse
import re
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("def_file", type=Path)
parser.add_argument("lef_file", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()

sizes = {}
macro = None
for line in args.lef_file.read_text().splitlines():
    if match := re.match(r"MACRO (\S+)", line):
        macro = match.group(1)
    elif macro and (match := re.match(r"\s*SIZE ([\d.]+) BY ([\d.]+) ;", line)):
        sizes[macro] = float(match.group(1)) * float(match.group(2))
        macro = None

units = 1000
xs, ys, areas = [], [], []
for line in args.def_file.read_text().splitlines():
    if match := re.match(r"UNITS DISTANCE MICRONS (\d+) ;", line):
        units = int(match.group(1))
    match = re.match(
        r"\s*-\s+\S+\s+(\S+).*?\+\s+(?:PLACED|FIXED)\s+\(\s+(\d+)\s+(\d+)\s+\)",
        line,
    )
    if match and match.group(1) in sizes:
        xs.append(int(match.group(2)) / units)
        ys.append(int(match.group(3)) / units)
        areas.append(sizes[match.group(1)])

if not areas:
    raise SystemExit("No placed cells with LEF sizes found")

width, height = 1378.16, 225.76  # Pinned TT support-tools 8x2 DEF outline.
nx, ny = 56, 10
density, _, _ = np.histogram2d(
    xs, ys, bins=[nx, ny], range=[[0, width], [0, height]], weights=areas
)
density /= (width / nx) * (height / ny)

fig, ax = plt.subplots(figsize=(14, 3.5), constrained_layout=True)
im = ax.imshow(
    density.T,
    origin="lower",
    extent=(0, width, 0, height),
    aspect="equal",
    cmap="magma",
    vmin=0,
    vmax=1.25,
)
ax.set_title("SKY26d 8×2: approximate global-placement cell density")
ax.set_xlabel("x (µm)")
ax.set_ylabel("y (µm)")
fig.colorbar(im, ax=ax, label="Cell area / bin area")
args.output.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(args.output, dpi=170)
print(f"{len(areas)} placed cells; {sum(areas):,.0f} µm² by LEF area; saved {args.output}")
