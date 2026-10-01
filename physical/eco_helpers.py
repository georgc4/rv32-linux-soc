"""Pure helpers shared by the CI ECO planner and route-neighborhood selector."""
import re


def failing_pins(text):
    result = set()
    for section in ('max slew', 'max capacitance'):
        match = re.search(r'(?:^|\n)' + section + r'\n\n(.*?)(?:\n\n|\Z)', text, re.S)
        if not match:
            count_name = 'max cap' if section == 'max capacitance' else section
            count = re.search(r'(?:^|\n)' + count_name + r' violation count (\d+)\s*(?:\n|$)', text)
            if count and int(count[1]) == 0:
                continue
            raise ValueError('Missing report section: ' + section)
        for line in match.group(1).splitlines():
            if '(VIOLATED)' in line:
                fields = line.split()
                if len(fields) < 5:
                    raise ValueError('Malformed electrical violation: ' + line)
                result.add(fields[0])
    return result


def overlaps(a, b):
    return a[0] <= b[2] and b[0] <= a[2] and a[1] <= b[3] and b[1] <= a[3]


def expand(box, halo):
    return (box[0]-halo, box[1]-halo, box[2]+halo, box[3]+halo)


def def_routes(text):
    """Return normalized route text and conservative segment boxes in DEF DBU.

    Include both endpoints (and vias there). A positive routing halo covers wire
    widths and via enclosure. Reset '*' coordinate history on every NEW path.
    """
    section = text.split('\nNETS ', 1)[1].split('\nEND NETS', 1)[0]
    routes = {}
    for chunk in re.split(r'\n\s*- ', section)[1:]:
        name = chunk.split()[0]
        start = re.search(r'\+ (?:ROUTED|FIXED|COVER) ', chunk)
        if not start:
            continue
        route = chunk[start.start():]
        boxes = []
        for path in re.split(r'\bNEW\b|\+ (?:ROUTED|FIXED|COVER) ', route)[1:]:
            previous = None
            for match in re.finditer(r'\(\s*(-?\d+|\*)\s+(-?\d+|\*)(?:\s+-?\d+)?\s*\)', path):
                if previous is None and '*' in match.groups():
                    raise ValueError('DEF path starts with relative coordinates')
                point = tuple(previous[i] if v == '*' else int(v) for i,v in enumerate(match.groups()))
                other = previous or point
                boxes.append((min(point[0],other[0]),min(point[1],other[1]),max(point[0],other[0]),max(point[1],other[1])))
                previous = point
        if not boxes:
            raise ValueError('Unable to decode routed geometry: ' + name)
        normalized = ' '.join(re.sub(r'\+ (?:ROUTED|FIXED|COVER) ', '+ WIRE ', route).split())
        routes[name] = (normalized, boxes)
    return routes


def neighborhood(routes, affected, cell_boxes, cell_halo, route_halo):
    windows = [expand(b, cell_halo) for b in cell_boxes]
    windows += [expand(b, route_halo) for n in affected if n in routes for b in routes[n][1]]
    # Spatial bins avoid a nets x shapes x windows scan on a large design.
    pitch = max(cell_halo, route_halo, 1)
    bins = {}
    for box in windows:
        for x in range(box[0]//pitch, box[2]//pitch+1):
            for y in range(box[1]//pitch, box[3]//pitch+1):
                bins.setdefault((x,y), []).append(box)
    editable = set(affected)
    for name, (_, boxes) in routes.items():
        if name in editable: continue
        for box in boxes:
            found = any(overlaps(box, w)
                        for x in range(box[0]//pitch, box[2]//pitch+1)
                        for y in range(box[1]//pitch, box[3]//pitch+1)
                        for w in bins.get((x,y), ()))
            if found:
                editable.add(name); break
    return editable
