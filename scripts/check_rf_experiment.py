#!/usr/bin/env python3
"""Fail closed on RF asset drift; distinguish experiment timing from signoff."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
meta = json.loads((root / 'macro/smunaut/provenance.json').read_text())
for name, expected in meta['files'].items():
    actual = hashlib.sha256((root / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'RF asset hash mismatch: {name}')
config = json.loads((root / 'src/config.json').read_text())
macro = config['MACROS']['rf_top']
assert set(macro['instances']) == {'soc.cpu.rf'}
assert 'VDPWR' in (root / 'macro/smunaut/rf_top.lib').read_text()
assert (root / 'src/rv32i_core.v').read_bytes() == (root / 'rtl/cpu/rv32i_core.v').read_bytes()
assert (root / 'src/rf_top.v').read_bytes() == (root / 'rtl/cpu/rf_top.v').read_bytes()
assert '(* blackbox *)' in (root / 'src/rf_top.v').read_text()
print('RF assets verified at upstream', meta['upstream_commit'])
print('EXPERIMENT ONLY: one nominal RF Liberty reused across corners; no RF PVT qualification.')
print('Physical DRC/LVS/antenna/PDN and existing STA gates remain enabled.')
