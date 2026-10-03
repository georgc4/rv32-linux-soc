"""Generate equivalent-family resizes and noninverting buffers from CI reports.
Run inside OpenROAD's Python interpreter. Never match checkpoint-specific names.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import odb
from eco_tree import shared_buffer_tree


def quote(value):
    if any(c in value for c in '{}\n\r') or value.endswith('\\'):
        raise ValueError('Unsupported Tcl identifier: '+value)
    return '{'+value+'}'


def main():
    p=argparse.ArgumentParser();p.add_argument('--odb',required=True);p.add_argument('--pins',required=True);p.add_argument('--output',required=True);p.add_argument('--buffer-only',action='store_true');a=p.parse_args()
    db=odb.dbDatabase.create();odb.read_db(db,a.odb);b=db.getChip().getBlock();u=b.getDbUnitsPerMicron()
    pins=json.loads(Path(a.pins).read_text());nets={}
    for name in pins:
        inst_name,sep,term_name=name.rpartition('/')
        inst=b.findInst(inst_name) if sep else None
        term=inst.findITerm(term_name) if inst else b.findBTerm(name)
        if term is None or term.getNet() is None: raise ValueError('Reported pin not found: '+name)
        net=term.getNet()
        if net.getSigType() in ['POWER','GROUND']: raise ValueError('Electrical violation on supply: '+name)
        nets[net.getName()]=net
    if len(nets)>100: raise ValueError('More than 100 failing nets; refusing an unbounded ECO')
    lines=['set eco_movable {}'];edits=[];net_plans=[];serial=0
    def point(t):
        valid,x,y=t.getAvgXY();assert valid
        return x/u,y/u
    def pin(t):return t.getInst().getName()+'/'+t.getMTerm().getName()
    def insert(cell,loads,x,y):
        nonlocal serial
        if db.findMaster(cell) is None: raise ValueError('Missing buffer master: '+cell)
        serial+=1;name=f'ci_eco_{serial:04d}'
        assert b.findInst(name) is None
        lines.append('set created [insert_buffer -buffer_cell '+quote(cell)+' -load_pins [list '+ ' '.join(loads)+'] -location {'+f'{x:.3f} {y:.3f}'+'} -buffer_name '+quote(name)+' -net_name '+quote(name+'_net')+']')
        lines.extend(['if {$created == "NULL"} {error "ECO buffer insertion failed"}',f'set eco_name({serial}) [get_property $created full_name]',f'lappend eco_movable $eco_name({serial})'])
        edits.append(dict(kind='buffer',requested_name=name,cell=cell,location_um=[x,y]))
        return f'"$eco_name({serial})/A"'
    for name,net in sorted(nets.items()):
        drivers=[t for t in net.getITerms() if t.getIoType()=='OUTPUT']
        if len(drivers)!=1: raise ValueError('Expected one internal driver: '+name)
        driver=drivers[0];inst=driver.getInst();master=inst.getMaster().getName();loads=sorted([t for t in net.getITerms() if t.getIoType()=='INPUT'],key=pin)
        dx,dy=point(driver)
        before=serial
        clock='__clkbuf_' in master or net.getSigType()=='CLOCK'
        if clock:
            if '__clkbuf_' not in master or len(loads)<2: raise ValueError('Unsupported clock repair: '+name)
            # Split the actual sink set spatially; retain clock polarity and cell family.
            xs=[point(t)[0] for t in loads];ys=[point(t)[1] for t in loads]
            axis=0 if max(xs)-min(xs)>=max(ys)-min(ys) else 1
            ordered=sorted(loads,key=lambda t:(point(t)[axis],pin(t)));middle=len(ordered)//2
            for group in [ordered[:middle],ordered[middle:]]:
                gx=sum(point(t)[0] for t in group)/len(group);gy=sum(point(t)[1] for t in group)/len(group)
                insert('sky130_fd_sc_hd__clkbuf_16',[quote(pin(t)) for t in group],dx+(gx-dx)*0.25,dy+(gy-dy)*0.25)
            net_plans.append(dict(net=name,kind='clock_split',sinks=len(loads),buffers=serial-before,independent_chain_buffers=None))
            continue
        match=re.fullmatch(r'(sky130_fd_sc_hd__.+)_(\d+)',master)
        if not match: raise ValueError('Unsupported driver family: '+master)
        strength=int(match[2]);replacement=None if a.buffer_only else next((f'{match[1]}_{size}' for size in [strength*2,strength+1] if db.findMaster(f'{match[1]}_{size}')),None)
        if replacement:
            oldpins=sorted((t.getName(),t.getIoType(),t.getSigType()) for t in inst.getMaster().getMTerms())
            newpins=sorted((t.getName(),t.getIoType(),t.getSigType()) for t in db.findMaster(replacement).getMTerms())
            if oldpins!=newpins: raise ValueError('Resize pin interface changed')
            lines.extend(['replace_cell '+quote(inst.getName())+' '+quote(replacement),'estimate_parasitics -placement','lappend eco_movable '+quote(inst.getName())])
            edits.append(dict(kind='resize',instance=inst.getName(),old=master,new=replacement))
        locations=[(pin(load),*point(load)) for load in loads]
        independent=sum(max(0,math.ceil((abs(x-dx)+abs(y-dy))/80)-1)
                        for _,x,y in locations)
        tree=shared_buffer_tree((dx,dy),locations,force=not replacement)
        refs={}
        for node in tree['buffers']:
            sink_refs=[quote(ref['pin']) if 'pin' in ref else refs[ref['buffer']]
                       for ref in node['loads']]
            refs[node['id']]=insert(node['cell'],sink_refs,*node['point_um'])
        inserted=serial-before
        net_plans.append(dict(net=name,kind='shared_tree',sinks=len(loads),
                              buffers=inserted,independent_chain_buffers=independent,
                              driver_pin=pin(driver),driver_um=[dx,dy],
                              sinks_um=locations,tree=tree))
        if not replacement and not inserted: raise ValueError('No supported repair for '+name)
    out=Path(a.output)
    record=dict(target_pins=pins,target_nets=sorted(nets),edits=edits,buffer_only=a.buffer_only,
                buffer_count=serial,buffer_limit=250,net_plans=net_plans,
                status='ready' if serial<=250 else 'buffer_limit_exceeded',
                odb_sha256=hashlib.sha256(Path(a.odb).read_bytes()).hexdigest())
    # Preserve diagnostics even when the bound rejects the proposed plan.
    out.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(dict(buffer_count=serial,buffer_limit=250,target_nets=len(nets),
                         independent_chain_buffers=sum(n['buffers'] if n['independent_chain_buffers'] is None else n['independent_chain_buffers']
                                                       for n in net_plans)),sort_keys=True))
    if serial>250: raise ValueError('More than 250 buffers; refusing an unbounded ECO; see '+str(out.with_suffix('.json')))
    out.write_text('\n'.join(lines)+'\n')

if __name__=='__main__':main()
