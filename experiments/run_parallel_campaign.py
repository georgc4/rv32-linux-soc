#!/usr/bin/env python3
"""Dispatch the frozen campaign across Mac and PS4 without restarting active PNR."""
import argparse
import concurrent.futures
import fcntl
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path

from runner import (ROOT, RUNS, run_one, ensure_worktree, planned_runs, utc_now,
                    write_result, collect_pnr_metrics, check_physical_artifacts)
from run_locality_campaign import resources
from run_physical_queue import archive_stage
from collect_ps4_worker import remote

SESSION = ROOT / 'build/experiments/locality-campaign'
REMOTE_NAMES = {'07-combined', '08-combined-multicorner', '11-one-line-tlb8', '12-no-cache-tlb8'}


def accepted(run):
    path = RUNS / run['id'] / 'result.json'
    result = json.loads(path.read_text()) if path.exists() else {'stages': {}}
    if 'acceptance' not in result['stages']:
        run_one(run, 'reuse-acceptance', None, 24, 40_000_000_000)
        result = json.loads(path.read_text())
    if result['stages']['acceptance']['status'] != 'pass':
        raise RuntimeError('Exact commit/image Linux acceptance has not passed')


def mac_job(job):
    run = job['run']
    accepted(run)
    run_one(run, 'pnr', None, 24, 40_000_000_000)
    archive_stage(RUNS / run['id'])


def wait_ps4(job):
    result_path = RUNS / job['run']['id'] / 'result.json'
    status_path = SESSION / ('ps4-' + job['run']['id'] + '.json')
    while 'pnr' not in json.loads(result_path.read_text())['stages']:
        status = json.loads(status_path.read_text())
        if status.get('status') == 'needs_attention':
            raise RuntimeError(status.get('error', 'Remote collector needs attention'))
        pid = status.get('collector_pid')
        if pid:
            try: os.kill(pid, 0)
            except ProcessLookupError:
                raise RuntimeError('Remote collector exited without a PNR result')
        time.sleep(15)


def adopt_job(job, pid):
    # Only the scheduler parent is replaced. Its detached hardening process continues.
    while True:
        command = subprocess.run(['ps', '-p', str(pid), '-o', 'command='], capture_output=True, text=True)
        if command.returncode or job['run']['id'] not in command.stdout:
            break
        time.sleep(10)
    directory = RUNS / job['run']['id']
    stage = directory / 'pnr-stage'
    final = stage / 'runs/wokwi/final'
    gds = final / 'gds/tt_um_rv32_linux_soc.gds'
    # TT writes these markers only after LibreLane returns success.
    complete = gds.is_file() and (final / 'commit_id.json').is_file() and (stage / 'runs/wokwi/pdk.json').is_file()
    pnr = {'status': 'pass' if complete else 'failed', 'returncode': None,
           'exit_status_observed': False, 'completion_evidence': 'TT final commit and PDK markers',
           'adopted_running_process': pid, 'gds_present': gds.is_file(), 'log': 'pnr.log',
           'librelane_version': '3.0.14', 'started_utc': job.get('started_utc'), 'ended_utc': utc_now()}
    pnr.update(collect_pnr_metrics(stage))
    if gds.is_file():
        pnr['checks'] = check_physical_artifacts(directory, stage, pnr.get('physical_pdk_revision'), None)
        if any(c['status'] != 'pass' for c in pnr['checks'].values()):
            pnr['status'] = 'failed'
    with (directory / 'result.lock').open('a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = json.loads((directory / 'result.json').read_text())
        if 'pnr' not in result['stages']:
            result['stages']['pnr'] = pnr
            write_result(directory / 'result.json', result)
    archive_stage(directory)


def ps4_job(job):
    run = job['run']; directory = RUNS / run['id']; stage = directory / 'pnr-stage'
    accepted(run)
    source = ensure_worktree(directory, run['commit'])
    options = directory / 'physical-options.json'; write_result(options, run['config']['physical_options'])
    config = run['config']
    command = [sys.executable, str(ROOT / 'tt/stage_sky26d_uart.py'), '--rtl-root', str(source),
               '--stage', str(stage), '--clock-period-ns', str(config['clock_period_ns']),
               '--tile-shape', config['tile_shape'], '--density-pct', str(config['placement_density_pct']),
               '--synth-strategy', config['synth_strategy'], '--hold-margin-ns', str(config['hold_margin_ns']),
               '--grt-hold-margin-ns', str(config['grt_hold_margin_ns']), '--physical-options', str(options)]
    with (directory / 'pnr-stage.log').open('w') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    python = ROOT / 'build/sky130/venv/bin/python'
    env = os.environ.copy(); env.update(PDK_ROOT=str(Path.home()/'.volare'), DYLD_FALLBACK_LIBRARY_PATH='/opt/homebrew/lib')
    env['PATH'] = str(python.parent) + ':' + env['PATH']
    with (directory / 'pnr-config.log').open('w') as log:
        subprocess.run([str(python), str(stage/'tt/tt_tool.py'), '--create-user-config'], cwd=stage,
                       env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    original = json.loads((SESSION / 'ps4-worker.json').read_text())
    root = original['remote_root']; control = root + '/workers/' + run['id']
    state_path = SESSION / ('ps4-' + run['id'] + '.json')
    state = {k:original[k] for k in ['host','via','remote_root','image_id','architecture']}
    state.update(run=run, control_dir=control, status='transferring', started_utc=utc_now())
    write_result(state_path, state)
    # A local tar archive avoids relying on pipeline exit status during input transfer.
    archive = directory / 'ps4-inputs.tar.gz'
    subprocess.run(['tar','-chzf',str(archive),'-C','/',str(stage).lstrip('/')], check=True)
    with archive.open('rb') as data:
        remote(f'set -o pipefail; gzip -d | tar xf - -C {shlex.quote(root)}', stdin=data, check=True)
    archive.unlink()
    image = json.loads((SESSION/'incident-20260927/ps4-image.json').read_text())[0]
    lines = ['#!/bin/sh'] + ['export '+key+'='+shlex.quote(value) for key,value in
                            (entry.split('=',1) for entry in image['Config']['Env'])]
    inner_control = '/workers/' + run['id']
    lines += ['export HOME=/root OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1',
              'cd '+shlex.quote(str(stage))+' || exit 125', 'mkdir -p runs/wokwi',
              'python -m librelane --manual-pdk --pdk-root /Users/cgeorges/.volare --pdk sky130A '
              '--run-tag wokwi --force-run-dir runs/wokwi --jobs 4 --hide-progress-bar src/config_merged.json',
              'rc=$?', 'printf "%s\\n" "$rc" > '+inner_control+'/worker-exit.code', 'exit "$rc"']
    script='\n'.join(lines)+'\n'
    remote(f'mkdir -p {control}; cat > {control}/run.sh', input=script, text=True, check=True)
    launch=(f'test ! -e {control}/worker.pid || exit 1; '
            f'nohup nice -n -10 chroot {root} /bin/sh {inner_control}/run.sh '
            f'>{control}/worker.log 2>&1 </dev/null & echo $! >{control}/worker.pid; cat {control}/worker.pid')
    started=remote(launch, capture_output=True, text=True, check=True)
    state.update(status='running', worker_pid=int(started.stdout.strip()))
    write_result(state_path, state)
    with (directory/'ps4-collector.log').open('a') as log:
        subprocess.run([sys.executable,str(ROOT/'experiments/collect_ps4_worker.py'),'--status',str(state_path)],
                       stdout=log,stderr=subprocess.STDOUT,check=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adopt-pid',type=int)
    parser.add_argument('--adopt-map',type=Path)
    parser.add_argument('--plan',action='store_true')
    args=parser.parse_args()
    adoption=json.loads(args.adopt_map.read_text()) if args.adopt_map else {}
    path=SESSION/'status.json'; state=json.loads(path.read_text())
    if args.plan:
        for job in state['jobs']:
            print(job['name'], 'ps4' if job['name'] in REMOTE_NAMES else 'mac', job['status'])
        return
    with (SESSION/'scheduler.lock').open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        state.update(pid=os.getpid(), scheduler='parallel', status='running', max_mac_pnr=4, max_ps4_pnr=2)
        (SESSION/'scheduler.pid').write_text(str(os.getpid())+'\n')
        futures={}
        with concurrent.futures.ThreadPoolExecutor(max_workers=7) as pool:
            for job in state['jobs']:
                if job['status']=='running':
                    if job.get('execution_host')=='ps4':
                        futures[pool.submit(wait_ps4,job)]=(job,'ps4')
                    else:
                        pid=adoption.get(job['run']['id']) or (args.adopt_pid if job['name']=='01-timing-nominal' else None)
                        if not pid:
                            raise RuntimeError('Unexpected running job; refusing duplicate launch')
                        futures[pool.submit(adopt_job,job,pid)]=(job,'mac')
                        job['execution_host']='mac'
            while True:
                for future,(job,host) in list(futures.items()):
                    if not future.done(): continue
                    try:
                        future.result()
                        pnr=json.loads((RUNS/job['run']['id']/'result.json').read_text())['stages']['pnr']
                        job.update(status='finished' if pnr['status']=='pass' else 'failed',pnr=pnr['status'],
                                   timing=pnr.get('timing',{}).get('status'),ended_utc=utc_now())
                    except Exception as exc:
                        job.update(status='failed',error=f'{type(exc).__name__}: {exc}',ended_utc=utc_now())
                    del futures[future]
                    subprocess.run([sys.executable,str(ROOT/'experiments/visualize.py')],cwd=ROOT,check=False)
                queued=[j for j in state['jobs'] if j['status']=='queued']
                if not queued and not futures: break
                try:
                    capacity=resources(); state['resources']=capacity
                    ids=subprocess.check_output(['podman','ps','-q'],text=True).split()
                    inspected=json.loads(subprocess.check_output(['podman','inspect',*ids],text=True)) if ids else []
                    active_dirs={c.get('Config',{}).get('WorkingDir') for c in inspected}
                    pending=sum(host=='mac' and str(RUNS/j['run']['id']/'pnr-stage') not in active_dirs
                                for j,host in futures.values())
                    # Reserve capacity through staging, before the container becomes visible.
                    capacity['reserved_mac_slots']=capacity['active_pnr']+pending
                    ps4_base=json.loads((SESSION/'ps4-worker.json').read_text())
                    ps4_busy=(ps4_base['status']!='finished')+sum(h=='ps4' for _,h in futures.values())
                    ps4_free=None
                    if ps4_busy<2:
                        probe=remote("awk '/MemAvailable:/ {print $2}' /proc/meminfo",capture_output=True,text=True,timeout=45,check=True)
                        ps4_free=int(probe.stdout.strip())/1024**2
                    for job in queued:
                        host='ps4' if job['name'] in REMOTE_NAMES else 'mac'
                        if job['name']=='13-registered-legality':
                            result=json.loads((RUNS/job['run']['id']/'result.json').read_text())
                            acceptance=result['stages'].get('acceptance')
                            if acceptance is None: continue
                            if acceptance['status']!='pass':
                                job.update(status='failed',error='Linux acceptance failed'); continue
                        ready=(ps4_busy<2 and ps4_free is not None and ps4_free>=3.5) if host=='ps4' else (
                            capacity['reserved_mac_slots']<4 and capacity['vm_available_gib']>=6
                            and capacity['vm_free_gib']>=5 and capacity['host_free_gib']>=12)
                        if not ready: continue
                        current=planned_runs(ROOT/job['manifest'])
                        if job['run']['id'] not in [r['id'] for r in current]:
                            job.update(status='failed',error='Flow provenance changed'); continue
                        # Pre-create worktrees serially before dispatching independent workers.
                        (RUNS/job['run']['id']).mkdir(parents=True,exist_ok=True)
                        ensure_worktree(RUNS/job['run']['id'],job['run']['commit'])
                        job.update(status='running',execution_host=host,started_utc=utc_now())
                        futures[pool.submit(ps4_job if host=='ps4' else mac_job,job)]=(job,host)
                        print(utc_now(),'START',host,job['name'],flush=True)
                        break  # One admission per interval lets startup memory and container counts settle.
                    state.pop('resource_error',None)
                except Exception as exc:
                    state['resource_error']=f'{type(exc).__name__}: {exc}'
                state.update(updated_utc=utc_now(), active_jobs=[j['name'] for j in state['jobs'] if j['status']=='running'])
                write_result(path,state)
                time.sleep(15)
        state.update(status='complete',ended_utc=utc_now()); write_result(path,state)


if __name__=='__main__':
    main()
