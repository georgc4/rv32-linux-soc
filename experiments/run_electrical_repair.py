"""Repair electrical violations from the successful partition checkpoint."""
import argparse
import json
import os
from pathlib import Path
import subprocess

from run_soft_partition_screens import ROOT, OUT, IMAGE, now, sha
from runner import audit_final_timing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--margin', type=int, choices=[20, 35], required=True)
    args = parser.parse_args()
    source = OUT / 'four-part-seed-60'
    evidence = json.loads((source / 'result.json').read_text())
    assert evidence['status'] == 'screen_pass' and evidence['global_overflow'] == 0
    directory = OUT / f'electrical-repair-{args.margin}'
    directory.mkdir(exist_ok=False)
    config = json.loads((OUT / 'four-part-qualification/config.json').read_text())
    config.update(RUN_POST_GRT_DESIGN_REPAIR=True,
                  GRT_DESIGN_REPAIR_RUN_GRT=True,
                  GRT_DESIGN_REPAIR_MAX_SLEW_PCT=args.margin,
                  GRT_DESIGN_REPAIR_MAX_CAP_PCT=args.margin)
    state = source / 'runs/screen/12-openroad-globalrouting/state_out.json'
    cp = directory / 'config.json'
    cp.write_text(json.dumps(config, indent=2) + '\n')
    command = ['podman', 'run', '--rm', '--name', f'rv32-electrical-{args.margin}',
               '--network', 'none', '-v', f'{Path.home()}:{Path.home()}',
               '-w', str(directory), IMAGE, 'python', '-m', 'librelane',
               '--manual-pdk', '--pdk-root', str(Path.home() / '.volare'),
               '--design-dir', str(directory), '--run-tag', 'wokwi',
               '--with-initial-state', str(state), '--from', 'OpenROAD.RepairDesignPostGRT',
               '--jobs', '4', '--hide-progress-bar', str(cp)]
    record = {'status': 'running', 'qualification': False, 'pid': os.getpid(),
              'started_utc': now(), 'margin_pct': args.margin,
              'rtl_commit': evidence['rtl_commit'], 'source_screen': str(source / 'result.json'),
              'config_sha256': sha(cp), 'initial_state_sha256': sha(state),
              'initial_odb_sha256': sha(Path(json.loads(state.read_text())['odb'])),
              'worker_sha256': sha(Path(__file__)), 'command': command,
              'image_id': subprocess.check_output(
                  ['podman', 'image', 'inspect', IMAGE, '--format', '{{.Id}}'], text=True).strip()}
    result = directory / 'result.json'
    result.write_text(json.dumps(record, indent=2) + '\n')
    with (directory / 'worker.log').open('w') as log:
        rc = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
    run = directory / 'runs/wokwi'
    final = run / 'final/metrics.json'
    sta = list(run.glob('*-openroad-stapostpnr/state_out.json'))
    metrics = json.loads(final.read_text()) if final.exists() else (
        json.loads(sta[-1].read_text())['metrics'] if sta else {})
    record.update(returncode=rc, ended_utc=now(),
                  status='flow_completed_review_required' if rc == 0 else 'failed',
                  final_timing_audit=audit_final_timing(metrics, run / 'resolved.json'))
    record['physical_metrics'] = {k: metrics.get(k) for k in [
        'route__drc_errors', 'magic__drc_error__count', 'klayout__drc_error__count',
        'design__lvs_error__count', 'antenna__violating__nets',
        'design__critical_disconnected_pin__count', 'route__wirelength',
        'design__instance__area__stdcell']}
    record['log_tail'] = (directory / 'worker.log').read_text(errors='replace').splitlines()[-20:]
    result.write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
