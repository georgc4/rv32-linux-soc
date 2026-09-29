"""Run the user-authorized 1.5 ns target and a targeted electrical ECO."""
import json
import os
from pathlib import Path
import subprocess

from run_soft_partition_screens import ROOT, OUT, IMAGE, now, sha
from runner import audit_final_timing


def main():
    source = OUT / 'four-part-qualification'
    original = source / 'runs/wokwi/15-openroad-rcx/state_out.json'
    state = json.loads(original.read_text())
    # Do not inherit stale signoff metrics or final deliverables after an ECO.
    state['metrics'] = {}
    for key in ('sdf', 'lib', 'gds', 'mag_gds', 'klayout_gds', 'spice'):
        state.pop(key, None)
    directory = OUT / 'electrical-library15-targeted'
    directory.mkdir(exist_ok=False)
    config = json.loads((source / 'config.json').read_text())
    eco = OUT / 'library15-targeted-inputs/eco.tcl'
    if not eco.is_file():
        raise RuntimeError('Generate and review the targeted ECO before launching')
    config.update(MAX_TRANSITION_CONSTRAINT=1.5,
                  RUN_POST_GRT_DESIGN_REPAIR=True, RUN_POST_GRT_RESIZER_TIMING=True,
                  GRT_DESIGN_REPAIR_RUN_GRT=True, GRT_RESIZER_HOLD_SLACK_MARGIN=0.10,
                  ELECTRICAL_TARGETED_TCL=str(eco),
                  meta={'version': 1, 'flow': 'Classic', 'substituting_steps': {
                      'OpenROAD.RepairDesignPostGRT': 'Electrical.LibraryLimitRepair'}})
    cp = directory / 'config.json'; sp = directory / 'initial-state.json'
    cp.write_text(json.dumps(config, indent=2) + '\n')
    sp.write_text(json.dumps(state, indent=2) + '\n')
    plugin = ROOT / 'experiments/route_feedback/librelane_plugin_library_limit.py'
    command = ['podman', 'run', '--rm', '--name', 'rv32-electrical-library15',
               '--network', 'none', '-v', f'{Path.home()}:{Path.home()}',
               '-e', 'PYTHONPATH=' + str(plugin.parent), '-w', str(directory),
               IMAGE, 'python', '-m', 'librelane', '--manual-pdk',
               '--pdk-root', str(Path.home() / '.volare'), '--design-dir', str(directory),
               '--run-tag', 'wokwi', '--with-initial-state', str(sp),
               '--from', 'Electrical.LibraryLimitRepair', '--jobs', '4', '--hide-progress-bar', str(cp)]
    record = {'status': 'running', 'qualification': False, 'pid': os.getpid(),
              'started_utc': now(), 'command': command,
              'rtl_commit': json.loads((source / 'result.json').read_text())['rtl_commit'],
              'config_sha256': sha(cp), 'initial_state_sha256': sha(sp),
              'source_state_sha256': sha(original), 'initial_odb_sha256': sha(Path(state['odb'])),
              'targeted_eco_sha256': sha(eco), 'generator_sha256': sha(ROOT / 'experiments/generate_library_limit_eco.py'),
              'transition_target_ns': 1.5, 'capacitance_target_pf': config['MAX_CAPACITANCE_CONSTRAINT'] if 'MAX_CAPACITANCE_CONSTRAINT' in config else 'PDK default 0.2',
              'plugin_sha256': sha(plugin), 'worker_sha256': sha(Path(__file__)),
              'image_id': subprocess.check_output(
                  ['podman', 'image', 'inspect', IMAGE, '--format', '{{.Id}}'], text=True).strip()}
    result = directory / 'result.json'
    result.write_text(json.dumps(record, indent=2) + '\n')
    with (directory / 'worker.log').open('w') as log:
        rc = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
    run = directory / 'runs/wokwi'; final = run / 'final/metrics.json'
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
