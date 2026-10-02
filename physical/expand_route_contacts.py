"""Explicitly promote protected routes involved in proven inter-net contacts."""
import argparse,json
from pathlib import Path
import odb


def main():
    p=argparse.ArgumentParser();p.add_argument('--odb',required=True);p.add_argument('--manifest',required=True)
    p.add_argument('--contacts',required=True);p.add_argument('--output-dir',required=True);a=p.parse_args()
    m=json.loads(Path(a.manifest).read_text());report=json.loads(Path(a.contacts).read_text())
    contacts=report['contacts'];nets=set(n for c in contacts for n in c['nets'])
    added=nets.intersection(m['protected_nets'])
    if not added:raise ValueError('Contacts involve no protected nets; refusing an unproductive retry')
    db=odb.dbDatabase.create();odb.read_db(db,a.odb);b=db.getChip().getBlock()
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
    m.setdefault('contact_expansions',[]).append(dict(promoted_nets=sorted(added),reroute_nets=sorted(nets),contacts=contacts))
    out=Path(a.output_dir);out.mkdir(parents=True,exist_ok=True)
    odb.write_db(db,str(out/'prepared.odb'))
    (out/'preservation.json').write_text(json.dumps(m,indent=2)+'\n')
    (out/'reroute-nets.json').write_text(json.dumps(sorted(nets),indent=2)+'\n')
    print(json.dumps(dict(promoted_nets=sorted(added),reroute_nets=len(nets),protected_nets=len(m['protected_nets']),editable_nets=len(editable))))

if __name__=='__main__':main()
