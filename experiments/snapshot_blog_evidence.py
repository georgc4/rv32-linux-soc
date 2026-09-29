"""Capture compact experiment evidence for Git; leave large artifacts in place.

Creates a new timestamped directory and refuses to overwrite one. Running
experiments are explicitly point-in-time snapshots, not completed results.
"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOFT = ROOT / 'build/experiments/soft-partition-screen'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def main():
    now = datetime.now(timezone.utc)
    out = ROOT / 'experiments/evidence' / now.strftime('%Y%m%dT%H%M%SZ')
    out.mkdir(parents=True, exist_ok=False)
    selected = set()
    for pattern in ['*/result.json', '*/config.json', '*/initial-state.json',
                    'partition-probe.tcl', 'partition.txt', 'seeded.odb.json',
                    '*-inputs/eco.tcl', '*-inputs/eco.json',
                    '*-inputs/connectivity-verification.json', '*-inputs/verify-eco.py',
                    'constraint-diagnostic/all-corner-summary.json',
                    'constraint-diagnostic/*.tcl', 'constraint-diagnostic/*.log',
                    '*/runs/wokwi/final/metrics.json',
                    '*/runs/wokwi/*-netgen-lvs/reports/lvs.netgen.rpt',
                    '*/runs/wokwi/*-magic-drc/reports/drc.magic.rpt']:
        selected.update(SOFT.glob(pattern))
    selected.update((ROOT / 'build/experiments/runs').glob('*/result.json'))
    selected.update((ROOT / 'build/experiments/runs').glob('*/final-timing-audit.json'))
    selected.update((ROOT / 'build/experiments/runs').glob('*/acceptance-ps4-result.json'))
    for name in ['status.json', 'ps4-acceptance.json']:
        p = ROOT / 'build/experiments/locality-campaign' / name
        if p.is_file(): selected.add(p)
    selected.update((SOFT / 'four-part-qualification/runs/wokwi').glob(
        '*-openroad-stapostpnr/max_ss_100C_1v60/checks.rpt'))
    manifest = {'captured_utc': now.isoformat(), 'source_head': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'scope': 'Compact local evidence snapshot. Active results remain provisional.',
        'captured_files': [], 'external_artifacts': []}
    for src in sorted(selected):
        if not src.is_file(): continue
        data = src.read_bytes()
        if len(data) > 2_000_000:
            raise RuntimeError(f'Unexpected large evidence file: {src}')
        rel = src.relative_to(ROOT / 'build/experiments')
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(data)
        manifest['captured_files'].append({'source': str(src.relative_to(ROOT)),
            'copy': str(rel), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    # Hash completed run logs and final artifacts. This is an inventory, not a
    # claim that the binaries/logs were pushed or backed up remotely.
    artifacts = {SOFT / 'seeded.odb'}
    for result in SOFT.glob('*/result.json'):
        data = json.loads(result.read_text())
        if data.get('status') == 'running': continue
        p = result.parent
        artifacts.update(p.glob('worker.log'))
        artifacts.update(p.glob('screen.log'))
        artifacts.update(p.glob('runs/wokwi/final/gds/*.gds'))
        artifacts.update(p.glob('runs/wokwi/final/odb/*.odb'))
    for path in sorted(artifacts):
        if path.is_file():
            manifest['external_artifacts'].append({'path': str(path.relative_to(ROOT)),
                'bytes': path.stat().st_size, 'sha256': digest(path),
                'storage': 'outside_git; remote_backup_not_verified_by_this_snapshot'})
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (out / 'README.md').write_text(
        '# Experiment evidence snapshot\n\nCaptured UTC: ' + now.isoformat() +
        '\n\nFiles preserve original bytes and paths inside JSON. The manifest hashes '
        'the captured bytes. Running results are provisional. Large artifacts and '
        'full logs listed in the manifest remain outside Git; their hashes do not '
        'constitute a backup. Historical qualification labels must be interpreted '
        'using the journal and final timing audits.\n')
    print(out.relative_to(ROOT))
    print(len(manifest['captured_files']), 'compact files;', len(manifest['external_artifacts']), 'external artifacts')


if __name__ == '__main__':
    main()
