#!/usr/bin/env bash
set -euo pipefail

# First technology-mapped baseline. This is not placement, routing, or STA.
root_dir="${RTL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
pdk_root="${PDK_ROOT:-$HOME/.volare}"
pdk_dir="$pdk_root/sky130A"
liberty="$pdk_dir/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
run_dir="${SYNTH_RUN_DIR:-$root_dir/build/sky130/tt_025C_1v80}"
abc_delay_ps="${ABC_DELAY_PS:-}"

if [[ -n "$abc_delay_ps" && ! "$abc_delay_ps" =~ ^[0-9]+$ ]]; then
    echo "ABC_DELAY_PS must be a nonnegative integer number of picoseconds" >&2
    exit 2
fi

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
    printf 'abc_delay_ps=%s\n' "${abc_delay_ps:-default}"
    shasum -a 256 "$liberty"
} > "$run_dir/versions.txt"

abc_options="-liberty $liberty"
if [[ -n "$abc_delay_ps" ]]; then
    abc_options="$abc_options -D $abc_delay_ps"
fi

cat > "$run_dir/synth.ys" <<EOF
read_verilog rtl/cpu/*.v rtl/interconnect/*.v rtl/peripherals/*.v rtl/memory/*.v rtl/soc/*.v
hierarchy -check -top tt_um_rv32_linux_soc
synth -top tt_um_rv32_linux_soc -noabc
dfflibmap -liberty $liberty
abc $abc_options
clean
stat -liberty $liberty
write_verilog -noattr $run_dir/tt_um_rv32_linux_soc_mapped.v
write_json $run_dir/tt_um_rv32_linux_soc_mapped.json
EOF

yosys -Q -T -s "$run_dir/synth.ys" > "$run_dir/yosys.log" 2>&1
tail -n 45 "$run_dir/yosys.log"
