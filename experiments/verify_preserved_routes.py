"""Run in OpenROAD Python to prove a selective ECO preserved unrelated wires."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import odb


def load(path):
    db = odb.dbDatabase.create()
    odb.read_db(db, str(path))
    return db, db.getChip().getBlock()


def routes(path):
    section = path.read_text().split('\nNETS ')[1].split('\nEND NETS')[0]
    result = {}
    for chunk in re.split(r'\n\s*- ', section)[1:]:
        name = chunk.split()[0]
        route = re.search(r'\+ (?:ROUTED|FIXED) ', chunk)
        if route:
            result[name] = ' '.join(re.sub(r'\+ (?:ROUTED|FIXED) ', '+ WIRE ', chunk[route.start():]).split())
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', required=True)
    parser.add_argument('--after', required=True)
    parser.add_argument('--manifest', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    ad, a = load(args.before); bd, b = load(args.after)
    output = Path(args.output); output.parent.mkdir(parents=True, exist_ok=True)
    errors = []; moved = []
    for i in a.getInsts():
        j = b.findInst(i.getName())
        if j is None or i.getMaster().getName() != j.getMaster().getName():
            errors.append('Instance changed/missing: ' + i.getName()); continue
        if i.getLocation() != j.getLocation() or i.getOrient() != j.getOrient():
            moved.append(i.getName())
            if i.getName() not in manifest['changed_instances']:
                errors.append('Unrelated instance moved: ' + i.getName())
        def pins(inst):
            return sorted((t.getMTerm().getName(), t.getNet().getName() if t.getNet() else '') for t in inst.getITerms() if t.getSigType() not in ['POWER','GROUND'])
        if pins(i) != pins(j): errors.append('Connectivity changed: ' + i.getName())
    types = {}
    for name in manifest['protected_nets']:
        net = b.findNet(name); wire = net.getWire() if net else None
        if wire is None:
            errors.append('Protected wire missing: ' + name); continue
        decoder = odb.dbWireDecoder(); decoder.begin(wire); decoder.next()
        kind = str(decoder.getWireType()); types[kind] = types.get(kind, 0) + 1
        if kind != 'FIXED': errors.append('Protected wire not FIXED: ' + name)
    paths = [output.with_suffix('.before.def'), output.with_suffix('.after.def')]
    odb.write_def(a, str(paths[0])); odb.write_def(b, str(paths[1]))
    x, y = (routes(p) for p in paths)
    changed = [name for name in manifest['protected_nets'] if name not in x or x.get(name) != y.get(name)]
    errors += ['Protected route geometry changed: ' + name for name in changed]
    record = dict(status='failed' if errors else 'pass', errors=errors,
                  protected_nets=len(manifest['protected_nets']), wire_types=types,
                  changed_protected_routes=changed, moved_instances=moved,
                  manifest_sha256=hashlib.sha256(Path(args.manifest).read_bytes()).hexdigest(),
                  before_sha256=hashlib.sha256(Path(args.before).read_bytes()).hexdigest(),
                  after_sha256=hashlib.sha256(Path(args.after).read_bytes()).hexdigest())
    output.write_text(json.dumps(record, indent=2) + '\n')
    for p in paths: p.unlink()
    print(json.dumps(record))
    if errors: raise RuntimeError('Route preservation audit failed')

if __name__ == '__main__':
    main()
