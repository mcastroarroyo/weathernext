"""GDE-Niño backup-source pipeline.

ECMWF IFS ENS open data (50 perturbed members, CC BY 4.0) -> daily rain per province, canton and parish (INEC 2024) -> exceedance probabilities.
GEOGloWS v2 (52 members, CC BY 4.0) -> daily river flow at demo gauges -> P(Q >= 2/5/20-year flood).
Google Flood Forecasting API (key from FLOOD_API_KEY or Secret Manager floodforecasting-api-key) -> latest status of every Ecuador gauge.
Also keeps the native 0.25° grid (ArcGIS-ready export). Writes out/forecast.json (for the demo) and NDJSON rows, and optionally loads them into BigQuery.

Usage: .venv/bin/python pipeline.py [--skip-download] [--crop] [--bq PROJECT]
"""
import argparse, datetime as dt, json, math, pathlib, subprocess, sys
import numpy as np, requests, eccodes
from ecmwf.opendata import Client

HERE = pathlib.Path(__file__).parent
DATA, OUT = HERE / 'data', HERE / 'out'
THRESHOLDS = [20, 30, 50, 100]            # mm in 24 h
DAYS = 15
LAT_N, LAT_S, LON_W, LON_E = 2.0, -5.5, -92.5, -75.0   # Ecuador incl. Galápagos
GAUGES = [
    ('Río Esmeraldas', 'Esmeraldas', -79.65, .93), ('Río Chone', 'Chone', -80.10, -.70),
    ('Río Portoviejo', 'Portoviejo', -80.45, -1.05), ('Río Quevedo', 'Quevedo', -79.46, -1.03),
    ('Río Babahoyo', 'Babahoyo', -79.53, -1.80), ('Río Daule', 'Daule', -79.98, -1.86),
    ('Río Jubones', 'Pasaje', -79.81, -3.33), ('Río Zarumilla', 'Huaquillas', -80.23, -3.48),
    ('Río Jatunyacu', 'Otavalo', -78.27, .23)]
GEOGLOWS = 'https://geoglows.ecmwf.int/api/v2'


# ---------------- ECMWF ENS ----------------
def download_ens(retries=4, crop=False):
    """One file per forecast step, with a socket timeout and retries; completed steps are kept and resumed.
    crop=True keeps only the Ecuador window of each step (ens_XXX.npz, ~0.5 MB) and deletes the 42 MB global GRIB."""
    import socket, time
    socket.setdefaulttimeout(90)                       # a stalled transfer raises instead of hanging forever
    DATA.mkdir(exist_ok=True)
    c = Client(source='google', model='ifs')
    run = c.latest(type='pf', stream='enfo', param='tp', step=24 * DAYS)   # latest 00/12Z run that reaches 360 h
    print('ECMWF ENS run', run)
    marker = DATA / 'run.txt'
    if not marker.exists() or marker.read_text() != str(run):     # new run: drop the previous run's steps
        for f in [*DATA.glob('ens_pf*.grib2'), *DATA.glob('ens_*.npz')]: f.unlink()
        marker.write_text(str(run))
    for step in range(0, 24 * DAYS + 1, 24):
        target = DATA / f'ens_pf_{step:03d}.grib2'
        if (DATA / f'ens_{step:03d}.npz').exists() or (target.exists() and target.stat().st_size > 1_000_000): continue
        for attempt in range(1, retries + 1):
            try:
                c.retrieve(date=run, type='pf', stream='enfo', param='tp', step=step, number=list(range(1, 51)), target=str(target) + '.part')
                (DATA / f'ens_pf_{step:03d}.grib2.part').rename(target)
                if crop: crop_step(target)
                break
            except Exception as e:                          # timeout or HTTP error: retry this step only
                print(f'step {step}: attempt {attempt} failed ({type(e).__name__}); retrying')
                time.sleep(5 * attempt)
        else:
            raise SystemExit(f'ECMWF step {step} failed after {retries} attempts')
    return run


def crop_step(path):
    """Cut every member of one GRIB step file to the Ecuador window and save it as ens_XXX.npz (then delete the GRIB)."""
    fields, init, lat, lon = {}, None, None, None
    with open(path, 'rb') as f:
        while (gid := eccodes.codes_grib_new_from_file(f)) is not None:
            try:
                ni, nj = eccodes.codes_get(gid, 'Ni'), eccodes.codes_get(gid, 'Nj')
                lat0, lon0 = eccodes.codes_get(gid, 'latitudeOfFirstGridPointInDegrees'), eccodes.codes_get(gid, 'longitudeOfFirstGridPointInDegrees')
                dlat, dlon = eccodes.codes_get(gid, 'jDirectionIncrementInDegrees'), eccodes.codes_get(gid, 'iDirectionIncrementInDegrees')
                num = eccodes.codes_get(gid, 'number') if eccodes.codes_get(gid, 'dataType') == 'pf' else 0
                step = int(eccodes.codes_get(gid, 'endStep'))
                if init is None:
                    d, t = eccodes.codes_get(gid, 'dataDate'), eccodes.codes_get(gid, 'dataTime')
                    init = dt.datetime.strptime(f'{d}{t:04d}', '%Y%m%d%H%M').replace(tzinfo=dt.timezone.utc)
                v = eccodes.codes_get_values(gid).reshape(nj, ni)
                lats = lat0 - np.arange(nj) * dlat
                lons = (lon0 + np.arange(ni) * dlon + 180) % 360 - 180
                rows = np.where((lats <= LAT_N) & (lats >= LAT_S))[0]
                cols = np.where((lons >= LON_W) & (lons <= LON_E))[0]
                fields[num] = v[np.ix_(rows, cols)].astype('float32')
                lat, lon = lats[rows], lons[cols]
            finally:
                eccodes.codes_release(gid)
    members = sorted(fields)
    np.savez(DATA / f'ens_{step:03d}.npz', tp=np.stack([fields[m] for m in members]), members=members, lat=lat, lon=lon, step=step, init=init.isoformat())
    path.unlink()


def read_ens():
    """Return init datetime, lat, lon, steps and tp[member, step_index, lat, lon] (metres) cut to Ecuador."""
    for path in sorted(DATA.glob('ens_pf_*.grib2')): crop_step(path)        # local runs keep the GRIB until here
    parts = [np.load(f) for f in sorted(DATA.glob('ens_*.npz'))]
    steps = [int(z['step']) for z in parts]
    tp = np.stack([z['tp'] for z in parts], axis=1)
    lat, lon, init = parts[0]['lat'], parts[0]['lon'], dt.datetime.fromisoformat(str(parts[0]['init']))
    order = np.argsort(lon); tp, lon = tp[..., order], lon[order]     # longitudes may not be monotonic after wrapping
    print(f'ENS: {tp.shape[0]} members, steps {steps[0]}–{steps[-1]} h, grid {len(lat)}×{len(lon)}, init {init:%Y-%m-%d %HZ}')
    return init, lat, lon, steps, tp


# ---------------- areas (INEC 2024: provinces, cantons, parishes) ----------------
GEO = HERE.parent / 'data' / 'geo'
LEVELS = [('provincia', 'provincias.json'), ('canton', 'cantones.json'), ('parroquia', 'parroquias.json')]
SAMPLE = 0.04   # degrees: lattice used to average the 0.25° field over each polygon


def inside(xs, ys, geom):
    """Vectorised even-odd point-in-polygon for arrays of points."""
    res = np.zeros(xs.shape, bool)
    for poly in ([geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']):
        for ring in poly:
            r = np.asarray(ring); xa, ya = r[:, 0], r[:, 1]; xb, yb = np.roll(xa, 1), np.roll(ya, 1)
            for k in range(len(r)):
                if ya[k] == yb[k]: continue
                cross = ((ya[k] > ys) != (yb[k] > ys)) & (xs < (xb[k] - xa[k]) * (ys - ya[k]) / (yb[k] - ya[k]) + xa[k])
                res ^= cross
    return res


def area_weights(geom, lat, lon):
    """Weights over grid cells: bilinear interpolation of the field at lattice points inside the polygon."""
    pts = np.concatenate([np.asarray(r) for poly in ([geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']) for r in poly[:1]])
    x0, y0 = pts.min(axis=0); x1, y1 = pts.max(axis=0)
    gx, gy = np.meshgrid(np.arange(x0 + SAMPLE / 2, x1, SAMPLE), np.arange(y0 + SAMPLE / 2, y1, SAMPLE))
    xs, ys = gx.ravel(), gy.ravel()
    m = inside(xs, ys, geom) if xs.size else np.zeros(0, bool)
    xs, ys = (xs[m], ys[m]) if m.any() else (np.array([(x0 + x1) / 2]), np.array([(y0 + y1) / 2]))
    # lat is descending, lon ascending, both regular 0.25°
    fi = np.clip((lat[0] - ys) / (lat[0] - lat[1]), 0, len(lat) - 1.001); fj = np.clip((xs - lon[0]) / (lon[1] - lon[0]), 0, len(lon) - 1.001)
    i0, j0 = fi.astype(int), fj.astype(int); wi, wj = fi - i0, fj - j0
    w = np.zeros((len(lat), len(lon)))
    for di, dj, ww in ((0, 0, (1 - wi) * (1 - wj)), (1, 0, wi * (1 - wj)), (0, 1, (1 - wi) * wj), (1, 1, wi * wj)):
        np.add.at(w, (i0 + di, j0 + dj), ww)
    return (w / w.sum()).ravel(), int(xs.size)


def area_rain(lat, lon, steps, tp):
    s = {st: k for k, st in enumerate(steps)}
    daily = np.stack([tp[:, s[24 * d]] - tp[:, s[24 * (d - 1)]] for d in range(1, DAYS + 1)], axis=1) * 1000  # mm
    daily = np.clip(daily, 0, None).reshape(daily.shape[0], DAYS, -1)      # [member, day, cell]
    out = {}; used = np.zeros(len(lat) * len(lon), bool)
    for level, fname in LEVELS:
        gj = json.load(open(GEO / fname)); rows = []
        for f in gj['features']:
            w, n = area_weights(f['geometry'], lat, lon); used |= w > 0
            series = daily @ w                                   # area-weighted rain per member and day
            pr = f['properties']
            rows.append({'code': pr['code'], 'name': pr['name'], 'parent': pr.get('canton') or pr.get('prov'), 'samples': n,
                         'p': {str(t): np.round((series > t).mean(axis=0), 2).tolist() for t in THRESHOLDS},
                         'med': np.round(np.median(series, axis=0), 1).tolist(),
                         'p90': np.round(np.percentile(series, 90, axis=0), 1).tolist()})
        out[level] = rows
        print(f'{level}: {len(rows)} areas')
    return out, used.reshape(len(lat), len(lon))


def grid_rain(lat, lon, steps, tp, areas_used):
    """The native 0.25° ECMWF cells over Ecuador (ArcGIS-ready grid): P(rain > t) per day, median and p90."""
    s = {st: k for k, st in enumerate(steps)}
    daily = np.clip(np.stack([tp[:, s[24 * d]] - tp[:, s[24 * (d - 1)]] for d in range(1, DAYS + 1)], axis=1) * 1000, 0, None)
    cells = []
    for i, j in zip(*np.nonzero(areas_used)):
        v = daily[:, :, i, j]
        cells.append({'lat': round(float(lat[i]), 3), 'lon': round(float(lon[j]), 3),
                      'p': {str(t): np.round((v > t).mean(axis=0), 2).tolist() for t in THRESHOLDS},
                      'med': np.round(np.median(v, axis=0), 1).tolist(), 'p90': np.round(np.percentile(v, 90, axis=0), 1).tolist()})
    print(f'grid: {len(cells)} cells of 0.25°')
    return {'step_deg': round(float(abs(lat[1] - lat[0])), 4), 'cells': cells}


# ---------------- Google Flood Forecasting API ----------------
FLOOD_API = 'https://floodforecasting.googleapis.com/v1/'


def flood_api_key(project):
    import os
    if os.environ.get('FLOOD_API_KEY'): return os.environ['FLOOD_API_KEY']
    if not project: return None
    r = subprocess.run(['gcloud', 'secrets', 'versions', 'access', 'latest', '--secret=floodforecasting-api-key', f'--project={project}'], capture_output=True, text=True)
    return r.stdout.strip() or None


def floodhub(key):
    """All Ecuador gauges and their latest flood status (CC BY 4.0, attribution: Google Flood Hub)."""
    def post(path, field, body):
        out, tok = [], None
        while True:
            b = dict(body, pageSize=1000, **({'pageToken': tok} if tok else {}))
            d = requests.post(FLOOD_API + path, params={'key': key}, json=b, timeout=90).json()
            if 'error' in d: raise SystemExit(f'Flood API {path}: {d["error"].get("message")}')
            out += d.get(field, []); tok = d.get('nextPageToken')
            if not tok: return out
    gauges = post('gauges:searchGaugesByArea', 'gauges', {'regionCode': 'EC', 'includeNonQualityVerified': True, 'includeGaugesWithoutHydroModel': True})
    status = {s['gaugeId']: s for s in post('floodStatus:searchLatestFloodStatusByArea', 'floodStatuses', {'regionCode': 'EC', 'includeNonQualityVerified': True})}
    rows = []
    for g in gauges:
        st = status.get(g['gaugeId'], {})
        rows.append({'id': g['gaugeId'], 'lat': round(g['location']['latitude'], 4), 'lon': round(g['location']['longitude'], 4),
                     'verified': bool(g.get('qualityVerified')), 'model': bool(g.get('hasModel')), 'river': g.get('river') or '', 'site': g.get('siteName') or '',
                     'severity': st.get('severity', 'UNKNOWN'), 'trend': st.get('forecastTrend', ''), 'issued': st.get('issuedTime', ''),
                     'from': st.get('forecastTimeRange', {}).get('start', ''), 'to': st.get('forecastTimeRange', {}).get('end', '')})
    from collections import Counter
    print(f'Flood Hub: {len(rows)} gauges ({sum(r["verified"] for r in rows)} verified) · ' + ', '.join(f'{k} {v}' for k, v in Counter(r['severity'] for r in rows).items()))
    return rows


# ---------------- GEOGloWS ----------------
def gumbel(annual_max, T):
    mu, sd = float(np.mean(annual_max)), float(np.std(annual_max, ddof=1))
    k = -(math.sqrt(6) / math.pi) * (0.5772 + math.log(math.log(T / (T - 1))))
    return mu + k * sd


def rivers():
    out = []
    for name, site, lon, lat in GAUGES:
        rid = requests.get(f'{GEOGLOWS}/getriverid', params={'lat': lat, 'lon': lon}, timeout=60).json()['river_id']
        ens = requests.get(f'{GEOGLOWS}/forecastensemble/{rid}', params={'format': 'json'}, timeout=120).json()
        retro = requests.get(f'{GEOGLOWS}/retrospectivedaily/{rid}', params={'format': 'json'}, timeout=180).json()
        # return periods from annual maxima of the 1940–2025 daily simulation (Gumbel, method of moments)
        years = {}
        for t, q in zip(retro['datetime'], retro[str(rid)]):
            if q not in ('', None) and int(t[:4]) <= 2025: years[t[:4]] = max(years.get(t[:4], 0), float(q))
        rp = {T: round(gumbel(list(years.values()), T), 1) for T in (2, 5, 20)}
        # daily max per member over the 15-day forecast
        times = [dt.datetime.fromisoformat(t) for t in ens['datetime']]
        t0 = times[0]
        mem_keys = [k for k in ens if k.startswith('ensemble_')]
        daily = np.full((len(mem_keys), DAYS), np.nan)
        for m, k in enumerate(mem_keys):
            for t, q in zip(times, ens[k]):
                if q in ('', None): continue
                d = int((t - t0).total_seconds() // 86400)
                if d < DAYS: daily[m, d] = np.nanmax([daily[m, d], float(q)])
        valid = ~np.isnan(daily).all(axis=0)
        med = np.nanmedian(daily, axis=0); lo = np.nanpercentile(daily, 10, axis=0); hi = np.nanpercentile(daily, 90, axis=0)
        p = {str(T): [round(float(np.nanmean(daily[:, d] >= q)), 3) if valid[d] else None for d in range(DAYS)] for T, q in rp.items()}
        out.append({'name': name, 'site': site, 'lon': lon, 'lat': lat, 'river_id': rid, 'members': len(mem_keys),
                    'start': t0.isoformat(), 'rp': {str(k): v for k, v in rp.items()},
                    'med': [None if np.isnan(x) else round(float(x), 1) for x in med],
                    'lo': [None if np.isnan(x) else round(float(x), 1) for x in lo],
                    'hi': [None if np.isnan(x) else round(float(x), 1) for x in hi], 'p': p})
        print(f'GEOGloWS {name}: river {rid}, Q2/Q5/Q20 = {rp[2]}/{rp[5]}/{rp[20]} m3/s, peak median {np.nanmax(med):.0f}')
    return out


# ---------------- outputs ----------------
def write_area_rows(path, init, areas, source):
    with open(path, 'w') as f:
        for level, rows in areas.items():
            for c in rows:
                for d in range(DAYS):
                    for t in THRESHOLDS:
                        f.write(json.dumps({'init_time': init.isoformat(), 'source': source, 'level': level, 'dpa_code': c['code'], 'name': c['name'],
                                            'parent_code': c['parent'], 'lead_day': d + 1, 'valid_date': (init + dt.timedelta(days=d)).date().isoformat(),
                                            'threshold_mm': t, 'probability': c['p'][str(t)][d], 'median_mm': c['med'][d], 'p90_mm': c['p90'][d]}, ensure_ascii=False) + '\n')


def extra_sources(init, names):
    """Other ensembles on the same init, for verification only: area rows -> out/area_exceedance_<source>.ndjson."""
    import sources
    for name in names:
        try:
            _, lat, lon, steps, tp = sources.SOURCES[name](init, DATA / name)
            areas, _ = area_rain(lat, lon, steps, tp)
            write_area_rows(OUT / f'area_exceedance_{name}.ndjson', init, areas, name)
        except Exception as e:                       # an extra source must never cost the day's main run
            print(f'{name} skipped: {type(e).__name__}: {e}')


def write_outputs(init, areas, gauges, grid=None, flood=None):
    OUT.mkdir(exist_ok=True)
    doc = {'generated': dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'), 'init': init.isoformat(),
           'source_rain': 'ECMWF IFS ENS open data, 50 members, 0.25° (CC BY 4.0); area-weighted bilinear average',
           'source_rivers': 'GEOGloWS v2, 52 members; return periods: Gumbel on 1940–2025 daily simulation (CC BY 4.0)',
           'source_areas': 'INEC 2024 DPA boundaries via OCHA COD-AB (CC BY-IGO)',
           'thresholds': THRESHOLDS, 'days': DAYS, 'areas': areas, 'gauges': gauges, 'grid': grid, 'floodhub': flood,
           'source_floodhub': 'Google Flood Forecasting API, latest flood status (CC BY 4.0, Google Flood Hub)' if flood else None}
    (OUT / 'forecast.json').write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    write_area_rows(OUT / 'area_exceedance.ndjson', init, areas, 'ecmwf_ifs_ens')
    with open(OUT / 'river_forecast.ndjson', 'w') as f:
        for g in gauges:
            for d in range(DAYS):
                f.write(json.dumps({'init_time': g['start'], 'source': 'geoglows_v2', 'river': g['name'], 'site': g['site'], 'river_id': g['river_id'],
                                    'lead_day': d + 1, 'q_median': g['med'][d], 'q_p10': g['lo'][d], 'q_p90': g['hi'][d],
                                    'rp2': g['rp']['2'], 'rp5': g['rp']['5'], 'rp20': g['rp']['20'],
                                    'p_rp2': g['p']['2'][d], 'p_rp5': g['p']['5'][d], 'p_rp20': g['p']['20'][d]}, ensure_ascii=False) + '\n')
    with open(OUT / 'floodhub_status.ndjson', 'w') as f:
        for r in flood or []:
            f.write(json.dumps({'fetched_at': doc['generated'], 'gauge_id': r['id'], 'lat': r['lat'], 'lon': r['lon'], 'quality_verified': r['verified'],
                                'has_model': r['model'], 'severity': r['severity'], 'trend': r['trend'], 'issued_time': r['issued'] or None,
                                'forecast_start': r['from'] or None, 'forecast_end': r['to'] or None}) + '\n')
    print('wrote', OUT / 'forecast.json')


def bq_load(project, init):
    """Append the NDJSON files to ectwin_commons; forecast tables are skipped when this run is already loaded (safe to re-run)."""
    from google.cloud import bigquery
    client = bigquery.Client(project=project)
    schemas = {
        'area_exceedance': 'init_time:TIMESTAMP,source:STRING,level:STRING,dpa_code:STRING,name:STRING,parent_code:STRING,lead_day:INTEGER,valid_date:DATE,threshold_mm:INTEGER,probability:FLOAT,median_mm:FLOAT,p90_mm:FLOAT',
        'floodhub_status': 'fetched_at:TIMESTAMP,gauge_id:STRING,lat:FLOAT,lon:FLOAT,quality_verified:BOOLEAN,has_model:BOOLEAN,severity:STRING,trend:STRING,issued_time:TIMESTAMP,forecast_start:TIMESTAMP,forecast_end:TIMESTAMP',
        'river_forecast': 'init_time:TIMESTAMP,source:STRING,river:STRING,site:STRING,river_id:INTEGER,lead_day:INTEGER,q_median:FLOAT,q_p10:FLOAT,q_p90:FLOAT,rp2:FLOAT,rp5:FLOAT,rp20:FLOAT,p_rp2:FLOAT,p_rp5:FLOAT,p_rp20:FLOAT'}
    river_init = next((json.loads(l)['init_time'] for l in open(OUT / 'river_forecast.ndjson')), None)
    files = [(t, OUT / f'{t}.ndjson') for t in schemas] + [('area_exceedance', f) for f in sorted(OUT.glob('area_exceedance_*.ndjson'))]
    for table, path in files:
        if not path.exists() or path.stat().st_size == 0: continue
        first = json.loads(open(path).readline())
        if table in ('area_exceedance', 'river_forecast'):
            key = init.isoformat() if table == 'area_exceedance' else river_init
            n = list(client.query(f'SELECT COUNT(*) n FROM ectwin_commons.{table} WHERE init_time = TIMESTAMP(@t) AND source = @s',
                                  job_config=bigquery.QueryJobConfig(query_parameters=[bigquery.ScalarQueryParameter('t', 'STRING', key),
                                                                                       bigquery.ScalarQueryParameter('s', 'STRING', first['source'])])).result())[0].n
            if n: print(f'{table} {first["source"]}: run {key} already loaded ({n} rows), skipped'); continue
        cfg = bigquery.LoadJobConfig(source_format='NEWLINE_DELIMITED_JSON', write_disposition='WRITE_APPEND',
                                     schema=[bigquery.SchemaField(c.split(':')[0], c.split(':')[1]) for c in schemas[table].split(',')])
        with open(path, 'rb') as f: client.load_table_from_file(f, f'{project}.ectwin_commons.{table}', job_config=cfg).result()
        print('loaded', f'ectwin_commons.{table}', '' if table != 'area_exceedance' else first['source'])


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-download', action='store_true')
    ap.add_argument('--bq', metavar='PROJECT')
    ap.add_argument('--sources', default='ecmwf_aifs_ens,noaa_gefs', help='extra ensembles to verify (comma list, empty for none)')
    ap.add_argument('--crop', action='store_true', help='keep only the Ecuador window of each GRIB step (Cloud Run Job)')
    a = ap.parse_args()
    if not a.skip_download: download_ens(crop=a.crop)
    init, lat, lon, steps, tp = read_ens()
    areas, used = area_rain(lat, lon, steps, tp)
    grid = grid_rain(lat, lon, steps, tp, used)
    key = flood_api_key(a.bq)
    try: flood = floodhub(key) if key else None
    except BaseException as e:                         # Flood Hub is an extra layer: never lose the day's run for it
        print('Flood Hub skipped:', e); flood = None
    gauges = rivers()
    write_outputs(init, areas, gauges, grid, flood)
    for f in OUT.glob('area_exceedance_*.ndjson'): f.unlink()
    extra_sources(init, [x for x in a.sources.split(',') if x])
    if a.bq: bq_load(a.bq, init)
