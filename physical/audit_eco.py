"""Fail closed on changed protected routes or unintended ECO connectivity."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import odb
from eco_helpers import def_routes, route_crossings


def main():
    p=argparse.ArgumentParser();p.add_argument('--odb',required=True);p.add_argument('--manifest',required=True);p.add_argument('--output',required=True);p.add_argument('--report-route-contacts',action='store_true');a=p.parse_args()
    m=json.loads(Path(a.manifest).read_text());out=Path(a.output)
    olddb=odb.dbDatabase.create();odb.read_db(olddb,m['original_odb']);old=olddb.getChip().getBlock()
    db=odb.dbDatabase.create();odb.read_db(db,a.odb);b=db.getChip().getBlock()
    def drivers(net,depth=0):
        if net is None:return ()
        if depth>300:raise ValueError('Buffer cycle in ECO')
        result=[]
        for term in net.getITerms():
            if term.getIoType()!='OUTPUT':continue
            inst=term.getInst();name=inst.getName()
            if name.startswith('ci_eco_'):
                if inst.getMaster().getName() not in ['sky130_fd_sc_hd__buf_4','sky130_fd_sc_hd__buf_8','sky130_fd_sc_hd__clkbuf_16']:raise ValueError('Unexpected ECO cell')
                result.extend(drivers(inst.findITerm('A').getNet(),depth+1))
            else:result.append(name+'/'+term.getMTerm().getName())
        result.extend('PORT:'+t.getName() for t in net.getBTerms() if t.getIoType()=='INPUT')
        return tuple(sorted(set(result)))
    checked=0
    for i in old.getInsts():
        j=b.findInst(i.getName())
        if j is None:
            if not i.getName().startswith('FILLER_'):raise ValueError('Original instance removed: '+i.getName())
            continue
        if i.getName() not in m['changed_instances']:
            if i.getLocation()!=j.getLocation() or i.getOrient()!=j.getOrient() or i.getMaster().getName()!=j.getMaster().getName():raise ValueError('Unrelated cell changed: '+i.getName())
        for t in i.getITerms():
            if t.getIoType()!='INPUT' or t.getSigType() in ['POWER','GROUND']:continue
            other=j.findITerm(t.getMTerm().getName())
            if not other or drivers(t.getNet())!=drivers(other.getNet()):raise ValueError('Connectivity changed: '+i.getName()+'/'+t.getMTerm().getName())
            checked+=1
    for t in old.getBTerms():
        other=b.findBTerm(t.getName())
        if not other:raise ValueError('Top port disappeared')
        if t.getIoType()=='OUTPUT' and drivers(t.getNet())!=drivers(other.getNet()):raise ValueError('Output connectivity changed: '+t.getName())
    path=out.with_suffix('.def');odb.write_def(b,str(path));routes=def_routes(path.read_text())
    for n in m['protected_nets']:
        if n not in routes or hashlib.sha256(routes[n][0].encode()).hexdigest()!=m['protected_geometry_sha256'][n]:raise ValueError('Protected route changed: '+n)
        d=odb.dbWireDecoder();d.begin(b.findNet(n).getWire());d.next()
        if str(d.getWireType())!='FIXED':raise ValueError('Protected route lost FIXED encoding: '+n)
    contacts=route_crossings(routes)
    if contacts:
        out.write_text(json.dumps(dict(status='fail',reason='Inter-net same-layer route contacts',contacts=contacts),indent=2)+'\n')
        if a.report_route_contacts:return
        raise ValueError(f'Physical route contacts found: {len(contacts)} (report capped at 100); see {out}')
    record=dict(status='pass',protected_nets=len(m['protected_nets']),editable_nets=len(m['editable_nets']),checked_original_input_pins=checked,route_centerline_contacts=0,
                odb_sha256=hashlib.sha256(Path(a.odb).read_bytes()).hexdigest(),scope='Logical driver and protected-route audit; DRC/LVS remain required')
    out.write_text(json.dumps(record,indent=2)+'\n');path.unlink();print(json.dumps(record))

if __name__=='__main__':main()
