# DRC marker repair and buffer-only cleanup

Candidate d93c8fd; failed CI 37096880158; new full CI 37149985351.

`selected-result.json` verifies all 42 corner/physical metric gates on the final
buffer-only checkpoint replay. `buffer-cleanup/` holds its fresh per-stage
metrics, all nine final electrical reports, audits and LVS report. The original
driver input routes remain unchanged, as recorded in
`cleanup-route-comparison.json`.

`signoff/` and `minimal-signoff/` are 22-net/18-net routing controls: physically
clean but one cap violation. `integration/` includes the two-round control
(11 slew pins, one cap violation) and rejected resize-plus-buffer cleanup
(six slew pins, one cap violation). `buffer-cleanup/` is the selected clean
result. Stage outputs describe their stage, not later success.

The broad 22-net control inherited route__drc_errors=20 in its state; the fresh
empty repair/routed.drc establishes zero. Its manual routing did not rewrite
that inherited metric. Final buffer-only metrics come from the actual routing
steps and have fresh zero counts. Two manual signoff wrappers finished all
signoff steps but failed to serialize Decimal objects in their final optional
summary; their completed stage JSON files retain the results.

These are exact-CI-PDK checkpoint regressions, not clean RTL-to-GDS runs or
submission precheck. Full ODB/GDS/SPEF/logs remain outside Git. Source paths in
copied JSON preserve their original container paths. SHA256.json hashes every
captured file; it does not back up the large external artifacts.
