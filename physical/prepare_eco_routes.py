"""Unlock ECO wires and their geometric neighborhood, preserving distant routes."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import odb
from eco_helpers import def_routes, neighborhood


def main():
    p=argparse.ArgumentParser();p.add_argument('--original',required=True);p.add_argument('--eco',required=True);p.add_argument('--output-dir',required=True);a=p.parse_args()
    out=Path(a.output_dir);out.mkdir(parents=True,exist_ok=True)
    olddb=odb.dbDatabase.create();odb.read_db(olddb,a.original);old=olddb.getChip().getBlock()
    db=odb.dbDatabase.create();odb.read_db(db,a.eco);b=db.getChip().getBlock();u=b.getDbUnitsPerMicron()
    def pins(net):return sorted([t.getInst().getName()+'/'+t.getMTerm().getName() for t in net.getITerms()]+['PORT:'+t.getName() for t in net.getBTerms()])
    def box(inst):
        r=inst.getBBox();return (r.xMin(),r.yMin(),r.xMax(),r.yMax())
    changed=[];boxes=[]
    for i in b.getInsts():
        previous=old.findInst(i.getName())
        if previous is None or previous.getMaster().getName()!=i.getMaster().getName() or previous.getLocation()!=i.getLocation() or previous.getOrient()!=i.getOrient():
            changed.append(i.getName());boxes.append(box(i))
            if previous:boxes.append(box(previous))
    affected=set()
    for net in b.getNets():
        if net.getSigType() in ['POWER','GROUND']:continue
        previous=old.findNet(net.getName())
        if previous is None or pins(net)!=pins(previous) or any(t.getInst().getName() in changed for t in net.getITerms()):affected.add(net.getName())
    before=out/'original.def';odb.write_def(old,str(before));routes=def_routes(before.read_text())
    editable=neighborhood(routes,affected,boxes,round(20*u),round(5*u))
    if len(editable)>max(100,0.25*len(routes)):
        raise ValueError(f'Repair neighborhood too broad: {len(editable)} / {len(routes)} nets')
    protected=[]
    for net in b.getNets():
        if net.getSigType() in ['POWER','GROUND']:continue
        wire=net.getWire()
        if net.getName() in editable:
            if wire:odb.dbWire.destroy(wire)
            net.setWireType('ROUTED')
        elif wire:
            net.setWireType('FIXED');protected.append(net.getName())
    odb.write_def(b,str(out/'fixed.def'))
    for inst in b.getInsts():
        for term in inst.getITerms():term.clearPrefAccessPoints()
    for point in list(b.getAccessPoints()):odb.dbAccessPoint.destroy(point)
    odb.dbBlock.destroy(b);odb.read_def(db.getTech(),str(out/'fixed.def'))
    odb.write_db(db,str(out/'prepared.odb'))
    manifest=dict(original_odb=a.original,eco_odb=a.eco,changed_instances=changed,
                  affected_nets=sorted(affected),editable_nets=sorted(editable),protected_nets=protected,
                  cell_halo_um=20,route_halo_um=5,original_sha256=hashlib.sha256(Path(a.original).read_bytes()).hexdigest(),
                  protected_geometry_sha256={n:hashlib.sha256(routes[n][0].encode()).hexdigest() for n in protected})
    (out/'preservation.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(dict(changed_instances=len(changed),affected_nets=len(affected),editable_nets=len(editable),protected_nets=len(protected))))

if __name__=='__main__':main()
