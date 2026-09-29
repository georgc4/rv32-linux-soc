"""Screen placement hypotheses through global routing; never run detailed routing."""
import concurrent.futures
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'build/experiments/runs/f91a5e108ca5-717c71a48262/pnr-stage'
OUT = ROOT/'build/experiments/soft-partition-screen'
IMAGE = 'ghcr.io/librelane/librelane:3.0.14'
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def resolve(value):
    if isinstance(value, str) and value.startswith('dir::'):
        return str((BASE/'src'/value[5:]).resolve())
    if isinstance(value, list): return [resolve(x) for x in value]
    if isinstance(value, dict): return {k:resolve(v) for k,v in value.items()}
    return value

def run(name, seeded, density):
    directory = OUT/name
    directory.mkdir(exist_ok=False)
    config = resolve(json.loads((BASE/'src/config_merged.json').read_text()))
    config.update(PL_SKIP_INITIAL_PLACEMENT=seeded, PL_TARGET_DENSITY_PCT=density,
                  GRT_ALLOW_CONGESTION=False, DRT_THREADS=4, STA_THREADS=2)
    state = json.loads((BASE/'runs/wokwi/27-odb-applydeftemplate/state_out.json').read_text())
    # Clear historical metrics: the screen must report only recomputed evidence.
    state['metrics'] = {}
    if seeded: state['odb'] = str(OUT/'seeded.odb')
    cp=directory/'config.json'; sp=directory/'initial-state.json'
    cp.write_text(json.dumps(config,indent=2)+'\n');sp.write_text(json.dumps(state,indent=2)+'\n')
    command=['podman','run','--rm','--name','rv32-screen-'+name,'--network','none',
             '-v',str(Path.home())+':'+str(Path.home()),'-w',str(directory),IMAGE,
             'python','-m','librelane','--manual-pdk','--pdk-root',str(Path.home()/'.volare'),
             '--design-dir',str(directory),'--run-tag','screen','--with-initial-state',str(sp),
             '--from','OpenROAD.GlobalPlacement','--to','OpenROAD.GlobalRouting',
             '--jobs','4','--hide-progress-bar',str(cp)]
    status={'name':name,'status':'running','started_utc':now(),'seeded':seeded,'density_pct':density,
            'rtl_commit':'f91a5e108ca57f257d740447d6e14c926b77360b','baseline_run':'f91a5e108ca5-717c71a48262',
            'config_sha256':sha(cp),'initial_odb_sha256':sha(Path(state['odb'])),
            'seed_script_sha256':sha(ROOT/'experiments/seed_soft_partitions.py'),
            'seed_report':str(OUT/'seeded.odb.json') if seeded else None,
            'image_id':subprocess.check_output(['podman','image','inspect',IMAGE,'--format','{{.Id}}'],text=True).strip(),
            'command':command,'qualification':False}
    result=directory/'result.json';result.write_text(json.dumps(status,indent=2)+'\n')
    with (directory/'screen.log').open('w') as log:
        rc=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT).returncode
    text=(directory/'screen.log').read_text(errors='replace')
    reports=list((directory/'runs/screen').glob('*-openroad-globalrouting/openroad-globalrouting.log'))
    if reports:
        t=reports[-1].read_text(); pos=t.rfind('Final congestion report:')
        status['congestion_report']=t[pos:t.find('[INFO GRT-0018]',pos)].strip() if pos>=0 else None
        totals=re.findall(r'^Total\s+\d+\s+\d+\s+[\d.]+%\s+\d+\s*/\s*\d+\s*/\s*(\d+)',t,re.M)
        status['global_overflow']=int(totals[-1]) if totals else None
        lengths=re.findall(r'Total wirelength: ([\d.]+) um',t)
        status['wirelength_um']=float(lengths[-1]) if lengths else None
    status.update(status='screen_pass' if rc==0 else 'screen_rejected',returncode=rc,ended_utc=now(),
                  log_tail=text.splitlines()[-15:])
    result.write_text(json.dumps(status,indent=2)+'\n')
    print(name,status['status'],'overflow',status.get('global_overflow'),flush=True)
    return status

if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    (OUT/'screen-worker.pid').write_text(str(os.getpid())+'\n')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures=[pool.submit(run,'four-part-seed-60',True,60.0),
                 pool.submit(run,'density-only-55',False,55.0)]
        results=[f.result() for f in futures]
    (OUT/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
