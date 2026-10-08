"""ArcGIS / GIS-ready exports of the latest forecast (WGS84, EPSG:4326) into deploy/data/.

GeoJSON (ArcGIS Online: Add layer from URL), zipped Shapefile and CSV for:
  ecmwf_malla_025   native 0.25° ECMWF ENS cells: P(>20 mm) and P(>50 mm) and median rain per day
  parroquias_lluvia INEC 2024 parishes: the same attributes, area-weighted
  floodhub_puntos   Google Flood Hub gauges with their latest flood status
  geoglows_estaciones GEOGloWS demo stations with 2/5/20-year floods and daily median flow
MIT road data is never exported (not authorised for redistribution).
"""
import csv, json, pathlib, subprocess, zipfile

HERE = pathlib.Path(__file__).parent
OUT = HERE / 'deploy' / 'data'
DAYS = 15
WGS84_PRJ = 'GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]'


def day_attrs(p, med):
    a = {}
    for t in ('20', '50'):
        for d in range(DAYS): a[f'p{t}_d{d + 1:02d}'] = p[t][d]
    for d in range(DAYS): a[f'med_d{d + 1:02d}'] = med[d]
    return a


def write(name, features, csv_rows=None):
    gj = OUT / f'{name}.geojson'
    gj.write_text(json.dumps({'type': 'FeatureCollection', 'features': features}, ensure_ascii=False, separators=(',', ':')))
    shp_dir = OUT / f'_{name}_shp'; shp_dir.mkdir(exist_ok=True)
    subprocess.run(['npx', '-y', 'mapshaper@0.6', str(gj), '-o', 'format=shapefile', f'{shp_dir}/{name}.shp'], check=True, capture_output=True)
    (shp_dir / f'{name}.prj').write_text(WGS84_PRJ)
    (shp_dir / f'{name}.cpg').write_text('UTF-8')            # DBF text encoding, so ArcGIS reads ñ and accents
    with zipfile.ZipFile(OUT / f'{name}_shp.zip', 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(shp_dir.iterdir()): z.write(f, f.name)
    for f in shp_dir.iterdir(): f.unlink()
    shp_dir.rmdir()
    if csv_rows:
        with open(OUT / f'{name}.csv', 'w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=list(csv_rows[0])); w.writeheader(); w.writerows(csv_rows)
    return [p.name for p in OUT.glob(f'{name}*') if p.is_file()]


def main():
    fc_path = HERE / 'pipeline' / 'out' / 'forecast.json'
    if not fc_path.exists(): print('no forecast: skipping GIS exports'); return
    fc = json.loads(fc_path.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.iterdir():
        if old.is_file(): old.unlink()
    init, files = fc['init'], {}

    grid = fc.get('grid')
    if grid:
        h = grid['step_deg'] / 2; feats, rows = [], []
        for c in grid['cells']:
            x, y = c['lon'], c['lat']
            props = {'lat': y, 'lon': x, 'init': init, **day_attrs(c['p'], c['med'])}
            feats.append({'type': 'Feature', 'properties': props, 'geometry': {'type': 'Polygon', 'coordinates': [[[x - h, y - h], [x + h, y - h], [x + h, y + h], [x - h, y + h], [x - h, y - h]]]}})
            rows.append(props)
        files['ecmwf_malla_025'] = write('ecmwf_malla_025', feats, rows)

    parr_geo = HERE / 'data' / 'web' / 'parroquias_export.json'
    if parr_geo.exists() and fc.get('areas'):
        byc = {r['code']: r for r in fc['areas']['parroquia']}
        feats, rows = [], []
        for f in json.loads(parr_geo.read_text())['features']:
            r = byc.get(f['properties']['code'])
            if not r: continue
            props = {'dpa': r['code'], 'nombre': r['name'], 'canton': f['properties']['canton'], 'provincia': f['properties']['prov'], 'init': init, **day_attrs(r['p'], r['med'])}
            feats.append({'type': 'Feature', 'properties': props, 'geometry': f['geometry']}); rows.append(props)
        files['parroquias_lluvia'] = write('parroquias_lluvia', feats, rows)

    if fc.get('floodhub'):
        feats = [{'type': 'Feature', 'properties': {k: g[k] for k in ('id', 'verified', 'severity', 'trend', 'issued', 'from', 'to')} | {'lat': g['lat'], 'lon': g['lon']},
                  'geometry': {'type': 'Point', 'coordinates': [g['lon'], g['lat']]}} for g in fc['floodhub']]
        files['floodhub_puntos'] = write('floodhub_puntos', feats, [f['properties'] for f in feats])

    if fc.get('gauges'):
        feats = []
        for g in fc['gauges']:
            props = {'rio': g['name'], 'sitio': g['site'], 'river_id': g['river_id'], 'q2': g['rp']['2'], 'q5': g['rp']['5'], 'q20': g['rp']['20'],
                     **{f'q_d{d + 1:02d}': g['med'][d] for d in range(DAYS)}}
            feats.append({'type': 'Feature', 'properties': props, 'geometry': {'type': 'Point', 'coordinates': [g['lon'], g['lat']]}})
        files['geoglows_estaciones'] = write('geoglows_estaciones', feats, [f['properties'] | {'lat': f['geometry']['coordinates'][1], 'lon': f['geometry']['coordinates'][0]} for f in feats])

    manifest = {'generated': fc['generated'], 'init': init, 'crs': 'EPSG:4326 (WGS84)',
                'attributes': 'pXX_dNN = probabilidad (0–1) de lluvia > XX mm en el día NN; med_dNN = mediana en mm; q_dNN = caudal mediano m³/s',
                'sources': {'lluvia': fc.get('source_rain'), 'rios': fc.get('source_rivers'), 'floodhub': fc.get('source_floodhub'), 'limites': fc.get('source_areas')},
                'aviso': 'Pronóstico experimental de apoyo a la decisión. No es información oficial; prevalecen los avisos de la SNGR y el INAMHI.',
                'layers': files}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
    (OUT / 'LEEME_ArcGIS.txt').write_text(
        'Capas del Gemelo Digital Ecuador – El Niño (WGS84, EPSG:4326)\n\n'
        'ArcGIS Online / Map Viewer: Agregar capa > Agregar capa desde URL > GeoJSON > pegar la URL del archivo .geojson.\n'
        'ArcGIS Pro / QGIS: descargar el .zip (Shapefile) o el .csv (campos lat, lon) y agregarlo al mapa.\n'
        'Atributos: pXX_dNN = probabilidad (0-1) de lluvia > XX mm en el día NN del pronóstico; med_dNN = mediana (mm).\n'
        'Fuentes: ECMWF Open Data y GEOGloWS (CC BY 4.0); Google Flood Hub (CC BY 4.0); límites INEC 2024 vía OCHA COD-AB (CC BY-IGO).\n'
        'Aviso: pronóstico experimental; no es información oficial. Prevalecen los avisos de la SNGR y el INAMHI.\n', encoding='utf-8')
    print('GIS exports:', ', '.join(f'{k} ({len(v)} files)' for k, v in files.items()))


if __name__ == '__main__':
    main()
