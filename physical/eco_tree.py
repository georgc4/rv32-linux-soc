"""Deterministic geometric buffer trees; no OpenDB or timing claims.

Leaf groups have bounded fanout and bounding-box Manhattan span. Binary spatial
splits share upstream trunks. Every generated reference points to a preceding
buffer or an original sink, so insertion can execute from sinks toward driver.
Extracted timing and physical checks remain the authority after routing.
"""
import math


def shared_buffer_tree(driver, sinks, *, max_sinks=8, leaf_span=80.0,
                       spacing=90.0, force=False):
    """Return buffers in insertion order and the resulting original-net loads.

sinks: (pin_name, x_um, y_um); refs: {'pin': name} or {'buffer': local_index}.
    """
    if max_sinks < 2 or leaf_span <= 0 or spacing <= 0:
        raise ValueError('Invalid buffer tree bounds')
    sinks = sorted(sinks)
    if len({p[0] for p in sinks}) != len(sinks):
        raise ValueError('Duplicate sink pin')
    if not all(math.isfinite(v) for v in (*driver, *(v for p in sinks for v in p[1:]))):
        raise ValueError('Nonfinite buffer tree geometry')
    nodes = []

    def distance(a, b):
        return abs(a[0]-b[0]) + abs(a[1]-b[1])

    def bounds(group):
        xs, ys = [p[1] for p in group], [p[2] for p in group]
        return min(xs), min(ys), max(xs), max(ys)

    def insert(xy, refs, cell):
        index = len(nodes)
        nodes.append(dict(id=index, point_um=list(xy), loads=refs, cell=cell))
        return {'buffer': index}, xy

    def connect(origin, endpoint):
        # Build backward: farthest repeater first, then connect its input.
        ref, xy = endpoint
        count = max(0, math.ceil(distance(origin, xy)/spacing)-1)
        for index in range(count, 0, -1):
            fraction = index/(count+1)
            where = tuple(a+(b-a)*fraction for a, b in zip(origin, xy))
            ref, _ = insert(where, [ref], 'sky130_fd_sc_hd__buf_8')
        return ref

    def build(group):
        if len(group) == 1:
            name, x, y = group[0]
            return {'pin': name}, (x, y)
        x0, y0, x1, y1 = bounds(group)
        center = ((x0+x1)/2, (y0+y1)/2)
        if len(group) <= max_sinks and x1-x0+y1-y0 <= leaf_span:
            return insert(center, [{'pin': p[0]} for p in group],
                          'sky130_fd_sc_hd__buf_4')
        axis = 1 if x1-x0 >= y1-y0 else 2
        ordered = sorted(group, key=lambda p: (p[axis], p[0]))
        middle = len(ordered)//2
        children = [build(ordered[:middle]), build(ordered[middle:])]
        return insert(center, [connect(center, child) for child in children],
                      'sky130_fd_sc_hd__buf_8')

    if not sinks:
        roots = []
    elif not force and len(sinks) <= max_sinks and all(
            distance(driver, p[1:]) <= spacing for p in sinks):
        roots = [{'pin': p[0]} for p in sinks]
    else:
        endpoint = build(sinks)
        root = connect(driver, endpoint)
        if force and not nodes:
            xy = tuple((a+b)/2 for a, b in zip(driver, endpoint[1]))
            root, _ = insert(xy, [root], 'sky130_fd_sc_hd__buf_4')
        roots = [root]
    # Geometric branch points do not all need a physical buffer. Bypass a
    # junction only if the resulting parent still meets both explicit bounds.
    # This also removes redundant repeaters next to an already-buffered branch.
    active = {node['id']: node for node in nodes}
    pin_xy = {name: (x, y) for name, x, y in sinks}
    def location(ref):
        return pin_xy[ref['pin']] if 'pin' in ref else active[ref['buffer']]['point_um']
    changed = True
    while changed:
        changed = False
        parents = [(driver, roots)] + [(n['point_um'], n['loads']) for n in active.values()]
        for xy, refs in parents:
            for ref in list(refs):
                if 'buffer' not in ref or ref['buffer'] not in active:
                    continue
                child = active[ref['buffer']]
                if force and len(active) == 1:
                    continue
                if len(refs)-1+len(child['loads']) <= max_sinks and all(
                        distance(xy, location(load)) <= spacing for load in child['loads']):
                    index = refs.index(ref)
                    refs[index:index+1] = child['loads']
                    del active[ref['buffer']]
                    changed = True
                    break
            if changed:
                break  # rebuild parent list after removing a node
    remap = {old: new for new, old in enumerate(sorted(active))}
    def remap_ref(ref):
        return {'pin': ref['pin']} if 'pin' in ref else {'buffer': remap[ref['buffer']]}
    nodes = [dict(node, id=remap[old], loads=[remap_ref(r) for r in node['loads']])
             for old, node in sorted(active.items())]
    roots = [remap_ref(r) for r in roots]
    return dict(buffers=nodes, root_loads=roots,
                bounds=dict(max_sinks=max_sinks, leaf_span_um=leaf_span,
                            max_segment_um=spacing))
