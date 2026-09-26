#!/usr/bin/env bash
# Check the hand-editable Magic layout, never the generated placement/routing Tcl.
set -euo pipefail

root=$(cd "$(dirname "$0")/../../.." && pwd)
src="$root/experiments/register-file/layout/magic"
out="$root/build/register-file/layout-check"
pdk=${PDK_ROOT:-$HOME/.volare/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71}
test -f "$pdk/sky130A/libs.tech/magic/sky130A.magicrc"
mkdir -p "$out"
cp "$src"/*.mag "$out"/

cat > "$out/check.tcl" <<'TCL'
load rf8t_routed
select top cell
box values 0um 0um 45um 30um
drc check
drc catchup
drc count total
puts "DRC_ERRORS=[drc listall why]"
extract all
ext2spice lvs
ext2spice -o rf8t_routed.spice
gds write rf8t_routed.gds
quit -noprompt
TCL

if command -v magic >/dev/null 2>&1 && command -v netgen >/dev/null 2>&1; then
    (
        cd "$out"
        PDK_ROOT="$pdk" magic -dnull -noconsole \
            -rcfile "$pdk/sky130A/libs.tech/magic/sky130A.magicrc" \
            < check.tcl > magic.log 2>&1
        PDK_ROOT="$pdk" netgen -batch lvs \
            "$root/experiments/register-file/layout/rf8t_reference.spice rf8t_reference" \
            'rf8t_routed.spice rf8t_routed' \
            "$pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl" rf8t_lvs.out \
            > lvs.log 2>&1
    )
else
    podman run --rm -e PDK_ROOT=/pdk \
        -v "$pdk":/pdk:ro -v "$root":/work \
        -w /work/build/register-file/layout-check \
        --entrypoint bash ghcr.io/librelane/librelane:3.0.14 \
        -lc 'magic -dnull -noconsole -rcfile /pdk/sky130A/libs.tech/magic/sky130A.magicrc < check.tcl' \
        > "$out/magic.log" 2>&1

    podman run --rm -e PDK_ROOT=/pdk \
        -v "$pdk":/pdk:ro -v "$root":/work \
        -w /work/build/register-file/layout-check \
        --entrypoint bash ghcr.io/librelane/librelane:3.0.14 \
        -lc 'netgen -batch lvs "/work/experiments/register-file/layout/rf8t_reference.spice rf8t_reference" "rf8t_routed.spice rf8t_routed" /pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl rf8t_lvs.out' \
        > "$out/lvs.log" 2>&1
fi

grep 'Total DRC errors found:' "$out/magic.log" | tail -1
grep -E 'Circuits match uniquely|Circuits do not match' "$out/lvs.log" | tail -1
echo "DRC detail: $out/magic.log"
echo "LVS detail: $out/lvs.log"

count=$(sed -n 's/Total DRC errors found: \([0-9][0-9]*\).*/\1/p' "$out/magic.log" | tail -1)
if [[ ! "$count" =~ ^[0-9]+$ ]] || (( count != 0 )); then
    exit 1
fi
grep -q 'Circuits match uniquely' "$out/lvs.log"
