# Selective routed ECO experiment

Use the pinned `ghcr.io/librelane/librelane:3.0.14` container. The preparer and
verifier require `openroad -exit -python`, not a normal Python interpreter.

1. Start with an original routed ODB and a logically verified, pre-legalization ECO
   ODB (our v3 dry ECO). `prepare_preserved_routes.py --original ORIGINAL --eco ECO
   --output-dir NEW_DIRECTORY` freezes unrelated cells, identifies all nets touching
   changed connectivity/masters, deletes only those wires, and produces encoded
   FIXED wires for the remaining nets. It also invalidates cached pin access safely.
2. Load `encoded-fixed.odb` in OpenROAD, run `detailed_placement`, `check_placement
   -verbose`, and save `legalized.odb`. Keep unaffected cells locked.
3. Run `verify_preserved_routes.py --before prepared.odb --after legalized.odb
   --manifest preparation.json --output canonical-audit.json` in OpenROAD Python.
   Do not proceed if connectivity, unrelated-cell locations, fixed wire encoding,
   or protected geometry changed.
4. `run_library_limit_repair_preserved_routes.py` supplies that ODB to the existing
   qualification harness. Its companion plugin generates guides for the exact ECO
   net objects, preserving all other fixed routes. Broad timing and antenna repair
   are disabled; final timing/electrical/physical checks remain enabled. Its current
   paths identify the documented experiment, not a standalone portable CI flow.
5. After routing, the runner applies the same geometry/connectivity audit to the
   completed routed database and records it alongside all-corner signoff results.

The prototype allows coarse-grid congestion only to test detailed routability.
This is diagnostic, never permission to accept a final DRC violation. Failure to
route around frozen wires may require a larger, explicitly audited repair region.
The separate clean-RTL CI branch uses partitioned placement, and does not consume
these experimental databases or automatically adopt this ECO.
