#!/usr/bin/env python3
"""Build a self-contained interactive Pareto dashboard from experiment results."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "build/experiments/runs"
DEFAULT_OUTPUT = ROOT / "build/experiments/pareto.html"


def historical_baseline() -> dict | None:
    base = ROOT / "tt/reports/sky26d-120d965"
    files = [base / "baseline.json", base / "global-placement-metrics.json",
             base / "pre-cts-timing-metrics.json"]
    if any(not file.is_file() for file in files):
        return None
    revision, placement, timing = [json.loads(file.read_text()) for file in files]
    wns = next(value for key, value in timing.items()
               if key.startswith("timing__setup__wns__corner:"))
    return {
        "id": "historical-120d965", "name": "first SKY26d baseline",
        "commit": revision["rtl_commit"],
        "config": {"clock_period_ns": 50, "placement_density_pct": 60,
                   "synth_strategy": "original TT flow"},
        "metrics": {"mapped_area_um2": 224972.016,
                    "placed_area_um2": placement["design__instance__area__stdcell"],
                    "setup_wns_ns": wns,
                    "utilization_pct": 100 * placement["design__instance__utilization__stdcell"],
                    "mapped_cells": None, "acceptance_cycles": None},
        "synth": "pass", "pnr": "failed at detailed placement",
        "acceptance": "boot marker only", "qualified": False,
        "link": "history/sky26d-120d965.json",
    }


def collect() -> list[dict]:
    rows = []
    baseline = historical_baseline()
    if baseline:
        rows.append(baseline)
    for result_path in sorted(RUNS.glob("*/result.json")):
        result = json.loads(result_path.read_text())
        stages = result.get("stages", {})
        synth = stages.get("synth", {})
        pnr = stages.get("pnr", {})
        acceptance = stages.get("acceptance", {})
        failure_reason = None
        pnr_log = result_path.parent / pnr.get("log", "") if pnr.get("log") else None
        if pnr.get("status") == "failed" and pnr_log and pnr_log.is_file():
            failures = re.findall(r"\[([A-Z]+-\d+)\] ([^\n]+)",
                                  pnr_log.read_text(errors="replace"))
            if failures:
                failure_reason = " ".join(failures[-1])
        qualified = (pnr.get("status") == "pass" and pnr.get("gds_present") is True
                     and acceptance.get("status") == "pass")
        rows.append({
            "id": result["id"], "name": result.get("name", ""),
            "commit": result["commit"], "config": result["config"],
            "metrics": {
                "mapped_area_um2": synth.get("mapped_area_um2"),
                "mapped_cells": synth.get("mapped_cells"),
                "placed_area_um2": pnr.get("instance_area_um2"),
                "setup_wns_ns": pnr.get("setup_wns_ns"),
                "utilization_pct": (100 * pnr["utilization"]
                                    if "utilization" in pnr else None),
                "acceptance_cycles": acceptance.get("cycles"),
            },
            "synth": synth.get("status", "pending"),
            "pnr": pnr.get("status", "pending"),
            "acceptance": acceptance.get("status", "pending"),
            "failure_reason": failure_reason,
            "image_sha256": result.get("image_sha256"),
            "physical_pdk_revision": pnr.get("physical_pdk_revision"),
            "qualified": qualified,
            "link": f"runs/{result['id']}/result.json",
        })
    return rows


HTML = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RV32 SoC design experiments</title>
<style>
:root{color-scheme:dark;--bg:#0a1220;--panel:#122138;--line:#28405c;--text:#e8f2ff;--muted:#a3b5ca;--blue:#62b4ff;--green:#72dbac;--red:#ff837f;--amber:#f4ca78}
*{box-sizing:border-box}body{margin:0;background:linear-gradient(145deg,#0a1220,#0f1e32 58%,#081321);color:var(--text);font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
main{max-width:1380px;margin:auto;padding:28px 26px 50px}h1{font-size:31px;letter-spacing:-.035em;margin:0}h2{font-size:20px;margin:0 0 13px}p{color:var(--muted);margin:7px 0 0}.eyebrow{font-size:12px;text-transform:uppercase;letter-spacing:.16em;color:var(--blue);font-weight:700}
.top{display:flex;justify-content:space-between;gap:20px;align-items:end;flex-wrap:wrap}.stamp{color:var(--muted);font-size:12px}.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:25px 0}.card,.panel{background:#13243aeb;border:1px solid var(--line);border-radius:14px}.card{padding:16px 18px}.card b{display:block;font-size:27px;letter-spacing:-.04em}.card span{color:var(--muted);font-size:13px}.panel{padding:20px;margin-top:14px}
.controls{display:flex;gap:13px;flex-wrap:wrap;align-items:end;margin-bottom:15px}label{display:flex;flex-direction:column;gap:5px;color:var(--muted);font-size:12px;font-weight:650}select{background:#0b1829;color:var(--text);border:1px solid #456483;border-radius:8px;padding:9px 11px;min-width:190px;font:inherit}label.check{flex-direction:row;align-items:center;font-size:13px;padding-bottom:8px}input{accent-color:var(--blue)}
.chart-wrap{position:relative}svg{display:block;width:100%;height:auto;background:#0c1b2d;border-radius:11px;border:1px solid #29415e}.tooltip{position:fixed;z-index:5;pointer-events:none;max-width:340px;background:#07111fee;border:1px solid #53759c;border-radius:9px;padding:11px 13px;box-shadow:0 12px 35px #0008;display:none;font-size:12px;white-space:pre-line}.note{font-size:13px;color:var(--muted);margin-top:11px}.legend{display:flex;gap:21px;flex-wrap:wrap;color:var(--muted);font-size:12px;margin-top:10px}.swatch{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:6px}.swatch.q{background:var(--green)}.swatch.f{background:var(--red)}.swatch.p{background:var(--amber)}
table{width:100%;border-collapse:collapse;font-size:13px}th{text-align:left;color:#bed3e9;font-weight:650;border-bottom:1px solid #45617d;padding:10px 8px;white-space:nowrap}td{border-bottom:1px solid #203b56;padding:10px 8px;vertical-align:top}tr:hover td{background:#1b3450}a{color:#9ed0ff;text-decoration:none}a:hover{text-decoration:underline}.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}.status{padding:3px 7px;border-radius:999px;background:#233a56;white-space:nowrap}.status.pass{background:#174b3c;color:#a5f1cc}.status.failed{background:#5a2c36;color:#ffc2b5}.status.pending{background:#594a28;color:#ffe4a2}.table-scroll{overflow:auto}
@media(max-width:800px){main{padding:18px}.cards{grid-template-columns:repeat(2,1fr)}.panel{padding:12px}}
</style></head><body><main>
<div class="top"><div><div class="eyebrow">SKY26d design space</div><h1>SoC experiment explorer</h1><p>Compare immutable RTL revisions and physical-flow settings. Points enter the Pareto frontier only after routed PNR and ash-program acceptance pass.</p></div><div class="stamp" id="stamp"></div></div>
<div class="cards"><div class="card"><b id="runs">0</b><span>Recorded experiments</span></div><div class="card"><b id="qualified">0</b><span>Routed + functional pass</span></div><div class="card"><b id="frontier">0</b><span>Current Pareto points</span></div><div class="card"><b id="failed">0</b><span>Failed or reference runs</span></div></div>
<section class="panel"><h2>Tradeoff view</h2><div class="controls"><label>Horizontal axis<select id="xaxis"></select></label><label>Vertical axis<select id="yaxis"></select></label><label class="check"><input type="checkbox" id="showfailed" checked>Show failed and reference runs</label><label class="check"><input type="checkbox" id="showpending" checked>Show incomplete runs</label></div><div class="chart-wrap"><svg id="chart" viewBox="0 0 1100 565" role="img" aria-label="Experiment tradeoff scatter plot"></svg><div class="tooltip" id="tooltip"></div></div><div class="legend"><span><i class="swatch q"></i>Routed + ash pass</span><span><i class="swatch f"></i>Failed / historical reference</span><span><i class="swatch p"></i>Incomplete</span></div><p class="note" id="frontiernote"></p></section>
<section class="panel"><h2>Run ledger</h2><div class="table-scroll"><table><thead><tr><th>Experiment</th><th>Git revision</th><th>Mapping</th><th>PNR</th><th>ash program</th><th>Mapped area</th><th>Placed area</th><th>Setup WNS</th><th>Cycles</th></tr></thead><tbody id="ledger"></tbody></table></div><p class="note">Cell area is before placement; placed area is the latest available physical-flow metric. Early WNS is not routed signoff. Green frontier points require both a completed physical run and the serial-shell gate.</p></section>
</main><script>
const rows=__DATA__;
const dims={mapped_area_um2:{name:'Mapped cell area (µm²)',goal:'min'},placed_area_um2:{name:'Physical instance area (µm²)',goal:'min'},mapped_cells:{name:'Mapped cell count',goal:'min'},setup_wns_ns:{name:'Setup WNS (ns)',goal:'max'},utilization_pct:{name:'Core utilization (%)',goal:'min'},acceptance_cycles:{name:'ash program cycles',goal:'min'}};
const xaxis=document.getElementById('xaxis'),yaxis=document.getElementById('yaxis'),svg=document.getElementById('chart'),tooltip=document.getElementById('tooltip');
for(const [key,dim] of Object.entries(dims)){for(const select of [xaxis,yaxis]){const option=document.createElement('option');option.value=key;option.textContent=dim.name;select.appendChild(option)}}
xaxis.value='placed_area_um2';yaxis.value='setup_wns_ns';
if(!rows.some(r=>Number.isFinite(r.metrics.placed_area_um2)))xaxis.value='mapped_area_um2';
if(!rows.some(r=>Number.isFinite(r.metrics.setup_wns_ns)))yaxis.value='mapped_cells';
document.getElementById('stamp').textContent='Generated __GENERATED_UTC__';
document.getElementById('runs').textContent=rows.length;
document.getElementById('qualified').textContent=rows.filter(r=>r.qualified).length;
document.getElementById('failed').textContent=rows.filter(r=>r.pnr.startsWith('fail')||r.acceptance.startsWith('fail')).length;
function fmt(value,digits=1){return Number.isFinite(value)?value.toLocaleString(undefined,{maximumFractionDigits:digits}):'—'}
function klass(value){return value==='pass'?'pass':value.startsWith('fail')||value==='error'||value==='timeout'?'failed':'pending'}
function tag(value){const span=document.createElement('span');span.className='status '+klass(value);span.textContent=value;return span}
function textCell(tr,value,cls){const td=document.createElement('td');td.textContent=value;if(cls)td.className=cls;tr.appendChild(td);return td}
for(const r of rows){const tr=document.createElement('tr');const first=document.createElement('td');const link=document.createElement('a');link.href=r.link;link.textContent=r.name+' · '+r.id;first.appendChild(link);tr.appendChild(first);textCell(tr,r.commit.slice(0,12),'mono');for(const key of ['synth','pnr','acceptance']){const td=document.createElement('td');td.appendChild(tag(r[key]));tr.appendChild(td)}textCell(tr,fmt(r.metrics.mapped_area_um2,0));textCell(tr,fmt(r.metrics.placed_area_um2,0));textCell(tr,fmt(r.metrics.setup_wns_ns,2));textCell(tr,fmt(r.metrics.acceptance_cycles,0));if(r.failure_reason){tr.title=r.failure_reason}document.getElementById('ledger').appendChild(tr)}
const ns='http://www.w3.org/2000/svg';function el(type,attrs){const node=document.createElementNS(ns,type);for(const [k,v] of Object.entries(attrs))node.setAttribute(k,v);svg.appendChild(node);return node}
function dominates(a,b,x,y){const dx=dims[x].goal==='min'?a.metrics[x]<=b.metrics[x]:a.metrics[x]>=b.metrics[x];const dy=dims[y].goal==='min'?a.metrics[y]<=b.metrics[y]:a.metrics[y]>=b.metrics[y];const strict=a.metrics[x]!==b.metrics[x]||a.metrics[y]!==b.metrics[y];return dx&&dy&&strict}
function draw(){svg.replaceChildren();const x=xaxis.value,y=yaxis.value;const showfailed=document.getElementById('showfailed').checked,showpending=document.getElementById('showpending').checked;const points=rows.filter(r=>Number.isFinite(r.metrics[x])&&Number.isFinite(r.metrics[y])&&(r.qualified||(klass(r.pnr)==='failed'||klass(r.acceptance)==='failed'?showfailed:showpending)));const qualified=points.filter(r=>r.qualified);const front=qualified.filter(r=>!qualified.some(s=>s!==r&&dominates(s,r,x,y)));document.getElementById('frontier').textContent=front.length;document.getElementById('frontiernote').textContent=front.length?'Dashed line joins nondominated, fully qualified designs for the selected axes.':'No Pareto frontier yet: routed PNR and the ash-program acceptance gate must both pass.';
const L=112,R=1038,T=38,B=486;el('rect',{x:L,y:T,width:R-L,height:B-T,fill:'#0d1c2d',stroke:'#314b69','stroke-width':1});if(!points.length){const t=el('text',{x:550,y:270,'text-anchor':'middle',fill:'#a3b5ca','font-size':18});t.textContent='No experiments have both selected metrics yet';return}
let xlo=Math.min(...points.map(r=>r.metrics[x])),xhi=Math.max(...points.map(r=>r.metrics[x])),ylo=Math.min(...points.map(r=>r.metrics[y])),yhi=Math.max(...points.map(r=>r.metrics[y]));const xp=(xhi-xlo||Math.max(1,Math.abs(xlo)*.1))*.09,yp=(yhi-ylo||Math.max(1,Math.abs(ylo)*.1))*.12;xlo-=xp;xhi+=xp;ylo-=yp;yhi+=yp;const sx=v=>L+(v-xlo)/(xhi-xlo)*(R-L),sy=v=>B-(v-ylo)/(yhi-ylo)*(B-T);
for(let i=0;i<=5;i++){const xv=xlo+(xhi-xlo)*i/5,yv=ylo+(yhi-ylo)*i/5;const px=L+(R-L)*i/5,py=B-(B-T)*i/5;el('line',{x1:px,y1:T,x2:px,y2:B,stroke:'#213a55'});el('line',{x1:L,y1:py,x2:R,y2:py,stroke:'#213a55'});let tx=el('text',{x:px,y:B+24,'text-anchor':'middle',fill:'#a3b5ca','font-size':12});tx.textContent=fmt(xv,Math.abs(xhi-xlo)<100?2:0);let ty=el('text',{x:L-11,y:py+4,'text-anchor':'end',fill:'#a3b5ca','font-size':12});ty.textContent=fmt(yv,Math.abs(yhi-ylo)<100?2:0)}
let ax=el('text',{x:(L+R)/2,y:550,'text-anchor':'middle',fill:'#d2e5fb','font-size':14});ax.textContent=dims[x].name+' · '+(dims[x].goal==='min'?'lower is better':'higher is better');let ay=el('text',{x:24,y:(T+B)/2,transform:`rotate(-90 24 ${(T+B)/2})`,'text-anchor':'middle',fill:'#d2e5fb','font-size':14});ay.textContent=dims[y].name+' · '+(dims[y].goal==='min'?'lower is better':'higher is better');
if(front.length>1){const ordered=[...front].sort((a,b)=>a.metrics[x]-b.metrics[x]);el('polyline',{points:ordered.map(r=>`${sx(r.metrics[x])},${sy(r.metrics[y])}`).join(' '),fill:'none',stroke:'#72dbac','stroke-width':2,'stroke-dasharray':'7 6'})}
for(const r of points){const failure=klass(r.pnr)==='failed'||klass(r.acceptance)==='failed';const fill=r.qualified?'#72dbac':failure?'#ff837f':'#f4ca78';const circle=el('circle',{cx:sx(r.metrics[x]),cy:sy(r.metrics[y]),r:r.qualified?8:7,fill,stroke:'#f8fcff','stroke-width':1.5,tabindex:0});const tip=`${r.name} · ${r.id}\ncommit ${r.commit.slice(0,12)}\n${dims[x].name}: ${fmt(r.metrics[x],2)}\n${dims[y].name}: ${fmt(r.metrics[y],2)}\nPNR: ${r.pnr}; ash: ${r.acceptance}${r.failure_reason?'\nFailure: '+r.failure_reason:''}\nImage: ${r.image_sha256?r.image_sha256.slice(0,12):'unknown'}; PDK: ${r.physical_pdk_revision?r.physical_pdk_revision.slice(0,12):'see result'}\n${JSON.stringify(r.config)}`;circle.addEventListener('mouseenter',e=>{tooltip.textContent=tip;tooltip.style.display='block';tooltip.style.left=Math.min(e.clientX+14,window.innerWidth-350)+'px';tooltip.style.top=Math.min(e.clientY+14,window.innerHeight-170)+'px'});circle.addEventListener('mouseleave',()=>tooltip.style.display='none');circle.addEventListener('focus',e=>{tooltip.textContent=tip;tooltip.style.display='block';tooltip.style.left='30px';tooltip.style.top='30px'});circle.addEventListener('blur',()=>tooltip.style.display='none')}
}
for(const id of ['xaxis','yaxis','showfailed','showpending'])document.getElementById(id).addEventListener('change',draw);draw();
</script></body></html>'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    baseline = historical_baseline()
    if baseline:
        history = output.parent / "history/sky26d-120d965.json"
        history.parent.mkdir(parents=True, exist_ok=True)
        history.write_text(json.dumps(baseline, indent=2) + "\n")
    payload = json.dumps(collect(), ensure_ascii=False).replace("</", "<\\/")
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    output.write_text(HTML.replace("__DATA__", payload).replace("__GENERATED_UTC__", generated))
    print(output)


if __name__ == "__main__":
    main()
