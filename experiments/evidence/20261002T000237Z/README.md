# Guarded antenna repair regression

The failed CI checkpoint reproduced deletion of 218 protected wires during its
first antenna repair pass. The new guard restored them before detailed routing.
Routing then reached zero DRC, and the independent logical/protected-geometry
audit passed. This local test exercises one antenna pass, with 6 net / 10 pin
antenna violations remaining; it is not final signoff. CI runs the full loop.
The local linking Liberty revision differs from CI; full ODBs remain in ignored
build/partitioned-signoff-ci/build/antenna-fix. Their recorded hashes identify
the files but do not back up the large artifacts.
