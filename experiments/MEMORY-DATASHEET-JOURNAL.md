# Memory model experiments — 2026-09-30

User requested additional CI experiments and chip emulation close to the exact
purchased-part datasheets. The selected work replaces the most consequential
simulation shortcuts with a separate strict profile: elapsed NOR BUSY, true
array capacities, reset/power-up requirements and pin timing.

Locally observed before push:

* Existing serial-memory functional regression passed.
* Full-capacity bridge test passed at 20 MHz with typical NOR latency and 6 ns
  output delay, and with maximum 3 ms program / 400 ms erase and 6 ns output delay.
* Model protocol/timing self-tests passed, including deliberate violation cases.
* Production-wrapper pin-level RTL boot passed: NOR -> PSRAM -> CPU -> UART and
  RAM signature, then bad-checksum rejection, 2.67266 ms simulated.

The GDS neighborhood-repair experiment remains in CI at
https://github.com/georgc4/rv32-linux-soc/actions/runs/36808009959 (0f2390a).
This change does not modify synthesized RTL or physical scripts. Pushing it
starts CI for the new revision, including a new GDS build so the stronger GL
suite can test that revision's generated netlist after physical gates pass.
No gate-level success or physical signoff is claimed from the RTL result.

See `docs/verification/datasheet-memory-models.md` for assumptions, coverage and
the newly exposed requirement to defer NOR writes until 5 ms after power-up.
