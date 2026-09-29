"""Freeze unaffected detailed routes for an ECO; run with OpenROAD -python.

Input --eco is the logically verified ECO database before legalization/rerouting.
DEF roundtrip converts the encoded wire paths to FIXED; setting dbNet wireType
alone does not change dbWireDecoder's type and is insufficient for TritonRoute.
"""
import argparse
import hashlib
import json
from pathlib import Path
import odb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original', required=True)
    parser.add_argument('--eco', required=True)
    parser.add_argument('--output-dir', required=True)
    args = parser.parse_args()
    out = Path(args.output_dir); out.mkdir(parents=True, exist_ok=False)
    a = odb.dbDatabase.create(); odb.read_db(a, args.original)
    old = a.getChip().getBlock()
    db = odb.dbDatabase.create(); odb.read_db(db, args.eco)
    block = db.getChip().getBlock()
    def pins(net):
        return sorted([t.getInst().getName()+'/'+t.getMTerm().getName() for t in net.getITerms()]
                      + ['PORT:'+t.getName() for t in net.getBTerms()])
    changed = set(); status = {}
    for inst in block.getInsts():
        name = inst.getName(); original = old.findInst(name)
        status[name] = inst.getPlacementStatus()
        if original is None or original.getMaster().getName() != inst.getMaster().getName():
            changed.add(name)
        else:
            if original.getLocation() != inst.getLocation() or original.getOrient() != inst.getOrient():
                raise ValueError('Unrelated instance moved before ECO: ' + name)
            inst.setPlacementStatus('LOCKED')
    affected = set(); protected = []
    for net in block.getNets():
        if net.getSigType() in ['POWER', 'GROUND']: continue
        original = old.findNet(net.getName())
        if (original is None or pins(net) != pins(original)
                or any(t.getInst().getName() in changed for t in net.getITerms())):
            affected.add(net.getName())
    for net in block.getNets():
        if net.getSigType() in ['POWER', 'GROUND']: continue
        wire = net.getWire()
        if net.getName() in affected:
            if wire: odb.dbWire.destroy(wire)
        elif wire:
            net.setWireType('FIXED'); protected.append(net.getName())
    odb.write_db(db, str(out/'prepared.odb'))
    odb.write_def(block, str(out/'protected.def'))
    # Master-pin access IDs point into the old block. Clear them before
    # destroying it; retaining these IDs makes TritonRoute dereference freed data.
    for inst in block.getInsts():
        for term in inst.getITerms(): term.clearPrefAccessPoints()
    for point in list(block.getAccessPoints()):
        odb.dbAccessPoint.destroy(point)
    assert not list(block.getAccessPoints())
    odb.dbBlock.destroy(block)
    odb.read_def(db.getTech(), str(out/'protected.def'))
    odb.write_db(db, str(out/'encoded-fixed.odb'))
    manifest = dict(changed_instances=sorted(changed), affected_nets=sorted(affected),
                    protected_nets=protected, original_status=status,
                    original_sha256=hashlib.sha256(Path(args.original).read_bytes()).hexdigest(),
                    eco_sha256=hashlib.sha256(Path(args.eco).read_bytes()).hexdigest())
    (out/'preparation.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'{len(changed)} changed instances; {len(affected)} affected nets; {len(protected)} protected nets')

if __name__ == '__main__':
    main()
