# Register-file bit-cell layout experiment

The **editable source** is `magic/rf8t_routed.mag`, with three referenced
transistor PCells in the same directory. Edit and save that cell in Magic.
The generated GDS under `build/` is only an export and is not the source.

On Ubuntu, install the free native layout editor with `sudo apt install
magic`. `sudo apt install klayout` adds a useful GDS viewer. Magic is the
editor for this repository's `.mag` source and for interactive SKY130 DRC.
Install the same SKY130A PDK revision used by the project and set `PDK_ROOT`
to the directory containing `sky130A`.

From the repository root, with Magic and the SKY130A PDK installed:

```sh
PDK_ROOT=/path/to/volare/sky130/version ./experiments/register-file/layout/open_magic.sh
```

In Magic, use `drc check`, `drc catchup`, then select a highlighted error and
use `drc why` to inspect its rule. Save with `save`. Run the repeatable batch
check from the repository root:

```sh
PDK_ROOT=/path/to/volare/sky130/version ./experiments/register-file/layout/check_layout.sh
```

`check_layout.sh` copies the source into `build/`, then runs Magic DRC,
transistor extraction, GDS export, and Netgen LVS. It never writes to the
editable `.mag` files. Currently LVS matches, but the spread-out prototype
has DRC violations. This single-bit layout is an electrical/layout prototype,
not yet a compact 31 × 32 register-file macro.

The original placement/routing generators (`rf8t_devices.tcl` and
`route_devices.py`) remain as references; rerunning them does **not** replace
the editable source.
