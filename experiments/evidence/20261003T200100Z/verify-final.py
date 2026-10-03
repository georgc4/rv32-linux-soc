from pathlib import Path
import json,math
b=Path('build/drc-marker-fix/buffer-cleanup')
m=json.loads((b/'48-netgen-lvs/state_out.json').read_text())['metrics']
manifest=json.loads(Path('physical-flow.json').read_text());checked={}
for corner in manifest['corners']:
 for stem,nonnegative in [('timing__setup__ws',True),('timing__hold__ws',True),('design__max_slew_violation__count',False),('design__max_cap_violation__count',False)]:
  k=f'{stem}__corner:{corner}';v=m[k]
  assert isinstance(v,(int,float)) and math.isfinite(v) and (v>=0 if nonnegative else v==0),(k,v)
  checked[k]=v
for k in manifest['zero_metrics']:
 assert m[k]==0,(k,m[k]);checked[k]=m[k]
audit=json.loads((b/'35-rv32-round3auditecoroutes/audit.json').read_text());assert audit['status']=='pass'
comparison=json.loads(Path('build/drc-marker-fix/cleanup-route-comparison.json').read_text())
for n in ['_11694_','_11757_']:assert comparison['before_cleanup'][n]==comparison['buffer_only_cleanup'][n]
summary=dict(status='pass',scope='Exact-PDK checkpoint replay, not clean RTL-to-GDS or submission precheck',checked_metrics=checked,worst_setup_ns=m['timing__setup__ws'],worst_hold_ns=m['timing__hold__ws'],route_audit=audit)
Path('build/drc-marker-fix/selected-result.json').write_text(json.dumps(summary,indent=2)+'\n')
print('All',len(checked),'corner and physical metric gates pass')
print('Worst setup',summary['worst_setup_ns'],'ns; worst hold',summary['worst_hold_ns'],'ns')
