# RV32 Linux image

Run `make image-linux` on the M3 Mac. The script uses the existing local Podman machine for a Linux kernel build container, and Zig on macOS to cross-compile static RV32 BusyBox ash and the digit demo. It downloads verified Linux 6.12.111, BusyBox 1.37.0, and Zig 0.15.2 sources/tools into ignored `build/`. The pinned configs, device tree, source hashes, and build recipe are in this directory. Override `JOBS` for a smaller Podman machine. To reuse an already prepared container, set `LINUX_BUILD_IMAGE` to its image name.

Outputs appear in `build/linux/`: uncompressed `Image` with the BusyBox initramfs and digit demo built in, `rv32-linux-soc.dtb`, an inspectable `initramfs.cpio`, copies of the userspace binaries, and a size/hash manifest. The Image header requests physical address `0x80400000`, 4 MiB after the start of PSRAM. The DTB reserves `0x80000000`–`0x803fffff` for resident firmware. `check-image.py` checks the artifact headers and provisional flash/RAM ceilings. The BusyBox executable uses RV32IMA with Zicsr/Zifencei and a soft-float ABI; the kernel config disables compressed instructions and FPU use. Strict kernel RWX protection is disabled to avoid 4 MiB alignment gaps that otherwise put `Image` over the NOR budget.

The DTB connects the UART to a one-source PLIC at `0x0c000000`. Run `make image-linux-flash` to compile the M-mode loader and pack it, the DTB, and the `Image` into a 16 MiB NOR image at `build/linux/flash.bin`. Its companion JSON records offsets, sizes, and the SHA-256 hash. `make test-linux-handoff` verifies the ROM-to-S-mode path, SBI BASE/TIME calls, supervisor timer interrupt, and UART interrupt routing using a small kernel-shaped test payload.

`make test-linux-serial-boot` is the longer full-image RTL acceptance run. It loads that exact flash package into a 16 MiB behavioral NOR, models four full 8 MiB PSRAM chips, and runs the production `serial_mem_bridge` from reset with serial commands and actual quad-lane address/data transfers. It prints CPU progress and UART lines. Success now requires the interactive BusyBox ash prompt and then the output of a separate RV32 program invoked by a command sent as real UART RX frames. The testbench waits for Linux to consume each byte, since the UART has no RX FIFO. This run is separate from fast CI. See [experiment framework](../experiments/README.md).

The first completed full gate on RTL commit `8b2424d` passed at cycle
13,010,943,367: BusyBox ash displayed `ASH>`, accepted
`/bin/acceptance_smoke` through 22 UART RX bytes, and the separate RV32
program printed `ASH_PROGRAM_OK`. Verilator exited with code 0. This used
flash image SHA-256
`d7ca41e95c47af4ae02fe69c3fd0f56c9b33e41545bc2a0b8a95a23cac485b0c`.
The accepted log and simulator binary are hashed in experiment
`8b2424d1772d-4b86b7212906`; see the [boot performance note](../docs/boot-performance-baseline.md)
for cycle attribution and next trials.

The earlier 2026-09-24 run with `build/linux/flash.bin` (SHA-256 `8373980e8210d986666bc80c9ec08e696e106da5f6bf8e4e6780a02267bc5c4e`) reached the `/init` userspace marker at cycle 12,454,790,706. That older gate stopped before the interactive shell and did not meet the current acceptance condition. The same run recorded three recoverable kernel soft-lockup warnings during late initialization.

Progress reports include dephased guest PC/return-address/register snapshots, trap return PCs and causes, retired-instruction totals, RAM/flash requests, per-chip SPI command counts, and trap counts. The default 10,333,333-cycle report step avoids repeatedly sampling the same phase of the 16 Hz timer. Use `+report_first=<cycles>` and `+report_step=<cycles>` to change sampling. For a suspected guest routine, pass `+watch_pc_lo=<hex> +watch_pc_hi=<hex> +watch_after=<cycles>`; the testbench prints the first 64 unique return addresses observed while the PC is in that half-open range. Keep the matching `build/kernel/vmlinux` to symbolize guest PCs and return addresses after the run.

The kernel uses a project-specific 16 Hz tick choice added reproducibly by `linux/patch-hz16.py`; the patch also lowers `JIFFIES_SHIFT` at this tick rate so the fallback jiffies clocksource multiplier and its adjustment fit in 32 bits. High-resolution timers are disabled. Earlier full-image runs at standard 100/250 Hz spent most cycles in timer work after clock initialization even after quad transfers were enabled. The device-tree timebase remains the physical 20 MHz clock. This lower tick is a bring-up configuration and needs broader kernel validation.

The prototype kernel disables the optional crypto DRBG and jitter entropy collector. A full-serial-memory run reached the collector's SHA-3 initcall but triggered a soft-lockup warning after more than 22 simulated seconds in that work. The kernel's ordinary random subsystem remains enabled; this configuration does not claim to provide a hardware entropy source.
