#!/usr/bin/env bash
set -euo pipefail

# First technology-mapped baseline. This is not placement, routing, or STA.
root_dir="$(cd "$(dirname "$0")/.." && pwd)"
pdk_root="${PDK_ROOT:-$HOME/.volare}"
pdk_dir="$pdk_root/sky130A"
liberty="$pdk_dir/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
run_dir="$root_dir/build/sky130/tt_025C_1v80"

if [[ ! -f "$liberty" ]]; then
    echo "Missing SKY130 liberty: $liberty" >&2
    exit 1
fi

mkdir -p "$run_dir"
cd "$root_dir"
{
    printf 'rtl_commit=%s\n' "$(git rev-parse HEAD)"
    printf 'yosys=%s\n' "$(yosys -V)"
    printf 'pdk_source=%s\n' "$(cat "$pdk_dir/SOURCES")"
    printf 'liberty=%s\n' "$liberty"
    shasum -a 256 "$liberty"
} > "$run_dir/versions.txt"

cat > "$run_dir/synth.ys" <<EOF
read_verilog rtl/cpu/*.v rtl/interconnect/*.v rtl/peripherals/*.v rtl/memory/*.v rtl/soc/*.v
hierarchy -check -top tt_um_rv32_linux_soc
synth -top tt_um_rv32_linux_soc -noabc
dfflibmap -liberty $liberty
abc -liberty $liberty
clean
stat -liberty $liberty
write_verilog -noattr $run_dir/tt_um_rv32_linux_soc_mapped.v
EOF

yosys -Q -T -s "$run_dir/synth.ys" > "$run_dir/yosys.log" 2>&1
tail -n 45 "$run_dir/yosys.log"
