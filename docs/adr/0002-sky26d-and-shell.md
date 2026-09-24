# ADR 0002 — Submission target and first shell

Date: 2026-09-23. Status: accepted from user decisions; reevaluate against evidence gates.

Target TTSKY26d submission by its presently listed 2026-11-30 deadline. BusyBox ash is an acceptable first interactive shell on fabricated silicon. Prototype against Linux 6.12 LTS. To meet the deadline, consider reviewed reuse of specific blocks, attributed and proposed before incorporation. Keep the SoC/CPU original rather than repackaging an existing implementation.

Consequences: the schedule in `docs/schedule.md` has hard evidence gates; target tile allocation and price still require an actual quote and mapped design. The first shell image can remain small, which improves the chance of fitting 32 MiB PSRAM and 16 MiB NOR. Neither date nor shell choice establishes Linux compatibility.
