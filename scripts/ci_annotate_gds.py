#!/usr/bin/env python3
"""Emit GitHub annotations summarizing a LibreLane run, pass or fail.
Annotations are readable through the API even when raw logs are not."""
import glob, json, os, re

run = 'runs/wokwi'
if not os.path.isdir(run):
    print('::error::no runs/wokwi directory; flow did not start')
    raise SystemExit(0)
steps = sorted(d for d in glob.glob(f'{run}/[0-9]*-*') if os.path.isdir(d))
print(f'::notice::last step: {os.path.basename(steps[-1]) if steps else "none"} ({len(steps)} steps)')
errors = []
for d in steps[-6:]:
    for log in glob.glob(f'{d}/*.log'):
        for line in open(log, errors='replace'):
            if re.search(r'\[ERROR|\bERROR\b|Error:|\[(DPL|GRT|DRT|RSZ|GPL|CTS|ANT)-\d+\]', line):
                errors.append(f'{os.path.basename(d)}: {line.strip()[:300]}')
for e in errors[-12:]:
    print(f'::error::{e}')
metrics = None
for cand in [f'{run}/final/metrics.json'] + [f'{d}/state_out.json' for d in reversed(steps)]:
    if os.path.exists(cand):
        data = json.load(open(cand))
        metrics = data.get('metrics', data)
        src = cand
        break
if metrics:
    keys = ['design__instance__area', 'design__instance__utilization', 'design__core__area',
            'design__instance__count', 'route__drc_errors', 'antenna__violating__nets',
            'timing__setup__ws', 'timing__hold__ws', 'design__max_slew_violation__count',
            'design__max_cap_violation__count', 'route__wirelength']
    vals = []
    for k in keys:
        hit = [(m, v) for m, v in metrics.items() if m == k or (m.startswith(k + '__corner') and 'max_ss' in m)]
        for m, v in hit[:2]:
            vals.append(f'{m}={v}')
    print(f'::notice::metrics from {src}: ' + '; '.join(vals)[:3000])
