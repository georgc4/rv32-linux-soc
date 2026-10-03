import sys,json,re
from pathlib import Path
sys.path[:0]=['/work','/work/physical']
from librelane.common import Path as LLPath,Toolbox,get_script_dir
from librelane.config import Config
from librelane.state import State,DesignFormat as DF
from librelane.steps import Step
import librelane_plugin_rv32
root=Path('/work/build/ci-37096880158/runs/wokwi')
def remap(x):
 if isinstance(x,str):
  x=re.sub(r'/home/runner/.ciel/ciel/sky130/versions/[^/]+/sky130A','/pdks/sky130A',x)
  x=x.replace('/home/runner/work/rv32-linux-soc/rv32-linux-soc/runs/wokwi',str(root))
  x=x.replace('/home/runner/work/rv32-linux-soc/rv32-linux-soc','/work')
  x=re.sub(r'/nix/store/[^/]+/lib/python[^/]+/site-packages/librelane/scripts',get_script_dir(),x)
  return x
 if isinstance(x,dict):return {k:remap(v) for k,v in x.items()}
 if isinstance(x,list):return [remap(v) for v in x]
 return x
raw=remap(json.loads((root/'resolved.json').read_text()));raw.pop('meta',None);raw['PDK_ROOT']='/pdks'
config=Config(raw)
state=State.load(remap(json.loads((root/'075-rv32-round2repairdetailedrouting/state_out.json').read_text())),validate_path=False)
state=State(state,overrides={DF.ODB:LLPath('/work/build/drc-marker-fix/minimal/routed.odb'),DF.DEF:LLPath('/work/build/drc-marker-fix/minimal/routed.def')},metrics=dict(state.metrics,route__drc_errors=0))
base=Path('/work/build/drc-marker-fix/minimal-signoff');base.mkdir(exist_ok=True);box=Toolbox(tmp_dir=str(base/'tmp'))
steps=['OpenROAD.CheckAntennas','OpenROAD.FillInsertion','OpenROAD.RCX','OpenROAD.STAPostPNR','Magic.StreamOut','KLayout.StreamOut','Magic.DRC','KLayout.DRC','Magic.SpiceExtraction','Netgen.LVS']
if '--inspect' in sys.argv:
 for name in steps:
  cls=Step.factory.get(name);assert cls,name
  obj=cls(config,state);print(name,'configured')
 sys.exit(0)
for i,name in enumerate(steps):
 step=Step.factory.get(name)(config,state)
 state=step.start(toolbox=box,step_dir=str(base/f'{i:02d}-{name}'))
(base/'metrics.json').write_text(json.dumps(dict(state.metrics),indent=2,default=str)+'\n')
