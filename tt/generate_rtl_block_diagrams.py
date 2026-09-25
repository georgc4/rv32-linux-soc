#!/usr/bin/env python3
"""Generate readable block diagrams checked against Yosys coarse RTL synthesis.

The diagrams group RTLIL signals into architectural blocks. They are deliberately
not gate-level schematics; the Yosys JSON is the source of truth for the checks.
"""

from __future__ import annotations

import json
import hashlib
import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "rtl-block-diagrams"
BUILD = ROOT / "build" / "rtl-block-diagrams"


def run_yosys(name: str, files: list[str]) -> dict:
    BUILD.mkdir(parents=True, exist_ok=True)
    output = BUILD / f"{name}.json"
    script = (
        "read_verilog " + " ".join(files) + "; "
        f"hierarchy -check -top {name}; proc; opt; write_json {output}"
    )
    with (BUILD / f"{name}.log").open("w") as log:
        subprocess.run(["yosys", "-Q", "-T", "-p", script], cwd=ROOT,
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    return json.loads(output.read_text())["modules"][name]


def require(module: dict, nets: list[str], cells: dict[str, str] | None = None,
            memories: list[str] | None = None) -> None:
    missing = [name for name in nets if name not in module["netnames"]]
    missing += [f"cell {name}:{kind}" for name, kind in (cells or {}).items()
                if module["cells"].get(name, {}).get("type") != kind]
    missing += [f"memory {name}" for name in (memories or [])
                if name not in module.get("memories", {})]
    if missing:
        raise RuntimeError("Yosys netlist differs from diagram: " + ", ".join(missing))


def render(name: str, dot: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    source = OUT / f"{name}.dot"
    source.write_text(dot)
    for format_name in ("svg", "png"):
        subprocess.run(["dot", f"-T{format_name}", str(source),
                        "-o", str(OUT / f"{name}.{format_name}")], check=True)


def mapped_metrics() -> dict:
    """Count mapped Sky130 cells in actual synthesis/module boundaries.

    The register-file and TLB storage groups are identified by Q pins driving
    their named state bits. All other cells remain in an exact residual group;
    no cell is counted twice or assigned to a conceptual logic cone.
    """
    OUT.mkdir(parents=True, exist_ok=True)
    pdk_root = Path(os.environ.get("PDK_ROOT", Path.home() / ".volare"))
    liberty = (pdk_root / "sky130A/libs.ref/sky130_fd_sc_hd/lib/"
               "sky130_fd_sc_hd__tt_025C_1v80.lib")
    if not liberty.is_file():
        raise FileNotFoundError(f"Sky130 Liberty file missing: {liberty}")

    output = BUILD / "soc-mapped.json"
    script = (
        "read_verilog rtl/cpu/*.v rtl/interconnect/*.v rtl/peripherals/*.v "
        "rtl/memory/*.v rtl/soc/*.v; "
        "hierarchy -check -top tt_um_rv32_linux_soc; "
        "synth -top tt_um_rv32_linux_soc -noabc; "
        f"dfflibmap -liberty {liberty}; abc -liberty {liberty}; clean; "
        f"stat -liberty {liberty}; write_json {output}"
    )
    with (BUILD / "soc-mapped.log").open("w") as log:
        subprocess.run(["yosys", "-Q", "-T", "-p", script], cwd=ROOT,
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    modules = json.loads(output.read_text())["modules"]

    source = liberty.read_text()
    headers = list(re.finditer(r'\bcell\s*\(\s*"([^"]+)"\s*\)\s*\{', source))
    areas = {}
    for index, header in enumerate(headers):
        end = headers[index + 1].start() if index + 1 < len(headers) else len(source)
        area = re.search(r'(?m)^\s*area\s*:\s*([0-9.]+)', source[header.start():end])
        if area:
            areas[header.group(1)] = float(area.group(1))

    def cell_metric(cells: list[dict]) -> dict:
        if any(cell["type"] not in areas for cell in cells):
            raise RuntimeError("Mapped module contains a cell missing from Liberty")
        return {"cells": len(cells),
                "area_um2": round(sum(areas[cell["type"]] for cell in cells), 4)}

    def storage_cell_names(module: dict, net_prefixes: tuple[str, ...]) -> set[str]:
        bits = {bit for name, net in module["netnames"].items()
                if name.startswith(net_prefixes)
                for bit in net["bits"] if isinstance(bit, int)}
        return {name for name, cell in module["cells"].items()
                if cell["type"] in areas and
                any(bit in bits for bit in cell["connections"].get("Q", []))}

    core_name = next(name for name in modules if name.endswith("\\rv32i_core"))
    core = modules[core_name]
    mdu = modules["rv32_mdu"]
    priv = modules["rv32_priv_unit"]
    adapter = modules["sv32_bus_adapter"]
    core_cells = {name: cell for name, cell in core["cells"].items()
                  if cell["type"] in areas}
    adapter_cells = {name: cell for name, cell in adapter["cells"].items()
                     if cell["type"] in areas}
    reg_names = storage_cell_names(core, ("regs[",))
    tlb_names = storage_cell_names(adapter,
                                   ("tlb_valid", "tlb_vpn[", "tlb_context[",
                                    "tlb_pte[", "tlb_level1["))
    if len(reg_names) != 1024 or len(tlb_names) != 1280:
        raise RuntimeError("Mapped storage bit counts changed; review attribution")

    result = {
        "library": liberty.name,
        "library_sha256": hashlib.sha256(liberty.read_bytes()).hexdigest(),
        "yosys_version": subprocess.check_output(["yosys", "-V"], text=True).strip(),
        "core": {
            "register_file_storage": cell_metric([core_cells[n] for n in reg_names]),
            "other_local_logic": cell_metric([cell for n, cell in core_cells.items()
                                              if n not in reg_names]),
            "mdu": cell_metric(list(mdu["cells"].values())),
            "privilege": cell_metric(list(priv["cells"].values())),
        },
        "sv32_adapter": {
            "tlb_storage": cell_metric([adapter_cells[n] for n in tlb_names]),
            "other_logic": cell_metric([cell for n, cell in adapter_cells.items()
                                        if n not in tlb_names]),
        },
    }
    for group in ("core", "sv32_adapter"):
        metrics = result[group].values()
        result[f"{group}_total"] = {
            "cells": sum(metric["cells"] for metric in metrics),
            "area_um2": round(sum(metric["area_um2"] for metric in result[group].values()), 4),
        }
    (OUT / "mapped-area.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def metric_label(title: str, metric: dict, detail: str = "") -> str:
    lines = [title, f"{metric['cells']:,} cells · {metric['area_um2']:,.1f} µm²"]
    if detail:
        lines.append(detail)
    return "\n".join(lines)


def main() -> None:
    core = run_yosys("rv32i_core", [
        "rtl/cpu/rv32_mdu.v", "rtl/cpu/rv32_priv_unit.v",
        "rtl/cpu/rv32i_core.v",
    ])
    require(core, ["state", "pc", "instr", "a", "b", "next_pc", "result",
                   "access_addr_hold", "atomic_write_data", "i_req_addr",
                   "d_req_addr", "retire_valid", "current_satp", "current_mstatus"],
            {"mdu": "rv32_mdu", "priv_unit": "rv32_priv_unit"}, ["regs"])
    require(core, ["mdu_done", "mdu_result", "trap_commit", "irq_pending"])

    adapter = run_yosys("sv32_bus_adapter", [
        "rtl/interconnect/sv32_bus_adapter.v",
    ])
    require(adapter, ["state", "choose_data", "request_vaddr", "request_priv",
                      "do_translate", "virtual_addr", "root_context",
                      "tlb_valid", "tlb_vpn[0]", "tlb_vpn[15]",
                      "tlb_context[0]", "tlb_context[15]",
                      "tlb_pte[0]", "tlb_pte[15]",
                      "tlb_level1[0]", "tlb_level1[15]", "tlb_hit",
                      "cached_permission_ok", "cached_privilege_ok",
                      "walk_addr", "next_walk_addr", "pte_leaf", "pte_invalid",
                      "permission_ok", "privilege_ok", "leaf_addr", "pte_updated",
                      "access_addr", "response_data", "response_error",
                      "response_page_fault", "bus_req_addr", "bus_resp_data"])

    render("core", r'''digraph core {
  graph [rankdir=LR, bgcolor="white", pad=0.25, nodesep=0.48, ranksep=0.68,
         splines=polyline, fontname="Helvetica", label="RV32 core · synthesized RTL block view",
         labelloc=t, fontsize=22, fontcolor="#17243a"];
  node [shape=box, style="rounded,filled", fillcolor="#f2f6fb", color="#6380a5",
        penwidth=1.4, fontname="Helvetica", fontsize=13, margin="0.16,0.12"];
  edge [color="#637895", arrowsize=0.73, penwidth=1.4];

  if_bus [label="Instruction port\ni_req_* / i_resp_*", fillcolor="#e3eefb"];
  fetch [label="Fetch + PC control\nPC, next PC, core FSM"];
  decode [label="Instruction register + decode\nopcode, immediates, rs1/rs2/rd"];
  rf [label="Register file\n32 × 32 bits; x0 reads zero", fillcolor="#e9f6ef", color="#5c9b7d"];

  alu [label="Integer ALU + branch\nresult / next PC", fillcolor="#e9f6ef", color="#5c9b7d"];
  lsu [label="Load/store + atomics\naddress, lanes, AMO", fillcolor="#e9f6ef", color="#5c9b7d"];
  mdu [label="Iterative MDU\nRV32M multiply/divide", fillcolor="#f3ecfa", color="#9870b2"];
  priv [label="Privilege + CSR unit\ntraps, interrupts, satp", fillcolor="#f3ecfa", color="#9870b2"];
  { rank=same; alu; lsu; mdu; priv; }
  alu -> lsu -> mdu -> priv [style=invis, weight=10];

  wb [label="Writeback to rd\nALU / load / MDU / CSR", fillcolor="#e9f6ef", color="#5c9b7d"];
  d_bus [label="Data port\nd_req_* / d_resp_*", fillcolor="#e3eefb"];
  mmu [label="Sv32 context + flush\nprivilege / satp / mstatus", fillcolor="#e3eefb"];
  irq [label="Interrupts + time", fillcolor="#fff3de", color="#c48c31"];

  if_bus -> fetch -> decode -> rf;
  rf -> alu; rf -> lsu; rf -> mdu; rf -> priv;
  decode -> alu; decode -> lsu; decode -> mdu; decode -> priv;
  alu -> wb; lsu -> wb; mdu -> wb; priv -> wb;
  lsu -> d_bus;
  priv -> mmu;
  irq -> priv;
}
''')

    render("sv32-adapter", r'''digraph sv32_adapter {
  graph [rankdir=TB, bgcolor="white", pad=0.25, nodesep=0.68, ranksep=0.53,
         splines=polyline, fontname="Helvetica", label="Sv32 adapter · synthesized RTL block view",
         labelloc=t, fontsize=22, fontcolor="#17243a"];
  node [shape=box, style="rounded,filled", fillcolor="#f2f6fb", color="#6380a5",
        penwidth=1.4, fontname="Helvetica", fontsize=13, margin="0.16,0.12"];
  edge [color="#637895", arrowsize=0.73, penwidth=1.4];

  cpu [label="CPU instruction + data ports\ni_req_* / d_req_*", fillcolor="#e3eefb"];
  arb [label="One-request arbiter\ndata priority"];
  mode [label="Effective privilege + mode\nMPRV / Sv32 enable"];
  tlb [label="16-entry direct-mapped TLB\nvalid / VPN / context / PTE / level"];
  hit [label="Hit permissions + address\nR/W/X, U/S, SUM/MXR"];
  access [label="Physical access address\n4 KiB / 4 MiB / bypass"];
  mux [label="Physical bus request mux\nPTE read / A-D write / access", fillcolor="#f3ecfa", color="#9870b2"];
  bus [label="Physical bus\nbus_req_* / bus_resp_*", fillcolor="#e3eefb"];
  resp [label="CPU response + faults\ni_resp_* / d_resp_*", fillcolor="#e3eefb"];
  context [label="satp / mstatus / privilege\nSFENCE.VMA", fillcolor="#fff3de", color="#c48c31"];

  walk [label="TLB miss: L1/L0 walk\nPTE reads via physical bus", fillcolor="#e9f6ef", color="#5c9b7d"];
  pte [label="PTE check\nleaf / permissions / superpage", fillcolor="#e9f6ef", color="#5c9b7d"];
  ad [label="A/D update + TLB fill\nPTE write when needed", fillcolor="#e9f6ef", color="#5c9b7d"];
  { rank=same; hit; walk; }
  hit -> walk [style=invis, weight=10];

  cpu -> arb -> mode -> tlb;
  context -> mode;
  context -> tlb;
  tlb -> hit -> access -> mux -> bus -> resp;
  tlb -> walk -> pte -> ad -> mux;
}
''')
    metrics = mapped_metrics()
    core_area = r'''digraph core_area {
  graph [rankdir=TB, bgcolor="white", pad=0.28, nodesep=0.7, ranksep=0.55,
         fontname="Helvetica", fontsize=22, fontcolor="#17243a",
         label="RV32 core · Sky130 mapped cells and area", labelloc=t];
  node [shape=box, style="rounded,filled", penwidth=1.5, fontname="Helvetica",
        fontsize=14, margin="0.22,0.16"];
  edge [color="#637895", arrowsize=0.75, penwidth=1.5];

  subgraph cluster_local {
    label=@@LOCAL_TOTAL@@;
    fontname="Helvetica"; fontsize=17; fontcolor="#345478";
    color="#b4c6db"; style="rounded"; margin=18;
    reg [label=@@REG@@, fillcolor="#e9f6ef", color="#5c9b7d"];
    other [label=@@OTHER@@, fillcolor="#f2f6fb", color="#6380a5"];
    { rank=same; reg; other; }
    reg -> other [dir=both];
  }
  mdu [label=@@MDU@@, fillcolor="#f3ecfa", color="#9870b2"];
  priv [label=@@PRIV@@, fillcolor="#f3ecfa", color="#9870b2"];
  { rank=same; mdu; priv; }
  other -> mdu;
  other -> priv;
  total [shape=plaintext, label=@@TOTAL@@, fontcolor="#17243a", fontsize=16];
  mdu -> total [style=invis];
  priv -> total [style=invis];
}
'''
    core_values = {
        "@@LOCAL_TOTAL@@": metric_label("rv32i_core local logic",
                                        {"cells": metrics["core"]["register_file_storage"]["cells"] +
                                          metrics["core"]["other_local_logic"]["cells"],
                                         "area_um2": metrics["core"]["register_file_storage"]["area_um2"] +
                                                     metrics["core"]["other_local_logic"]["area_um2"]}),
        "@@REG@@": metric_label("Register-file storage FFs",
                                metrics["core"]["register_file_storage"],
                                "Read mux and write logic counted at right"),
        "@@OTHER@@": metric_label("Other core-local logic",
                                  metrics["core"]["other_local_logic"],
                                  "Fetch / decode / RF mux / ALU / LSU / writeback"),
        "@@MDU@@": metric_label("rv32_mdu submodule", metrics["core"]["mdu"],
                                "Iterative multiply / divide"),
        "@@PRIV@@": metric_label("rv32_priv_unit submodule", metrics["core"]["privilege"],
                                 "CSR / interrupts / trap state"),
        "@@TOTAL@@": metric_label("Core including both submodules",
                                  metrics["core_total"]),
    }
    for placeholder, label in core_values.items():
        core_area = core_area.replace(placeholder, json.dumps(label, ensure_ascii=False))
    render("core-area", core_area)

    sv32_area = r'''digraph sv32_area {
  graph [rankdir=TB, bgcolor="white", pad=0.28, nodesep=0.7, ranksep=0.6,
         fontname="Helvetica", fontsize=22, fontcolor="#17243a",
         label="Sv32 adapter · Sky130 mapped cells and area", labelloc=t];
  node [shape=box, style="rounded,filled", penwidth=1.5, fontname="Helvetica",
        fontsize=14, margin="0.22,0.16"];
  edge [color="#637895", arrowsize=0.75, penwidth=1.5, dir=both];
  tlb [label=@@TLB@@, fillcolor="#e9f6ef", color="#5c9b7d"];
  other [label=@@OTHER@@, fillcolor="#f2f6fb", color="#6380a5"];
  tlb -> other;
  total [shape=plaintext, label=@@TOTAL@@, fontcolor="#17243a", fontsize=16];
  other -> total [style=invis];
}
'''
    sv32_values = {
        "@@TLB@@": metric_label("TLB storage FFs", metrics["sv32_adapter"]["tlb_storage"],
                                "Valid / VPN / context / live PTE / level bits"),
        "@@OTHER@@": metric_label("Other adapter logic", metrics["sv32_adapter"]["other_logic"],
                                  "TLB lookup mux / compare / walk / A-D / bus / response"),
        "@@TOTAL@@": metric_label("sv32_bus_adapter total",
                                  metrics["sv32_adapter_total"]),
    }
    for placeholder, label in sv32_values.items():
        sv32_area = sv32_area.replace(placeholder, json.dumps(label, ensure_ascii=False))
    render("sv32-adapter-area", sv32_area)
    print(f"Wrote diagrams to {OUT}")


if __name__ == "__main__":
    main()
