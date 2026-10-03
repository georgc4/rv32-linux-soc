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

from librelane_eco_steps import ECO_STEPS_ROUND3
base=Path('/work/build/drc-marker-fix/buffer-cleanup');base.mkdir(exist_ok=True)
prior=base/'23-rv32-round2repairsta'
prior.symlink_to('/work/build/drc-marker-fix/integration/23-rv32-round2repairsta',target_is_directory=True) if not prior.exists() else None
state=State.load(json.loads((base/'23-rv32-round2repairsta/state_out.json').read_text()),validate_path=False)
box=Toolbox(tmp_dir=str(base/'tmp'))
classes=ECO_STEPS_ROUND3
classes += [Step.factory.get(n) for n in ['Magic.StreamOut','KLayout.StreamOut','Magic.DRC','KLayout.DRC','Magic.SpiceExtraction','Netgen.LVS']]
for i,cls in enumerate(classes,30):
 step=cls(config,state)
 state=step.start(toolbox=box,step_dir=str(base/f'{i:02d}-{cls.id.lower().replace(".","-")}'))
(base/'round3-final-metrics.json').write_text(json.dumps(dict(state.metrics),indent=2,default=str)+'\n')
