#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
pdk_root=${PDK_ROOT:-$HOME/.volare/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71}
export PDK_ROOT="$pdk_root"
export PDK=sky130A
export KLAYOUT_PATH="$pdk_root/sky130A/libs.tech/klayout"
test -f "$KLAYOUT_PATH/tech/sky130A.lyt" || {
    echo "SKY130A KLayout technology not found under $KLAYOUT_PATH" >&2
    exit 1
}
test -f "$here/rf8t_bitcell.gds" || {
    echo "Editable bitcell not found: $here/rf8t_bitcell.gds" >&2
    exit 1
}

if [[ -x /Applications/KLayout/klayout.app/Contents/MacOS/klayout ]]; then
    klayout=/Applications/KLayout/klayout.app/Contents/MacOS/klayout
else
    klayout=$(command -v klayout)
fi
exec "$klayout" -e -n sky130 -l "$KLAYOUT_PATH/tech/sky130A.lyp" \
    "$here/rf8t_bitcell.gds"
