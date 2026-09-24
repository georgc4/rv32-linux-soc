# ADR 0001 — Single-outstanding physical bus for first simulation

Date: 2026-09-23. Status: accepted for scaffolding, revisitable for performance.

Use one ready/valid request and one ready/valid response with a single transaction outstanding. The core, future arbiter, and device controllers meet at physical byte addresses. Device electrical protocols stay behind slave ports. Unmapped addresses return an error response.

This choice isolates routing and backpressure behavior before CPU and serial-memory implementations exist. It allows a simple state machine and directed tests. Its latency and throughput may be inadequate for Linux over PSRAM; later caching, bursts, or deeper queues can preserve the visible ordering contract while adding performance. The test map is parameterized and provisional.
