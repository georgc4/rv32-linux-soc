#!/usr/bin/env python3
"""Build/run hash-pinned Linux acceptance with strict serial-memory models."""
import argparse
import hashlib
import json
import lzma
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
IMAGE_SHA = '590ed63886833648537907532aac191c210e3eb4e36e300c99c4de4707e6f615'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output-delay', type=float, choices=(2.0, 6.0), default=6.0)
    p.add_argument('--ram-init', type=lambda s: int(s, 0), choices=(0xa5, 0x5a), default=0xa5)
    p.add_argument('--build-only', action='store_true')
    p.add_argument('--smoke-cycles', type=int, default=0)
    p.add_argument('--max-cycles', type=int, default=20_000_000_000)
    p.add_argument('--wall-seconds', type=int, default=19800)
    p.add_argument('--jobs', type=int, default=2)
    args = p.parse_args()
    if min(args.max_cycles, args.wall_seconds, args.jobs) <= 0 or args.smoke_cycles < 0:
        p.error('budgets must be positive; smoke-cycles must be nonnegative')
    os.chdir(ROOT)
    out = ROOT / 'build/linux-datasheet'
    out.mkdir(parents=True, exist_ok=True)
    linux = ROOT / 'build/linux'
    linux.mkdir(exist_ok=True)
    fixture = ROOT / 'sim/fixtures/linux-acceptance'
    image = lzma.decompress((fixture / 'flash.bin.xz').read_bytes())
    if len(image) != 16777216 or hashlib.sha256(image).hexdigest() != IMAGE_SHA:
        raise SystemExit('acceptance image identity mismatch')
    (linux / 'flash.bin').write_bytes(image)
    shutil.copyfile(fixture / 'flash.bin.json', linux / 'flash.bin.json')
    subprocess.run([sys.executable, 'scripts/flash_to_bytehex.py',
                    str(linux / 'flash.bin'), str(linux / 'flash.serial.hex')], check=True)
    sources = sorted((ROOT / 'src').glob('*.v')) + [
        ROOT / 'sim/tests/linux_serial_boot_tb.v',
        ROOT / 'sim/models/serial_memory_datasheet_model.v',
        ROOT / 'sim/tests/linux_serial_boot_main.cpp']
    verilator = os.environ.get('VERILATOR', 'verilator')
    manifest = {
        'git_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        'image_sha256': IMAGE_SHA,
        'fixture_sha256': sha(fixture / 'flash.bin.xz'),
        'sources': {str(path.relative_to(ROOT)): sha(path) for path in sources},
        'physical_config_sha256': sha(ROOT / 'src/config.json'),
        'boot_rom_sha256': sha(ROOT / 'firmware/boot_rom.hex'),
        'kernel_config_sha256': sha(fixture / 'kernel.config'),
        'image_manifest_sha256': sha(fixture / 'flash.bin.json'),
        'runner_sha256': sha(Path(__file__)),
        'verilator': subprocess.check_output([verilator, '--version'], text=True).strip(),
        'core_hz': 20_000_000, 'output_delay_ns': args.output_delay,
        'psram_initial_byte': args.ram_init, 'smoke_cycles': args.smoke_cycles,
        'max_cycles': args.max_cycles, 'wall_seconds': args.wall_seconds,
        'kind': 'rtl_datasheet_serial_linux_smunaut_rf',
        'rf_model': 'upstream_write_first_clocked_2r1w',
        'rf_physical_timing_qualified': False,
        'rf_assets': {str(p): sha(p) for p in sorted((ROOT / 'macro/smunaut').glob('*')) if p.is_file()}, 'two_state_simulator': True,
    }
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    command = [verilator, '--cc', '--exe', '--build', '--timing', '-O3',
               '-j', str(args.jobs), '-Wno-fatal', '-DDATASHEET_MODEL',
               '-CFLAGS', '-O3', '--top-module', 'linux_serial_boot_tb',
               f'-GMEMORY_OUTPUT_DELAY={args.output_delay}',
               f'-GMEMORY_INIT_BYTE={args.ram_init}',
               '--Mdir', str(out / 'obj')] + list(map(str, sources))
    print('Compiling production staged RTL and strict chip models', flush=True)
    with (out / 'compile.log').open('w') as log:
        built = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    if built.returncode:
        print((out / 'compile.log').read_text()[-12000:])
        return built.returncode
    if args.build_only:
        return 0
    binary = out / 'obj/Vlinux_serial_boot_tb'
    manifest['simulator_sha256'] = sha(binary)
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    command = [str(binary), f'+max_cycles={args.max_cycles}',
               '+report_first=1000000', '+report_step=100333333']
    if args.smoke_cycles:
        command += [f'+smoke_cycles={args.smoke_cycles}']
    start = time.monotonic()
    timed_out = False
    with (out / 'run.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        with (out / 'run.log').open() as live:
            while process.poll() is None:
                remaining = args.wall_seconds - (time.monotonic() - start)
                if remaining <= 0:
                    timed_out = True
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    break
                try:
                    process.wait(timeout=min(30, remaining))
                except subprocess.TimeoutExpired:
                    pass
                print(live.read(), end='', flush=True)
        code = 124 if timed_out else process.returncode
    text = (out / 'run.log').read_text(errors='replace')
    match = re.search(r'ACCEPTANCE ash_program=pass cycles=(\d+).*rx_bytes=(\d+)', text)
    accepted = bool(code == 0 and not args.smoke_cycles and match and
                    int(match[2]) == len('/bin/acceptance_smoke\n') and
                    'RV32 Linux userspace ready' in text and 'SHELL_PROMPT' in text and
                    'SHELL_INPUT' in text and
                    'PASS BusyBox ash executed /bin/acceptance_smoke' in text and
                    not any(token in text for token in ('FATAL', 'Error:', 'Kernel panic', 'SMOKE_ONLY')))
    smoke_ok = bool(args.smoke_cycles and code == 0 and
                    f'SMOKE_ONLY cycles={args.smoke_cycles} NOT_LINUX_ACCEPTANCE' in text)
    result = dict(manifest, status='pass' if accepted else 'smoke_only' if smoke_ok else 'timeout' if timed_out else 'fail',
                  linux_accepted=accepted, returncode=code,
                  elapsed_seconds=time.monotonic()-start,
                  acceptance_cycles=int(match[1]) if match else None)
    (out / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(text[-12000:], flush=True)
    print(json.dumps({k: result[k] for k in ('status','linux_accepted','elapsed_seconds','acceptance_cycles')}))
    return 0 if accepted or smoke_ok else code or 1


if __name__ == '__main__':
    raise SystemExit(main())
