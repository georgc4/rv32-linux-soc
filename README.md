# RV32 Linux SoC

An RV32IMA, Sv32 capable, single-hart SoC for Tiny Tapeout SKY130. The integrated RTL uses four external 8 MiB quad PSRAM chips, one 16 MiB serial NOR chip, a 16550-like UART, CLINT timer, one-source PLIC, boot ROM, and a small resident M-mode SBI loader. A locally built Linux 6.12.111 image embeds BusyBox ash and user programs.

**Start with the [engineering handbook](docs/README.md).** It traces the machine from instruction fetch and page walks through serial memory transactions, firmware, Linux, verification, physical flow, power/IO, and custom register-file layout. The [source map](docs/reference/source-map.md) indexes the implementation files. [Experiment results](experiments/RESULTS.md) are dated; each complete run's exact evidence is under ignored `build/experiments/runs/<id>/`.

## Current evidence

The full digital acceptance test boots the packed image through the production ROM and bit/nibble-level serial model of all five external chips. It sees the BusyBox ash prompt, sends `/bin/acceptance_smoke` over the SoC UART RX pin, and recognizes `ASH_PROGRAM_OK` from UART TX. A 5×4 SKY26d reference GDS for an earlier pinned RTL commit passed independent KLayout DRC, Magic DRC, and Netgen LVS; newer 8×2/5×4 optimizations are being evaluated separately. A 50 ns physical constraint is a target, not a signed-off 20 MHz silicon frequency. FPGA and fabricated-board tests remain to be performed. The custom 8T register-file cell is exploratory and is not integrated.

## Local commands

```sh
make test test-core test-mdu test-priv test-sv32 test-supervisor
make test-serial test-uart test-physical-uart test-timer test-plic
make test-soc-bad test-digit lint
make image-linux-flash       # Podman, Zig, RISC-V binutils and source downloads
make test-linux-handoff      # focused loader/SBI simulation
make test-linux-serial-boot  # long full-image serial simulation
make synth-sky130            # mapped-cell screen, not routed signoff
make stage-sky26d            # pinned Tiny Tapeout staging with current UART pins
make experiment-chart        # interactive run ledger/Pareto chart
```

See [build details](docs/boot/linux-image-and-programs.md), [test scope](docs/verification/tests-and-models.md), and [physical qualification](docs/physical/flow-and-evidence.md) before interpreting a command's output.
