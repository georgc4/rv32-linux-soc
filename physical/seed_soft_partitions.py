"""Seed four connectivity partitions; retain fully movable cells and no fences.
Run with the pinned OpenROAD Python interpreter. This changes initial placement
only; it is not a native soft-region constraint or a qualification result.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import odb

p = argparse.ArgumentParser()
p.add_argument('--odb', required=True)
p.add_argument('--partition', required=True)
p.add_argument('--output', required=True)
a = p.parse_args()
db = odb.dbDatabase.create()
odb.read_db(db, a.odb)
b = db.getChip().getBlock()
core = b.getCoreArea()
u = b.getDbUnitsPerMicron()
parts = {}
for line in Path(a.partition).read_text().splitlines():
    name, value = line.split()
    parts[name] = int(value)
assert set(parts.values()) == {0, 1, 2, 3}
insts = {i.getName(): i for i in b.getInsts()}
movable = {n: i for n, i in insts.items() if not i.isFixed() and i.getMaster().isBlock() is False
           and not any(s in i.getMaster().getName() for s in ['__tap', '__decap', '__fill'])}
missing = set(movable) - set(parts)
assert not missing, f'Unpartitioned movable instances: {sorted(missing)[:20]}'
fixed_before = {n: (i.getLocation(), i.getOrient(), i.getPlacementStatus())
                for n, i in insts.items() if i.isFixed()}
def connectivity():
    rows = []
    for n, i in sorted(insts.items()):
        rows.append((n, i.getMaster().getName(), sorted(
            (t.getMTerm().getName(), t.getNet().getName() if t.getNet() else '') for t in i.getITerms())))
    return hashlib.sha256(json.dumps(rows).encode()).hexdigest()
before = connectivity()
# Four overlapping seed windows, occupying the existing core. All cells remain
# PLACED (movable); no region, blockage, fence, or new net is added.
x0, y0, width, height = core.xMin(), core.yMin(), core.dx(), core.dy()
part_areas = [0.0]*4
for name, i in movable.items():
    part_areas[parts[name]] += i.getMaster().getWidth()*i.getMaster().getHeight()
def windows(perm):
    by_quad = {quad: part for part, quad in enumerate(perm)}
    left = part_areas[by_quad[0]] + part_areas[by_quad[2]]
    right = part_areas[by_quad[1]] + part_areas[by_quad[3]]
    split_x = x0 + width*left/(left+right)
    result = {}
    for low, high, xl, xr, total in [(0,2,x0,split_x,left),(1,3,split_x,x0+width,right)]:
        split_y = y0 + height*part_areas[by_quad[low]]/total
        result[by_quad[low]] = (xl,y0,xr,split_y)
        result[by_quad[high]] = (xl,split_y,xr,y0+height)
    return result
edges = []
for net in b.getNets():
    if net.getSigType() in ['POWER', 'GROUND', 'CLOCK'] or net.getName() in ['clk', 'rst_n']: continue
    names = [t.getInst().getName() for t in net.getITerms()]
    if len(names) > 64: continue
    ids = sorted({parts[n] for n in names if n in movable})
    pins = []
    for t in net.getBTerms():
        r = t.getBBox(); pins.append(((r.xMin()+r.xMax())/2, (r.yMin()+r.yMax())/2))
    if len(ids) + len(pins) > 1: edges.append((ids, pins))
def score(perm):
    result = 0
    centres = {k: ((r[0]+r[2])/2,(r[1]+r[3])/2) for k,r in windows(perm).items()}
    for ids, pins in edges:
        pts = [centres[k] for k in ids] + pins
        result += max(q[0] for q in pts)-min(q[0] for q in pts)+max(q[1] for q in pts)-min(q[1] for q in pts)
    return result
permutation = min(itertools.permutations(range(4)), key=score)
counts = [0]*4; areas = [0.0]*4
regions = windows(permutation)
for name, i in sorted(movable.items()):
    part = parts[name]
    xl, yl, xr, yr = regions[part]; cx, cy = (xl+xr)/2, (yl+yr)/2
    h = hashlib.sha256(name.encode()).digest()
    rx = int.from_bytes(h[:8], 'big') / (2**64-1) - 0.5
    ry = int.from_bytes(h[8:16], 'big') / (2**64-1) - 0.5
    m = i.getMaster()
    x = max(x0, min(x0+width-m.getWidth(), round(cx + rx*(xr-xl)*1.2)))
    y = max(y0, min(y0+height-m.getHeight(), round(cy + ry*(yr-yl)*1.2)))
    i.setLocation(x, y)
    i.setPlacementStatus('PLACED')
    counts[part] += 1; areas[part] += m.getWidth()*m.getHeight()/u**2
assert connectivity() == before, 'Connectivity changed during placement seeding'
assert fixed_before == {n: (i.getLocation(), i.getOrient(), i.getPlacementStatus())
                        for n, i in insts.items() if i.isFixed()}, 'Fixed instances changed'
assert all(not i.isFixed() for i in movable.values())
assert max(areas)/sum(areas) < 0.30, 'Unbalanced partitions'
odb.write_db(db, a.output)
report = dict(kind='initial placement seeds, no persistent constraints', counts=counts,
              area_um2=areas, quadrant_assignment=permutation, movable_instances=len(movable),
              fixed_instances_unchanged=len(fixed_before), connectivity_sha256=before,
              partition_sha256=hashlib.sha256(Path(a.partition).read_bytes()).hexdigest(),
              cross_partition_nets=sum(len(ids)>1 for ids,pins in edges), costed_interpartition_or_io_nets=len(edges), seed_windows_dbu=regions)
Path(a.output+'.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))
