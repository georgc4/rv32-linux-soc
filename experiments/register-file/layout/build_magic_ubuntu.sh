#!/usr/bin/env bash
# Build a Magic version compatible with the SKY130A techfile without sudo.
set -euo pipefail

pin=4f53bb3091d1e4a9b2009a58f157a8a4331d4c84 # Magic 8.3.684
src="$HOME/src/magic"
bin="$HOME/.local/bin/magic"

if [[ -x "$bin" ]]; then
    version=$("$bin" --version 2>/dev/null | head -1)
    if python3 - "$version" <<'PY'
import sys
try:
    current = tuple(map(int, sys.argv[1].split('.')[:3]))
except ValueError:
    raise SystemExit(1)
raise SystemExit(0 if current >= (8, 3, 411) else 1)
PY
    then
        echo "Magic $version is already installed at $bin"
        exit 0
    fi
fi

if [[ ! -f /usr/include/X11/Xlib.h || ! -f /usr/include/tcl8.6/tcl.h || ! -f /usr/include/cairo/cairo.h ]]; then
    echo 'Missing Ubuntu development headers. Install them on the iMac with:' >&2
    echo 'sudo apt install build-essential tcl-dev tk-dev libx11-dev libxext-dev libxmu-dev libxi-dev libgl-dev libglu1-mesa-dev libcairo2-dev libreadline-dev' >&2
    exit 1
fi

if [[ ! -d "$src/.git" ]]; then
    mkdir -p "$(dirname "$src")"
    git clone https://github.com/RTimothyEdwards/magic.git "$src"
fi
if [[ $(git -C "$src" rev-parse HEAD) != "$pin" ]]; then
    git -C "$src" fetch origin "$pin"
    git -C "$src" checkout --detach "$pin"
fi

cd "$src"
if ! CFLAGS='-g -std=gnu17' ./configure --prefix="$HOME/.local" > build_configure.log 2>&1; then
    tail -50 build_configure.log >&2
    exit 1
fi
make clean > build_clean.log 2>&1
if ! make -j"$(nproc)" > build_make.log 2>&1; then
    tail -50 build_make.log >&2
    exit 1
fi
if ! make install > build_install.log 2>&1; then
    tail -50 build_install.log >&2
    exit 1
fi
"$bin" --version
