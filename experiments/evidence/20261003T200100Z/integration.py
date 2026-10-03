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

from librelane_eco_steps import RepairDetailedRouting
base=Path('/work/build/drc-marker-fix/integration');base.mkdir(exist_ok=True)
prep=base/'01-rv32-prepareeconeighborhood';prep.mkdir(exist_ok=True)
m=json.loads((root/'062-rv32-repairdetailedrouting/preservation-active.json').read_text())
m['original_odb']=str(root/'058-rv32-planelectricaleco/original.odb')
(prep/'preservation.json').write_text(json.dumps(m,indent=2))
state=State.load(remap(json.loads((root/'062-rv32-repairdetailedrouting/state_out.json').read_text())),validate_path=False)
step=RepairDetailedRouting(config,state)
step.start(toolbox=Toolbox(tmp_dir=str(base/'tmp')),step_dir=str(base/'02-rv32-repairdetailedrouting'))
