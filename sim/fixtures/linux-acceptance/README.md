# Pinned Linux acceptance image

`flash.bin.xz` decompresses to the **exact existing 16 MiB NOR image** used in the
architecture/physical-design acceptance experiments, SHA-256:

`590ed63886833648537907532aac191c210e3eb4e36e300c99c4de4707e6f615`

Keeping this 1.6 MiB compressed fixture in Git lets CI compare memory models
without rebuilding or silently changing the guest. `flash.bin.json` records
layout and image identity; `kernel.config` is the no-plist/no-vm-pgtable variant.
The runner verifies the decompressed size and hard-coded SHA before simulation.
The ROM is still the production synthesized ROM. Only the external NOR is
preloaded; PSRAM is filled by actual simulated CPU/bus activity.

The image contains the project M-mode loader, Linux 6.12.111, BusyBox 1.37.0,
`linux/init` (with the `ASH> ` prompt), the digit demo and
`software/acceptance_smoke.c`. Source archives and hashes are in
`linux/sources.sha256`; build instructions are in `linux/build-image.sh`,
`scripts/build_linux_firmware.sh` and `linux/README.md`. Linux/BusyBox retain
their upstream GPL licenses. The fixture does not include a downloaded vendor
memory model, private data or credentials.

To regenerate a candidate on the supported build host:

```sh
KERNEL_CONFIG=sim/fixtures/linux-acceptance/kernel.config make image-linux-flash
```

Compiler/platform changes can change the resulting bytes; compare the manifest
instead of treating a rebuild as automatically identical. Updating this fixture
requires updating its manifest and the runner's expected SHA deliberately.
Historical successful acceptance is recorded in the experiment harness branch's
`experiments/evidence/20260929T081648Z/runs/f91a5e108ca5-717c71a48262/acceptance-ps4-result.json`
(13,877,255,869 cycles, older accelerated memory model). That result is not a
strict-model Linux result.
