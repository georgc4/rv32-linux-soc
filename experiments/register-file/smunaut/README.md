# Sylvain Munaut hard RF integration experiment

Branch: `codex/smunaut-rf-experiment`; baseline: qualified main
`99cc34f07a6a0e0db938a1165639ea3b473e9bb4`. This experiment retains the 5x4
floorplan, 20 MHz clock, four-entry TLB, one instruction line, registered legality
decode, partitioning, routed repairs, and final physical checks.

## Source and scope

The validation-only repository did not expose standalone macro views. Following
the owner's links to the working FemtoRV integration located the actual package:
https://github.com/MichaelBell/ttsky25b-femtorv-soc/tree/50aa37fdb7befa4fe2fac69f71a10d64d102df3c

`macro/smunaut/` vendors that revision's GDS, LEF, Liberty, original behavioral
model, Apache-2.0 license, and a hash manifest. The macro is 132.64 x 118.70 um,
32x32 with two synchronous read ports and one write port. The model is write-first,
including both read ports simultaneously matching the write address. Its word
zero is writable: the CPU wrapper enforces architectural x0 itself.

**This is an experiment, not a replacement qualified submission.** The supplied
Liberty is a nominal 25 C / 1.8 V scalar timing model, reused through the upstream
`"*"` corner mapping. It is not independently characterized slow/fast-corner RF
timing. Standard-cell timing is still analyzed at the existing corners; even a
fully green run will not establish RF PVT qualification. No DRC, LVS, antenna,
PDN, setup/hold, slew or capacitance gate was disabled for this experiment.

The original Liberty names its positive power pin `VPWR`; the LEF names it
`VDPWR`. The integration Liberty changes only that spelling, retaining the
original as `rf_top.upstream.lib`. Original geometry and timing numbers are
unchanged. The behavioral model gets an explicit synthesis-blackbox guard,
so GDS synthesis cannot quietly replace the hard RF with flip-flops.

## CPU timing

At the instruction response acceptance edge, both macro read addresses come
from `i_resp_data`. During the existing READ_RS2 state, macro port A supplies
legality/address/CSR decoding. At its closing edge, both operands and legality
are captured; EXEC follows as before. This preserves the baseline state count.
The state keeps its historical name to minimize unrelated changes.

Writes use the existing writeback selection, gated off during reset and for x0.
Operand registers hold execution inputs independently of macro outputs. AMOs
still copy rs2 into `atomic_operand_hold` before memory access and destination
writeback. This avoids depending on read-before-write when rd aliases rs2/rs1.
The SRAM is intentionally not reset or preloaded to zero.

The Linux simulator's optional register probes now read `cpu.rf.storage`; those
probes are debug observations, not preloads or alternate execution paths. The
Linux image, serial memory models, UART acceptance command, and limits are unchanged.

## Physical integration

One `rf_top` instance at `soc.cpu.rf`, initially placed at (120,120) um,
orientation E; 5 um macro halos. Power connects top VPWR/VGND to macro
VDPWR/VGND, with met3 as the macro connection layer. All original physical gates
are retained, including PDN-connectivity failure. Unlike the source project's
configuration, this experiment does not waive PDN errors or turn off KLayout DRC.
The first GDS run will determine whether this macro power arrangement and macro
boundary routing meet our stricter flow. Do not turn errors off to get a pass.

The checked-in `src/config.json` and `physical-flow.json` carry the macro views
and hashes. Legacy `tt/stage_sky26d.py` now rejects this branch because it would
discard those physical settings; use the direct GDS CI path. The experiment's
viewer job does not replace main's public viewer. Gate-level simulation includes
the vendor behavioral model for the hard macro, so it checks digital integration,
not transistor-level RF timing.

## Reproduction and tests

- `python3 scripts/check_rf_experiment.py`: hashes and staged/source consistency.
- `make test-rf`: both-port write-first collisions, clocked output hold, word zero.
- `make test-core`: existing boot/instruction/fault tests plus ALU destination aliases,
  x0, AMO rd=rs2, rd=rs1, all equal, discarded destination, and LR/SC collisions.
- `make regen-rf-alias`: regenerate the checked-in program from `sim/programs/rf_alias.S`.
- `make test-priv test-supervisor test-soc-bad lint`: privileged/translated execution,
  full ROM -> NOR -> PSRAM smoke, corrupt-image rejection, lint.
- Linux acceptance: `.github/workflows/linux-datasheet.yml`, both strict memory
  profiles, same pinned image, UART-driven `ASH_PROGRAM_OK` acceptance.
- GDS: `.github/workflows/gds.yaml`, same pinned support-tools fork/LibreLane flow.

Local results before dispatch: all tests above passed; CPU smoke 867 cycles,
85 retired instructions; SoC smoke 27,771 cycles. Pinned LibreLane 3.0.14's Yosys
elaborated/flattened the production sources and retained exactly one `rf_top`
blackbox, without synthesizing the behavioral storage. Verilator compiled the
staged sources and ran a 100,000-cycle strict-memory smoke; this is explicitly
**not Linux acceptance**. Full Linux/GDS outcomes must be taken from CI.

Once this first 5x4 comparison is complete, assess placed/routed cell area,
congestion, macro pin access, timing and actual Linux cycles. A smaller tile trial
is a separate experiment; do not infer 8x2 feasibility from macro dimensions alone.

## GDS 37568117521: partition-area check repair

The first macro run failed in `RV32.SeedPlacement`, after synthesis, macro
placement, PDN generation and TritonPart, before global placement/routing. Its
`Unbalanced partitions` assertion measured only movable standard cells. The
fixed RF macro belongs to partition 3 and contributes 15,744.368 um2 to
TritonPart's balance, but the wrapper omitted that area from its validation.

The pinned [OpenROAD TritonPart implementation](https://github.com/The-OpenROAD-Project/OpenROAD/blob/dcf36133a369abc8f3c5e5738cd4d82e4903c0e0/src/par/src/TritonPart.cpp)
uses physical instance bounding-box area, includes fixed macros and physical
cells with Liberty views, and gives ports zero area. The repaired check uses
that same solution population. It retains the strict 30% upper bound; seed
windows still use movable-only area, and the macro stays fixed. Empty movable
groups fail before window construction. Reports now expose both populations.

| Partition | All partitioned instance area (um2) | Movable area (um2) |
| --- | ---: | ---: |
| 0 | 38,561.9840 | 38,043.9872 |
| 1 | 55,489.4688 | 54,997.7472 |
| 2 | 48,396.4160 | 47,829.6224 |
| 3 | 46,811.6640 | 30,849.5872 |

Largest total share: **29.3192%**; largest movable-only share: **32.0274%**.
This is a population mismatch in our seed guard, not a routed timing/DRC result.

Validation: replayed the exact failed CI ODB and partition file with the pinned
LibreLane 3.0.14 / OpenROAD dcf36133 tool. Seeding passed for 13,760 movable
instances, preserving all 6,388 fixed instances and the connectivity SHA-256
`42186bd6c261cac48c2e003c31ed3b5a302ce4cea116c2f19de5e5b5a58bb27d`.
All 36 physical Python tests passed, including the failed-run area fixture,
true imbalance rejection, the original strict bound, invalid weights, and empty
movable groups. RF provenance checks passed. No RTL, macro assets, timing
constraints, or signoff gates changed; the original Linux acceptance run remains
applicable. Full GDS qualification still depends on the rerun, and the RF's
nominal-only timing-model limitation remains.
