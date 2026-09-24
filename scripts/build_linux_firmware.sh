#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CC="${RISCV_CLANG:-/opt/homebrew/opt/llvm/bin/clang}"
command -v "$CC" >/dev/null || { echo "missing RV32 LLVM compiler: $CC" >&2; exit 1; }
for tool in riscv64-unknown-elf-as riscv64-unknown-elf-ld riscv64-unknown-elf-objcopy; do
    command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done
mkdir -p build/firmware build/linux
"$CC" --target=riscv32-unknown-elf -march=rv32ima_zicsr_zifencei -mabi=ilp32 \
    -O2 -ffreestanding -fno-builtin -fno-stack-protector -fno-pic \
    -msmall-data-limit=0 -Wall -Wextra -Werror -c \
    firmware/linux_loader.c -o build/firmware/linux_loader.o
riscv64-unknown-elf-as -march=rv32ima_zicsr_zifencei -mabi=ilp32 \
    -o build/firmware/linux_loader_entry.o firmware/linux_loader_entry.S
riscv64-unknown-elf-ld -m elf32lriscv --no-relax -T firmware/linux_loader.ld \
    -o build/firmware/linux_loader.elf \
    build/firmware/linux_loader_entry.o build/firmware/linux_loader.o
riscv64-unknown-elf-objcopy -O binary \
    build/firmware/linux_loader.elf build/firmware/linux_loader.bin
python3 scripts/pack_linux_flash.py \
    build/firmware/linux_loader.bin build/linux/Image \
    build/linux/rv32-linux-soc.dtb build/linux/flash.bin
