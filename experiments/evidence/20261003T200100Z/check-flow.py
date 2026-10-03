import json,sys
sys.path.insert(0,'/work')
from librelane_plugin_rv32 import RV32Partitioned
m=json.load(open('/work/physical-flow.json'))
ids=[s.id.lower().replace('.','-') for s in RV32Partitioned.Steps]
assert len(ids)==len(set(ids))
assert set(m['required_steps']) <= set(ids)
assert ids.index('rv32-repairsta') < ids.index('rv32-round2planelectricaleco')
assert ids.index('rv32-round2repairsta') < ids.index('rv32-round3planelectricaleco')
assert ids.index('rv32-round3repairsta') < ids.index('magic-drc')
print(len(ids),'unique flow steps; all',len(m['required_steps']),'required stages present in order')
