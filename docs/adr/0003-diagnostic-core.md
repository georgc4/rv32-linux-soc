# ADR 0003 — Original RV32I diagnostic core

Date: 2026-09-23. Status: accepted for bring-up, not architectural signoff.

Implement an original multi-cycle core with separate instruction and data request/response ports. A small adapter serializes requests into the existing physical bus. The single-outstanding path keeps instruction and data ordering explicit while controllers and privileged machinery are developed. The register file has unspecified contents after reset, as permitted architecturally; reads of x0 return zero and writes to x0 are ignored.

For early simulation, `EBREAK` halts and faults stop with a PC output. This is a diagnostic convention, **not** the RISC-V trap behavior. The later privilege unit must replace it with architectural exception causes, `mepc`/`sepc`, delegation, and returns. The current core excludes M/A, Zicsr, Zifencei and Sv32. The adapter can later be changed to allow cached or overlapping transactions without introducing device protocols into the core.
