"""Rip up routes implicated by contacts/DRC, promoting protected nets as needed."""
import argparse,json
from pathlib import Path
import odb
from eco_helpers import contact_repair_nets


def main():
    p=argparse.ArgumentParser();p.add_argument('--odb',required=True);p.add_argument('--manifest',required=True)
    p.add_argument('--contacts',required=True);p.add_argument('--output-dir',required=True);p.add_argument('--include-protected-obstacles',action='store_true');a=p.parse_args()
    m=json.loads(Path(a.manifest).read_text());report=json.loads(Path(a.contacts).read_text())
    contacts=report.get('contacts',[])
    routing_drc=report.get('routing_drc',[])
    db=odb.dbDatabase.create();odb.read_db(db,a.odb);b=db.getChip().getBlock()
    supplies={n.getName() for n in b.getNets() if n.getSigType() in ['POWER','GROUND']}
    signal_markers=[]
    for marker in routing_drc:
        for name in marker.get('instances',[]):
            if b.findInst(name) is None:raise ValueError('Unknown DRC instance: '+name)
        # Power shapes and cell obstructions stay fixed; route the signal around them.
        signal_markers.append(dict(marker,nets=sorted(set(marker['nets'])-supplies)))
    nets,added=contact_repair_nets(contacts,m['editable_nets'],m['protected_nets'],signal_markers,prefer_editable=not a.include_protected_obstacles)
    if 'original_routed_nets' not in m:
        olddb=odb.dbDatabase.create();odb.read_db(olddb,m['original_odb'])
        m['original_routed_nets']=sum(bool(n.getWire()) for n in olddb.getChip().getBlock().getNets() if n.getSigType() not in ['POWER','GROUND'])
    editable=set(m['editable_nets'])|added
    if len(editable)>max(100,m['max_editable_fraction']*m['original_routed_nets']):
        raise ValueError('Contact repair exceeds the existing editable-net budget')
    for name in nets:
        net=b.findNet(name)
        if net is None or net.getSigType() in ['POWER','GROUND']:raise ValueError('Invalid contact net: '+name)
        if net.getWire():odb.dbWire.destroy(net.getWire())
        net.setWireType('ROUTED')
    m['editable_nets']=sorted(editable);m['protected_nets']=sorted(set(m['protected_nets'])-added)
    m.setdefault('contact_expansions',[]).append(dict(promoted_nets=sorted(added),reroute_nets=sorted(nets),contacts=contacts,routing_drc=routing_drc))
    out=Path(a.output_dir);out.mkdir(parents=True,exist_ok=True)
    odb.write_db(db,str(out/'prepared.odb'))
    (out/'preservation.json').write_text(json.dumps(m,indent=2)+'\n')
    (out/'reroute-nets.json').write_text(json.dumps(sorted(nets),indent=2)+'\n')
    print(json.dumps(dict(promoted_nets=sorted(added),reroute_nets=len(nets),protected_nets=len(m['protected_nets']),editable_nets=len(editable))))

if __name__=='__main__':main()
