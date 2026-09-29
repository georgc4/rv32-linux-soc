"""Route the 37 ECO nets while protecting all unaffected detailed wires."""
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
    directory = OUT / 'electrical-library15-preserved-routes-v6'
    directory.mkdir(exist_ok=False)
    config = json.loads((source / 'config.json').read_text())
    eco = OUT / 'library15-targeted-v3-inputs/eco.tcl'
    if not eco.is_file():
        raise RuntimeError('Generate and review the targeted ECO before launching')
    preparation = ROOT / 'build/experiments/route-preserving-eco-inputs-v3'
    preparation_audit = json.loads((preparation / 'canonical-audit.json').read_text())
    if (preparation_audit['status'] != 'pass'
            or preparation_audit['after_sha256'] != sha(preparation / 'legalized.odb')
            or preparation_audit['manifest_sha256'] != sha(preparation / 'preparation.json')):
        raise RuntimeError('Route preservation preparation not verified')
    state['odb'] = str(preparation / 'legalized.odb')
    config.update(MAX_TRANSITION_CONSTRAINT=1.5,
                  DRT_ANTENNA_REPAIR_ITERS=0, GRT_ANTENNA_REPAIR_ITERS=0,
                  GRT_ALLOW_CONGESTION=True, RUN_ANTENNA_REPAIR=False,
                  RUN_POST_GRT_DESIGN_REPAIR=True, RUN_POST_GRT_RESIZER_TIMING=False,
                  GRT_DESIGN_REPAIR_RUN_GRT=True, GRT_RESIZER_HOLD_SLACK_MARGIN=0.10,
                  ELECTRICAL_PREPARATION_JSON=str(preparation / 'preparation.json'),
                  meta={'version': 1, 'flow': 'Classic', 'substituting_steps': {
                      'OpenROAD.RepairDesignPostGRT': 'Electrical.PreservedRouteRepair'}})
    cp = directory / 'config.json'; sp = directory / 'initial-state.json'
    cp.write_text(json.dumps(config, indent=2) + '\n')
    sp.write_text(json.dumps(state, indent=2) + '\n')
    plugin = ROOT / 'experiments/route_feedback/librelane_plugin_preserved_routes.py'
    command = ['podman', 'run', '--rm', '--name', 'rv32-electrical-library15-preserved',
               '--network', 'none', '-v', f'{Path.home()}:{Path.home()}',
               '-e', 'PYTHONPATH=' + str(plugin.parent), '-w', str(directory),
               IMAGE, 'python', '-m', 'librelane', '--manual-pdk',
               '--pdk-root', str(Path.home() / '.volare'), '--design-dir', str(directory),
               '--run-tag', 'wokwi', '--with-initial-state', str(sp),
               '--from', 'Electrical.PreservedRouteRepair', '--jobs', '4', '--hide-progress-bar', str(cp)]
    record = {'status': 'running', 'qualification': False, 'pid': os.getpid(),
              'started_utc': now(), 'command': command,
              'rtl_commit': json.loads((source / 'result.json').read_text())['rtl_commit'],
              'config_sha256': sha(cp), 'initial_state_sha256': sha(sp),
              'source_state_sha256': sha(original), 'initial_odb_sha256': sha(Path(state['odb'])),
              'targeted_eco_sha256': sha(eco), 'generator_sha256': sha(ROOT / 'experiments/generate_library_limit_eco.py'),
              'eco_adjustment': 'Same verified v3 ECO; freeze 21385 unaffected detailed wires and unrelated instances; route only 37 affected nets; disable broad timing/antenna repair; permit 8 coarse-grid overflow units to test detailed routability, retain all final checks', 'transition_target_ns': 1.5, 'capacitance_target_pf': config['MAX_CAPACITANCE_CONSTRAINT'] if 'MAX_CAPACITANCE_CONSTRAINT' in config else 'PDK default 0.2',
              'preparation_manifest_sha256': sha(preparation / 'preparation.json'), 'plugin_sha256': sha(plugin), 'worker_sha256': sha(Path(__file__)),
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
    odbs = list((run / 'final/odb').glob('*.odb'))
    if not odbs:
        detailed = list(run.glob('*-openroad-detailedrouting/state_out.json'))
        if detailed:
            odbs = [Path(json.loads(detailed[-1].read_text())['odb'])]
    if odbs:
        audit = directory / 'route-preservation.json'
        audit_command = ['podman', 'run', '--rm', '--network', 'none',
                         '-v', f'{Path.home()}:{Path.home()}', '--entrypoint', 'openroad',
                         IMAGE, '-exit', '-python', str(ROOT / 'experiments/verify_preserved_routes.py'),
                         '--before', str(preparation / 'prepared.odb'), '--after', str(odbs[0]),
                         '--manifest', str(preparation / 'preparation.json'), '--output', str(audit)]
        with (directory / 'route-preservation.log').open('w') as log:
            audit_rc = subprocess.run(audit_command, stdout=log, stderr=subprocess.STDOUT).returncode
        record['route_preservation'] = json.loads(audit.read_text()) if audit.exists() else {'status': 'missing', 'returncode': audit_rc}
    else:
        record['route_preservation'] = {'status': 'missing', 'reason': 'No completed detailed-route output'}
    record['log_tail'] = (directory / 'worker.log').read_text(errors='replace').splitlines()[-20:]
    result.write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
