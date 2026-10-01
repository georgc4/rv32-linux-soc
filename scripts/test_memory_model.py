#!/usr/bin/env python3
"""Prove model semantics and rejection checks, including exact failure reasons."""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--simulator', choices=('iverilog', 'verilator'), default='iverilog')
args = parser.parse_args()
Path('build').mkdir(exist_ok=True)
if args.simulator == 'verilator':
    with Path('build/memory-model-verilator-compile.log').open('w') as log:
        built = subprocess.run([os.environ.get('VERILATOR', 'verilator'), '--binary',
            '--timing', '-j', '2', '-Wno-fatal', '--top-module', 'serial_memory_model_tb',
            '--Mdir', 'build/obj_memory_model',
            'sim/models/serial_memory_datasheet_model.v', 'sim/tests/serial_memory_model_tb.v'],
            stdout=log, stderr=subprocess.STDOUT)
    if built.returncode:
        raise SystemExit(Path('build/memory-model-verilator-compile.log').read_text()[-12000:])
    command = ['build/obj_memory_model/Vserial_memory_model_tb']
else:
    command = [os.environ.get('VVP', 'vvp'), 'build/memory_model_tb']
    subprocess.run([os.environ.get('IVERILOG', 'iverilog'), '-g2012', '-Wall',
                '-s', 'serial_memory_model_tb', '-o', 'build/memory_model_tb',
                'sim/models/serial_memory_datasheet_model.v',
                'sim/tests/serial_memory_model_tb.v'], check=True)
cases = {'flash': None, 'ram': None, 'output': None, 'startup_pins': 'POWERUP_PINS', 'reset_interrupted': 'RESET_SEQUENCE', 'powerup': 'POWERUP_WAIT',
         'write_powerup': 'WRITE_POWERUP_WAIT', 'reset': 'RESET_SEQUENCE',
         'no_reset': 'RESET_REQUIRED', 'cs_low': 'CS_LOW_REFRESH',
         'cs_high': 'CS_HIGH', 'setup': 'DATA_SETUP', 'hold': 'DATA_HOLD',
         'undriven': 'INPUT_UNDRIVEN', 'unsupported': 'UNSUPPORTED_COMMAND',
         'capacity': 'MODEL_CAPACITY', 'clock': 'CLOCK_LOW'}
for name, error in cases.items():
    result = subprocess.run(command + [f'+case={name}'], capture_output=True, text=True, timeout=30)
    if error is None:
        assert result.returncode == 0 and f'PASS datasheet model {name}' in result.stdout, result.stdout + result.stderr
    else:
        assert result.returncode != 0 and error in result.stdout, result.stdout + result.stderr
    print(f'PASS {name}: {error or "protocol semantics"}')
