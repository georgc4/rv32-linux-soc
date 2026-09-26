# RTL-derived schematic tools

`make rtl-tool-views` generates schematics from Yosys's elaborated RTL netlist.
No module boxes, functional blocks, or signal edges are manually drawn. This is
separate from the interpreted block diagrams in `docs/rtl-block-diagrams/`.

Install the renderer once (Yosys and Graphviz must also be on `PATH`):

```sh
npm install --prefix build/rtl-eda-tools --no-save netlistsvg@1.0.2
make rtl-tool-views
```

Outputs under ignored `build/rtl-tool-views/`:

| File | Source and scope |
|---|---|
| `soc_top-netlistsvg.svg` | netlistsvg rendering of Yosys `prep -top soc_top; write_json`; preserves the module hierarchy |
| `soc_top-yosys.svg` | Yosys `show` rendering of the same SoC top |
| `core-result-cone.svg` | Yosys `show` of the five-step fan-in cone of `rv32i_core/result` |
| `tlb-hit-cone.svg` | Yosys `show` of the eight-step fan-in cone of `sv32_bus_adapter/tlb_hit` |
| `*.json`, `*.dot`, `*.log`, `provenance.txt` | Underlying netlists, Graphviz source, tool logs, and RTL/tool versions |

Open the SVG files in a browser to pan and zoom. The full SoC schematic is
dense because every physical RTL port and wire is shown. The core and Sv32
adapter contain much of their logic inside single modules; a schematic tool
cannot label ALU, register file, page walk, or similar semantic regions unless
those are separate RTL instances. Bounded fan-in cones keep the actual logic
legible without inventing boundaries. To inspect a different path, change the
named wire and `%ciN` depth in `tt/generate_rtl_tool_views.sh`.
