#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

JOBS="${JOBS:-8}"
CONTAINER="${LINUX_BUILD_IMAGE:-localhost/rv32-linux-build:ubuntu24}"
ZIG="$ROOT/build/tools/zig-aarch64-macos-0.15.2/zig"
BUSYBOX="$ROOT/build/src/busybox-1.37.0"
KERNEL=build/src/linux-6.12.111

for tool in curl make podman python3 riscv64-unknown-elf-strip shasum; do
    command -v "$tool" >/dev/null || { echo "missing host tool: $tool" >&2; exit 1; }
done

mkdir -p build/downloads build/src build/tools build/busybox build/kernel build/linux
download() {
    local name="$1" url="$2"
    if [[ ! -f "build/downloads/$name" ]]; then
        curl -fL --retry 3 -o "build/downloads/$name" "$url"
    fi
}
download linux-6.12.111.tar.xz https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.111.tar.xz
download busybox-1.37.0.tar.bz2 https://busybox.net/downloads/busybox-1.37.0.tar.bz2
download zig-aarch64-macos-0.15.2.tar.xz https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz
shasum -a 256 -c linux/sources.sha256

[[ -f "$KERNEL/Makefile" ]] || tar -xJf build/downloads/linux-6.12.111.tar.xz -C build/src
python3 linux/patch-hz16.py "$KERNEL/kernel/Kconfig.hz"
[[ -f "$BUSYBOX/Makefile" ]] || tar -xjf build/downloads/busybox-1.37.0.tar.bz2 -C build/src
[[ -x "$ZIG" ]] || tar -xJf build/downloads/zig-aarch64-macos-0.15.2.tar.xz -C build/tools

# BusyBox's optional diagnostics use two linker flags Zig's linker rejects.
python3 - "$BUSYBOX/scripts/trylink" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace('-Wl,--warn-common', '')
s = s.replace('echo " -Wl,-Map,$EXE.map -Wl,--verbose"', 'echo ""')
if s != p.read_text():
    p.write_text(s)
PY

if [[ ! -f build/busybox/.config ]] || ! cmp -s linux/busybox-1.37.0.config build/busybox/.config; then
    cp linux/busybox-1.37.0.config build/busybox/.config
fi
make -C "$BUSYBOX" O="$ROOT/build/busybox" oldconfig </dev/null >build/busybox/config.log
make -C "$BUSYBOX" O="$ROOT/build/busybox" -j"$JOBS" \
    CC="$ZIG cc -target riscv32-linux-musl -mcpu=generic_rv32+m+a+zicsr+zifencei" \
    HOSTCC=cc AR="$ZIG ar" STRIP=riscv64-unknown-elf-strip \
    >build/busybox/build.log 2>&1
"$ZIG" cc -target riscv32-linux-musl \
    -mcpu=generic_rv32+m+a+zicsr+zifencei -static -Oz -s \
    -o build/digit_demo.rv32 software/digit/digit_demo.c

cat >build/rootfs.list <<'LIST'
dir /dev 755 0 0
nod /dev/console 600 0 0 c 5 1
nod /dev/null 666 0 0 c 1 3
dir /bin 755 0 0
file /bin/busybox /work/build/busybox/busybox 755 0 0
slink /bin/sh busybox 777 0 0
slink /bin/ash busybox 777 0 0
file /bin/digit_demo /work/build/digit_demo.rv32 755 0 0
dir /proc 755 0 0
dir /sys 755 0 0
dir /tmp 1777 0 0
file /init /work/linux/init 755 0 0
LIST

if ! podman image exists "$CONTAINER"; then
    podman build -f linux/Containerfile -t "$CONTAINER" linux
fi
if [[ ! -f build/kernel/.config ]] || ! cmp -s linux/kernel-6.12.111.config build/kernel/.config; then
    cp linux/kernel-6.12.111.config build/kernel/.config
fi
podman run --rm -v "$ROOT":/work:rw -w /work "$CONTAINER" bash -lc \
    'set -e; export KBUILD_BUILD_TIMESTAMP="2026-09-21 13:10:00 UTC" KBUILD_BUILD_USER=rv32 KBUILD_BUILD_HOST=local KBUILD_BUILD_VERSION=1 SOURCE_DATE_EPOCH=1789996200; make -C build/src/linux-6.12.111 O=/work/build/kernel ARCH=riscv LLVM=1 olddefconfig >/work/build/kernel/config.log; make -C build/src/linux-6.12.111 O=/work/build/kernel ARCH=riscv LLVM=1 -j'"$JOBS"' Image >/work/build/kernel/build.log 2>&1; /work/build/kernel/scripts/dtc/dtc -I dts -O dtb -o /work/build/linux/rv32-linux-soc.dtb /work/linux/rv32-linux-soc.dts'
cp build/kernel/arch/riscv/boot/Image build/linux/Image
cp build/kernel/usr/initramfs_data.cpio build/linux/initramfs.cpio
cp build/busybox/busybox build/linux/busybox
cp build/digit_demo.rv32 build/linux/digit_demo
python3 linux/check-image.py build/linux
