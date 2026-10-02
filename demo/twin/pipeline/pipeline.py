"""GDE-Niño backup-source pipeline.

ECMWF IFS ENS open data (50 perturbed members, CC BY 4.0) -> daily rain per province, canton and parish (INEC 2024) -> exceedance probabilities.
GEOGloWS v2 (52 members, CC BY 4.0) -> daily river flow at demo gauges -> P(Q >= 2/5/20-year flood).
Writes out/forecast.json (for the demo) and NDJSON rows, and optionally loads them into BigQuery.

Usage: .venv/bin/python pipeline.py [--skip-download] [--bq PROJECT]
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
def download_ens():
    DATA.mkdir(exist_ok=True)
    c = Client(source='google', model='ifs')
    steps = list(range(0, 24 * DAYS + 1, 24))
    run = c.latest(type='pf', stream='enfo', param='tp', step=24 * DAYS)   # latest 00/12Z run that reaches 360 h
    print('ECMWF ENS run', run)
    c.retrieve(date=run, type='pf', stream='enfo', param='tp', step=steps, number=list(range(1, 51)), target=str(DATA / 'ens_pf.grib2'))
    return run


def read_ens():
    """Return init datetime, lat, lon and tp[member, step_index, lat, lon] (metres) cut to Ecuador."""
    fields, init = {}, None
    for name in ('ens_pf.grib2',):
        with open(DATA / name, 'rb') as f:
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
                    fields[(num, step)] = v[np.ix_(rows, cols)]
                finally:
                    eccodes.codes_release(gid)
    members = sorted({k[0] for k in fields}); steps = sorted({k[1] for k in fields})
    tp = np.stack([np.stack([fields[(m, s)] for s in steps]) for m in members])
    lat, lon = lats[rows], lons[cols]
    # longitudes may not be monotonic after wrapping: sort them
    order = np.argsort(lon); tp, lon = tp[..., order], lon[order]
    print(f'ENS: {len(members)} members, steps {steps[0]}–{steps[-1]} h, grid {len(lat)}×{len(lon)}, init {init:%Y-%m-%d %HZ}')
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
    out = {}
    for level, fname in LEVELS:
        gj = json.load(open(GEO / fname)); rows = []
        for f in gj['features']:
            w, n = area_weights(f['geometry'], lat, lon)
            series = daily @ w                                   # area-weighted rain per member and day
            pr = f['properties']
            rows.append({'code': pr['code'], 'name': pr['name'], 'parent': pr.get('canton') or pr.get('prov'), 'samples': n,
                         'p': {str(t): np.round((series > t).mean(axis=0), 2).tolist() for t in THRESHOLDS},
                         'med': np.round(np.median(series, axis=0), 1).tolist(),
                         'p90': np.round(np.percentile(series, 90, axis=0), 1).tolist()})
        out[level] = rows
        print(f'{level}: {len(rows)} areas')
    return out


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
def write_outputs(init, areas, gauges):
    OUT.mkdir(exist_ok=True)
    doc = {'generated': dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'), 'init': init.isoformat(),
           'source_rain': 'ECMWF IFS ENS open data, 50 members, 0.25° (CC BY 4.0); area-weighted bilinear average',
           'source_rivers': 'GEOGloWS v2, 52 members; return periods: Gumbel on 1940–2025 daily simulation (CC BY 4.0)',
           'source_areas': 'INEC 2024 DPA boundaries via OCHA COD-AB (CC BY-IGO)',
           'thresholds': THRESHOLDS, 'days': DAYS, 'areas': areas, 'gauges': gauges}
    (OUT / 'forecast.json').write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    with open(OUT / 'area_exceedance.ndjson', 'w') as f:
        for level, rows in areas.items():
            for c in rows:
                for d in range(DAYS):
                    for t in THRESHOLDS:
                        f.write(json.dumps({'init_time': init.isoformat(), 'source': 'ecmwf_ifs_ens', 'level': level, 'dpa_code': c['code'], 'name': c['name'],
                                            'parent_code': c['parent'], 'lead_day': d + 1, 'valid_date': (init + dt.timedelta(days=d)).date().isoformat(),
                                            'threshold_mm': t, 'probability': c['p'][str(t)][d], 'median_mm': c['med'][d], 'p90_mm': c['p90'][d]}, ensure_ascii=False) + '\n')
    with open(OUT / 'river_forecast.ndjson', 'w') as f:
        for g in gauges:
            for d in range(DAYS):
                f.write(json.dumps({'init_time': g['start'], 'source': 'geoglows_v2', 'river': g['name'], 'site': g['site'], 'river_id': g['river_id'],
                                    'lead_day': d + 1, 'q_median': g['med'][d], 'q_p10': g['lo'][d], 'q_p90': g['hi'][d],
                                    'rp2': g['rp']['2'], 'rp5': g['rp']['5'], 'rp20': g['rp']['20'],
                                    'p_rp2': g['p']['2'][d], 'p_rp5': g['p']['5'][d], 'p_rp20': g['p']['20'][d]}, ensure_ascii=False) + '\n')
    print('wrote', OUT / 'forecast.json')


def bq_load(project):
    schemas = {
        'area_exceedance': 'init_time:TIMESTAMP,source:STRING,level:STRING,dpa_code:STRING,name:STRING,parent_code:STRING,lead_day:INTEGER,valid_date:DATE,threshold_mm:INTEGER,probability:FLOAT,median_mm:FLOAT,p90_mm:FLOAT',
        'river_forecast': 'init_time:TIMESTAMP,source:STRING,river:STRING,site:STRING,river_id:INTEGER,lead_day:INTEGER,q_median:FLOAT,q_p10:FLOAT,q_p90:FLOAT,rp2:FLOAT,rp5:FLOAT,rp20:FLOAT,p_rp2:FLOAT,p_rp5:FLOAT,p_rp20:FLOAT'}
    for table, schema in schemas.items():
        subprocess.run(['bq', f'--project_id={project}', 'load', '--source_format=NEWLINE_DELIMITED_JSON',
                        f'ectwin_commons.{table}', str(OUT / f'{table}.ndjson'), schema], check=True)
        print('loaded', f'{project}:ectwin_commons.{table}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-download', action='store_true')
    ap.add_argument('--bq', metavar='PROJECT')
    a = ap.parse_args()
    if not a.skip_download: download_ens()
    init, lat, lon, steps, tp = read_ens()
    areas = area_rain(lat, lon, steps, tp)
    gauges = rivers()
    write_outputs(init, areas, gauges)
    if a.bq: bq_load(a.bq)
