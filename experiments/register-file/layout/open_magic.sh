#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
pdk=${PDK_ROOT:-$HOME/.volare/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71}
if ! command -v magic >/dev/null 2>&1; then
    echo 'Magic is not installed on this host. On Ubuntu: sudo apt install magic' >&2
    exit 1
fi
test -f "$pdk/sky130A/libs.tech/magic/sky130A.magicrc" || {
    echo "SKY130 Magic technology file missing under PDK_ROOT=$pdk" >&2
    exit 1
}
cd "$root/experiments/register-file/layout/magic"
exec magic -rcfile "$pdk/sky130A/libs.tech/magic/sky130A.magicrc" rf8t_routed
