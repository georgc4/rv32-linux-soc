# Working tools and RTL-derived visualizations

`make rtl-diagrams` runs [`tt/generate_rtl_block_diagrams.py`](../tt/generate_rtl_block_diagrams.py), producing core and Sv32 diagrams plus cell-count/area overlays in [`docs/rtl-block-diagrams/`](rtl-block-diagrams/README.md). These views come from RTL elaboration and SKY130 mapping but group logic by script-defined functional cones; area belongs to that mapping revision and is not routed area. `make rtl-tool-views` runs Yosys `prep`/`show` and netlistsvg to render elaborated hierarchy and bounded fan-in cones. Its outputs under ignored `build/rtl-tool-views/` are code-derived netlists, with JSON/DOT/provenance retained. The [tool-view guide](../tt/rtl-tool-views.md) gives installation and filenames. Open SVGs in a browser for zoom and pan; a full flattened SoC is inherently dense.

For physical design, LibreLane saves OpenROAD `.odb` databases at completed stages such as floorplan, placement, CTS, global routing, antenna repair, and detailed routing. Open one in the OpenROAD GUI on macOS with XQuartz and the pinned LibreLane container:

```sh
python3 scripts/openroad_odb_viewer.py --run c1c485de7289
```

The viewer chooses the newest available checkpoint for that run. It uses a local authenticated X11 relay without changing XQuartz's TCP setting. You can also pass an explicit `.odb` path to compare stages. Select an instance, pin, or net in the GUI to inspect its name and connections. The physical database contains placed standard-cell instances and logical nets, but synthesis has largely flattened the RTL hierarchy. Global-route/antenna-repair checkpoints have placement and net metadata but no completed signal-wire shapes; wait for a detailed-route checkpoint to inspect a metal shape's routed net. Intermediate routing iterations are not saved as separate `.odb` files. After a physical queue run, `latest.odb` remains beside `result.json`; the complete stage directory is in `pnr-stage.tar.zst`.

For final geometry, open GDS in KLayout to inspect placement, routing, and DRC markers. The custom bitcell editable source is a separate KLayout GDS and older Magic `.mag` file; read [layout status](physical/register-file-layout.md) before editing. GDS is a geometric representation, not a transistor schematic. For circuit connectivity, use the SPICE schematic/netlist and LVS. For standard-cell schematics, use Yosys/netlistsvg or the mapped Verilog/JSON. For timing, inspect STA path reports; a schematic alone does not give delay or criticality.

The interactive experiment chart from `make experiment-chart` is the decision view for area, cycle count, and timing metrics. It distinguishes qualified runs from failed/pending ones and links to their JSON records. The chart is generated from local results, so sharing its HTML without the corresponding run records may hide evidence. The [experiment method](experiments/method.md) defines how to read it.
