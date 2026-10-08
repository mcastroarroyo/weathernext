"""Build the twin page: inject INEC boundaries, names, the MIT road network (if present) and the latest pipeline forecast.

Writes gemelo-ecuador.html (artifact body), preview.html and deploy/index.html (full documents).
"""
import json, pathlib

HERE = pathlib.Path(__file__).parent
DATA = HERE / 'data'
topo = (DATA / 'web' / 'ecuador.topo.json').read_text()
names = {}
for f in ('provincias.json', 'cantones.json'):
    for ft in json.loads((DATA / 'geo' / f).read_text())['features']:
        names[ft['properties']['code']] = ft['properties']['name']
roads_path = DATA / 'web' / 'red_vial_mit.topo.json'          # MIT data: kept out of the public repo
roads = roads_path.read_text() if roads_path.exists() else 'null'
fc_path = HERE / 'pipeline' / 'out' / 'forecast.json'
real = fc_path.read_text() if fc_path.exists() else 'null'
if real != 'null' and '"areas"' not in real[:400] and '"areas":' not in real:   # older single-level format
    real = 'null'

page = (HERE / 'twin.template.html').read_text()
for key, val in (('/*__TOPO__*/', topo), ('/*__NAMES__*/', json.dumps(names, ensure_ascii=False)),
                 ('/*__ROADS__*/null', roads), ('/*__REAL__*/null', real)):
    assert key in page, key
    page = page.replace(key, val)
(HERE / 'deploy' / 'data').mkdir(parents=True, exist_ok=True)   # the container copies this folder even when there is no forecast yet
(HERE / 'gemelo-ecuador.html').write_text(page)
import export_gis; export_gis.main()   # ArcGIS-ready GeoJSON / Shapefile / CSV into deploy/data/

head = ('<!doctype html>\n<html lang="es">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<meta name="robots" content="noindex">\n</head>\n<body>\n')
full = head + page + '\n</body>\n</html>\n'
(HERE / 'preview.html').write_text(full)
(HERE / 'deploy' / 'index.html').write_text(full)
print('page built:', 'real forecast' if real != 'null' else 'demo only', '+ MIT roads' if roads != 'null' else '(no MIT roads)', f'({len(full) // 1024} KB)')

# ---- verification page (/verificacion) and one data file per verified run
vpath = HERE / 'pipeline' / 'out' / 'verification.json'
vdir = HERE / 'deploy' / 'verificacion' / 'data'; vdir.mkdir(parents=True, exist_ok=True)
for old in vdir.glob('*.json'): old.unlink()
runs = json.loads(vpath.read_text())['runs'] if vpath.exists() else []
index = []
for r in runs:
    src = r.get('source', 'ecmwf_ifs_ens'); fname = f"{src}_{r['init'].replace(':', '')}.json"
    (vdir / fname).write_text(json.dumps(r, ensure_ascii=False, separators=(',', ':')))
    index.append({'init': r['init'], 'source': src, 'leads': r['leads'], 'file': fname, 'calibrated': bool(r['levels']['canton'].get('calibrated', {}).get('active'))})
(vdir / 'index.json').write_text(json.dumps({'runs': index}))
twin_css = (HERE / 'twin.template.html').read_text()
twin_css = twin_css[twin_css.index('<style>'):twin_css.index('</style>') + 8]
vpage = (HERE / 'verif.template.html').read_text().replace('<!--__CSS__-->', twin_css).replace('/*__TOPO__*/', topo).replace('/*__NAMES__*/', json.dumps(names, ensure_ascii=False))
(HERE / 'deploy' / 'verificacion.html').write_text(head + vpage + '\n</body>\n</html>\n')
print(f'verification page built: {len(runs)} runs')
