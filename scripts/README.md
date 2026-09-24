# Reproducible local helpers

`bin_to_memh.py` converts a little-endian binary to 32-bit words for RTL simulation or boot ROM synthesis. `make_flash_image.py` prepends the RVSB 16-byte header with word count and additive checksum to a first-stage payload. `make image-smoke` uses both helpers. Neither installs tools or modifies the host outside the build output and explicitly named files.
