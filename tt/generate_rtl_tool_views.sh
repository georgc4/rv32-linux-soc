#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
out=build/rtl-tool-views
netlistsvg=${NETLISTSVG:-build/rtl-eda-tools/node_modules/.bin/netlistsvg}
yosys=${YOSYS:-yosys}

if ! command -v "$yosys" >/dev/null 2>&1; then
    echo "Yosys is required" >&2
    exit 1
fi
if ! command -v dot >/dev/null 2>&1; then
    echo "Graphviz dot is required by Yosys show" >&2
    exit 1
fi
if ! test -x "$netlistsvg"; then
    echo "Install netlistsvg: npm install --prefix build/rtl-eda-tools --no-save netlistsvg@1.0.2" >&2
    exit 1
fi

mkdir -p "$out"

# No boxes, edges, or internal functional groupings are authored here. Yosys
# elaborates the RTL; netlistsvg and Yosys show render its actual cell/bit graph.
"$yosys" -Q -T -p "
    read_verilog rtl/cpu/*.v rtl/interconnect/*.v rtl/peripherals/*.v rtl/memory/*.v rtl/soc/*.v
    prep -top soc_top
    write_json $out/soc_top.json
    show -format svg -viewer none -width -stretch -prefix $out/soc_top-yosys soc_top
" > "$out/soc_top.log" 2>&1
"$netlistsvg" "$out/soc_top.json" -o "$out/soc_top-netlistsvg.svg"

# A whole-core schematic is many thousands of pixels tall. Select bounded
# upstream cones from named RTL wires; Yosys finds every displayed connection.
"$yosys" -Q -T -p "
    read_verilog rtl/cpu/rv32_mdu.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32i_core.v
    prep -top rv32i_core
    write_json $out/rv32i_core.json
    show -format svg -viewer none -width -stretch -prefix $out/core-result-cone rv32i_core/result %ci5
" > "$out/core-result-cone.log" 2>&1

"$yosys" -Q -T -p "
    read_verilog rtl/interconnect/sv32_bus_adapter.v
    prep -top sv32_bus_adapter
    write_json $out/sv32_bus_adapter.json
    show -format svg -viewer none -width -stretch -prefix $out/tlb-hit-cone sv32_bus_adapter/tlb_hit %ci8
" > "$out/tlb-hit-cone.log" 2>&1

{
    printf 'RTL commit: '; git rev-parse HEAD
    "$yosys" -V
    printf 'netlistsvg: '; node -p "require('./build/rtl-eda-tools/node_modules/netlistsvg/package.json').version"
    printf 'SoC top: soc_top\nCore cone: rv32i_core/result %%ci5\nSv32 cone: sv32_bus_adapter/tlb_hit %%ci8\n'
} > "$out/provenance.txt"

printf 'Generated RTL-derived schematics in %s\n' "$out"
