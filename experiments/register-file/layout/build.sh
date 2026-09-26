#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
pdk=${PDK_ROOT:-$HOME/.volare/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71}
test -f "$pdk/sky130A/libs.tech/magic/sky130A.magicrc"
mkdir -p "$root/build/register-file/layout"
python3 - "$root/build/register-file/layout" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
for path in out.glob("*.mag"):
    if path.name == "rf8t_devices.mag" or path.name.startswith("sky130_fd_pr__"):
        path.unlink()
PY
podman run --rm -e PDK_ROOT=/pdk \
    -v "$pdk":/pdk:ro -v "$root":/work \
    -w /work/build/register-file/layout \
    --entrypoint bash ghcr.io/librelane/librelane:3.0.14 \
    -lc 'magic -dnull -noconsole -rcfile /pdk/sky130A/libs.tech/magic/sky130A.magicrc < /work/experiments/register-file/layout/rf8t_devices.tcl' \
    > "$root/build/register-file/layout/magic.log" 2>&1
tail -15 "$root/build/register-file/layout/magic.log"
