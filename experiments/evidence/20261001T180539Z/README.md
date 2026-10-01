# Failed shared-tree CI diagnosis

Run 36822832367 stopped on a real protected-wire loss after antenna repair.
The first detailed-route checkpoint preserved every protected path. Subsequent
antenna repair/reroute checkpoints lost 218, then 228 routes. Surviving protected
routes remained byte-normalized identical. Net _00378_ keeps the same two logical
pins but its dbWire becomes null after the first antenna repair/reroute pass.

The final ODB passes a fresh OpenROAD antenna check with zero net/pin violations;
its last router DRC count is zero. Neither result establishes connectivity. The
flow stopped before post-ECO disconnected-pin checking, extraction, STA or LVS.

The separate local screen omitted antenna repair and passed the post-route
connectivity/protected-geometry audit with zero router DRC. The contrast locates
the integration defect in the antenna repair/reroute loop, not the shared-tree
buffer count. Exact attribution within that loop still requires instrumentation.
Large ODBs/DEFs are retained under build/partitioned-signoff-ci/build; the original
CI artifacts are linked from the Actions run. No signoff gate was relaxed.
