"""Generate a targeted ECO from the original partitioned candidate's actual pins.

Run with OpenROAD's Python interpreter. This reads the ODB but does not edit it.
The generated Tcl is applied later, with ordinary legalization and full rerouting.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import odb

p = argparse.ArgumentParser()
p.add_argument('--state', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
state = json.loads(a.state.read_text())
db = odb.dbDatabase.create()
odb.read_db(db, state['odb'])
block = db.getChip().getBlock()
units = block.getDbUnitsPerMicron()
targets = {'_25583_': 'nor2', '_26497_': 'a211o', '_26205_': 'or3',
           '_25685_': 'nor2', '_26547_': 'or2', '_22420_': 'inv'}
commands = []
edits = []


def point(pin):
    valid, x, y = pin.getAvgXY()
    assert valid
    return x / units, y / units


def pin_name(pin):
    return pin.getInst().getName() + '/' + pin.getMTerm().getName()


def buffer(name, cell, loads, x, y):
    assert block.findInst(name) is None
    assert db.findMaster(cell) is not None
    commands.append('insert_buffer -buffer_cell {' + cell + '} -load_pins {'
                    + ' '.join(loads) + '} -location {' + f'{x:.3f} {y:.3f}'
                    + '} -buffer_name {' + name + '} -net_name {' + name + '_net}')
    edits.append({'buffer': name, 'cell': cell, 'loads': loads, 'location_um': [x, y]})


for name, family in targets.items():
    inst = block.findInst(name)
    old = 'sky130_fd_sc_hd__' + family + '_2'
    new = 'sky130_fd_sc_hd__' + family + '_4'
    assert inst and inst.getMaster().getName() == old
    assert db.findMaster(new) is not None
    commands += [f'if {{[[$::block findInst {name}] getMaster] == "NULL"}} {{error "Missing driver {name}"}}',
                 f'if {{[[[$::block findInst {name}] getMaster] getName] ne "{old}"}} {{error "Driver identity changed: {name}"}}',
                 f'replace_cell {name} {new}']
    edits.append({'resize': name, 'from': old, 'to': new})
    outputs = [t for t in inst.getITerms() if t.getIoType() == 'OUTPUT']
    assert len(outputs) == 1
    driver = outputs[0]; net = driver.getNet(); dx, dy = point(driver)
    for load in sorted(net.getITerms(), key=pin_name):
        if load.getIoType() != 'INPUT':
            continue
        lx, ly = point(load)
        distance = abs(lx - dx) + abs(ly - dy)
        # Split only long branches on the six measured failing nets. Avoid a
        # design-wide maximum-wire-length repair and its extensive buffering.
        count = max(0, math.ceil(distance / 80.0) - 1)
        sink = pin_name(load)
        prefix = 'eco_lib15_' + hashlib.sha256(sink.encode()).hexdigest()[:10]
        for index in range(count, 0, -1):
            ratio = index / (count + 1)
            bname = prefix + '_' + str(index)
            buffer(bname, 'sky130_fd_sc_hd__buf_4', [sink],
                   dx + (lx - dx) * ratio, dy + (ly - dy) * ratio)
            sink = bname + '/A'

clock = block.findNet('clknet_0_clk')
assert clock
driver = [t for t in clock.getITerms() if t.getIoType() == 'OUTPUT']
assert len(driver) == 1 and pin_name(driver[0]) == 'clkbuf_0_clk/X'
cx, cy = point(driver[0])
loads = [t for t in clock.getITerms() if t.getIoType() == 'INPUT']
assert len(loads) == 8
west = [pin_name(t) for t in loads if point(t)[0] < cx]
east = [pin_name(t) for t in loads if point(t)[0] >= cx]
assert len(west) == len(east) == 4
buffer('eco_lib15_clock_west', 'sky130_fd_sc_hd__clkbuf_16', sorted(west), cx - 20, cy)
buffer('eco_lib15_clock_east', 'sky130_fd_sc_hd__clkbuf_16', sorted(east), cx + 20, cy)
a.output.write_text('\n'.join(commands) + '\n')
report = {'source_odb': state['odb'], 'source_odb_sha256': hashlib.sha256(Path(state['odb']).read_bytes()).hexdigest(),
          'tcl_sha256': hashlib.sha256(a.output.read_bytes()).hexdigest(),
          'resized_drivers': len(targets), 'inserted_buffers': sum('buffer' in x for x in edits), 'edits': edits}
a.output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'resized_drivers': report['resized_drivers'], 'inserted_buffers': report['inserted_buffers']}))
