"""Tag each MIT road section with the INEC parish / canton / province at its midpoint (planar, detailed boundaries)."""
import json, math, pathlib

HERE = pathlib.Path(__file__).parent
parr = json.load(open(HERE / 'geo' / 'parroquias.json'))['features']
roads_path = HERE / 'geo' / 'red_vial_mit.json'
roads = json.load(open(roads_path))


def rings(g):
    return [r for poly in ([g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']) for r in poly]


def bbox(g):
    xs = [p[0] for r in rings(g) for p in r]; ys = [p[1] for r in rings(g) for p in r]
    return min(xs), min(ys), max(xs), max(ys)


def inside(x, y, g):
    res = False
    for r in rings(g):
        for a in range(len(r)):
            (xa, ya), (xb, yb) = r[a], r[a - 1]
            if (ya > y) != (yb > y) and x < (xb - xa) * (y - ya) / (yb - ya) + xa:
                res = not res
    return res


def hav(a, b):
    t = math.pi / 180; dl, dn = (b[1] - a[1]) * t, (b[0] - a[0]) * t
    h = math.sin(dl / 2) ** 2 + math.cos(a[1] * t) * math.cos(b[1] * t) * math.sin(dn / 2) ** 2
    return 2 * 6371 * math.asin(math.sqrt(h))


def midpoint(g):
    lines = [g['coordinates']] if g['type'] == 'LineString' else g['coordinates']
    segs = [(a, b, hav(a, b)) for ln in lines for a, b in zip(ln, ln[1:])]
    total = sum(s[2] for s in segs); half = total / 2
    for a, b, L in segs:
        if half <= L and L > 0:
            f = half / L; return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f], total
        half -= L
    return lines[0][0], total


boxes = [(bbox(f['geometry']), f) for f in parr]
miss = 0
for f in roads['features']:
    (x, y), total = midpoint(f['geometry'])
    hit = next((p for (x0, y0, x1, y1), p in boxes if x0 <= x <= x1 and y0 <= y <= y1 and inside(x, y, p['geometry'])), None)
    if hit is None:   # midpoint on a border or outside: nearest parish by bbox centre
        miss += 1
        hit = min(boxes, key=lambda b: ((b[0][0] + b[0][2]) / 2 - x) ** 2 + ((b[0][1] + b[0][3]) / 2 - y) ** 2)[1]
    pr = hit['properties']
    f['properties'].update(parr=pr['code'], canton=pr['canton'], prov=pr['prov'], km=round(f['properties']['km'] or total, 2))
json.dump(roads, open(roads_path, 'w'), ensure_ascii=False, separators=(',', ':'))
print(f'annotated {len(roads["features"])} road sections ({miss} by nearest parish)')
