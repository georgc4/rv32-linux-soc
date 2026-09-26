#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../../../.." && pwd)
name=sky130_sram_1kbyte_1rw1r_32x256_8
version=965df150c754fe2b3f93a0bd1f9883eb114279b2
reference_dir="$repo/build/register-file/openram-reference"
reference="$reference_dir/$name.gds"
expected_sha256=f05100d51cca469d8832f6494680e30ee9df3e38baca0e086deda4fb2b8edf21

mkdir -p "$reference_dir"
if [[ ! -f "$reference" ]]; then
    curl -LfsS "https://raw.githubusercontent.com/VLSIDA/sky130_sram_macros/$version/$name/$name.gds" \
        -o "$reference"
fi
actual_sha256=$(shasum -a 256 "$reference" | cut -d ' ' -f 1)
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "Reference GDS checksum mismatch: $reference" >&2
    exit 1
fi

pdk_root=${PDK_ROOT:-$HOME/.volare/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71}
export PDK_ROOT="$pdk_root"
export PDK=sky130A
export KLAYOUT_PATH="$pdk_root/sky130A/libs.tech/klayout"
test -f "$KLAYOUT_PATH/tech/sky130A.lyt" || {
    echo "SKY130A KLayout technology not found under $KLAYOUT_PATH" >&2
    exit 1
}

if [[ -x /Applications/KLayout/klayout.app/Contents/MacOS/klayout ]]; then
    klayout=/Applications/KLayout/klayout.app/Contents/MacOS/klayout
else
    klayout=$(command -v klayout)
fi
exec "$klayout" -ne -n sky130 -l "$KLAYOUT_PATH/tech/sky130A.lyp" "$reference"
