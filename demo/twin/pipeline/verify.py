"""Verify stored ECMWF ENS area forecasts against CHIRPS v3 preliminary daily rain.

  .venv/bin/python verify.py --project <PROJECT> [--init 2026-10-01T12:00] [--bq]

Forecast windows run 12Z->12Z from the 12Z run; CHIRPS days are UTC calendar days, so the observed window
for lead d is approximated as 0.5 * CHIRPS(init day + d - 1) + 0.5 * CHIRPS(init day + d).
Scores per level (canton, parroquia) and threshold: Brier score and skill vs the sample base rate, reliability,
hits / misses / false alarms at P >= 0.5, and bias / MAE / correlation of the forecast median vs observed rain.
"""
import argparse, datetime as dt, json, pathlib, subprocess
import numpy as np, rasterio
from rasterio.windows import from_bounds
from pipeline import inside, GEO, OUT, LAT_N, LAT_S, LON_W, LON_E

CHIRPS = 'https://data.chc.ucsb.edu/products/CHIRPS/v3.0/daily/prelim/sat/{y}/chirps-v3.0.prelim.{y}.{m:02d}.{d:02d}.tif'
CACHE = pathlib.Path(__file__).parent / 'data' / 'chirps'
THRS = [20, 30, 50]
BINS = [0, .1, .3, .5, .7, 1.0001]


def chirps_day(day):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / f'{day:%Y%m%d}.npy'
    if f.exists(): return np.load(f)
    with rasterio.open('/vsicurl/' + CHIRPS.format(y=day.year, m=day.month, d=day.day)) as r:
        w = from_bounds(LON_W, LAT_S, LON_E, LAT_N, r.transform)
        a = r.read(1, window=w).astype('float32'); a[a < 0] = np.nan
        tr = r.window_transform(w)
    np.save(f, a); np.save(CACHE / 'transform.npy', np.array(tr)[:6])
    return a


def area_masks(level_file, shape):
    tr = np.load(CACHE / 'transform.npy')            # a, b, c, d, e, f of the Ecuador window
    lon = tr[2] + (np.arange(shape[1]) + .5) * tr[0]; lat = tr[5] + (np.arange(shape[0]) + .5) * tr[4]
    gx, gy = np.meshgrid(lon, lat); out = {}
    for f in json.load(open(GEO / level_file))['features']:
        g = f['geometry']; pts = np.concatenate([np.asarray(r) for poly in ([g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']) for r in poly[:1]])
        (x0, y0), (x1, y1) = pts.min(0), pts.max(0)
        sel = (gx >= x0) & (gx <= x1) & (gy >= y0) & (gy <= y1)
        m = np.zeros(shape, bool); m[sel] = inside(gx[sel], gy[sel], g)
        if not m.any():                              # very small area: nearest CHIRPS cell to its centre
            m[np.abs(lat - (y0 + y1) / 2).argmin(), np.abs(lon - (x0 + x1) / 2).argmin()] = True
        out[f['properties']['code']] = m
    return out


def bq(project, sql):
    r = subprocess.run(['bq', f'--project_id={project}', 'query', '--use_legacy_sql=false', '--format=json', '--max_rows=1000000', sql], capture_output=True, text=True, check=True)
    return json.loads(r.stdout or '[]')


def scores(p, o_mm, med, thr):
    o = (o_mm > thr).astype(float); n = len(o); base = o.mean()
    bs = float(np.mean((p - o) ** 2)); bs_ref = float(base * (1 - base))
    rel = []
    for lo, hi in zip(BINS[:-1], BINS[1:]):
        k = (p >= lo) & (p < hi)
        if k.any(): rel.append({'bin': f'{lo:.1f}–{min(hi, 1):.1f}', 'n': int(k.sum()), 'p_mean': round(float(p[k].mean()), 3), 'obs_freq': round(float(o[k].mean()), 3)})
    yes = p >= .5
    hits, misses, fa = int((yes & (o == 1)).sum()), int((~yes & (o == 1)).sum()), int((yes & (o == 0)).sum())
    return {'threshold_mm': thr, 'n': n, 'observed_rate': round(float(base), 3), 'mean_forecast_p': round(float(p.mean()), 3),
            'brier': round(bs, 4), 'brier_ref': round(bs_ref, 4), 'bss': round(1 - bs / bs_ref, 3) if bs_ref > 0 else None,
            'hits': hits, 'misses': misses, 'false_alarms': fa,
            'pod': round(hits / (hits + misses), 3) if hits + misses else None, 'far': round(fa / (hits + fa), 3) if hits + fa else None,
            'reliability': rel}


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--project', required=True); ap.add_argument('--init'); ap.add_argument('--bq', action='store_true'); a = ap.parse_args()
    init = a.init or bq(a.project, 'SELECT FORMAT_TIMESTAMP("%FT%R", MIN(init_time)) AS t FROM ectwin_commons.area_exceedance')[0]['t']
    t0 = dt.datetime.fromisoformat(init)
    # observed days available
    days, d = [], t0.date()
    while True:
        try: chirps_day(d); days.append(d); d += dt.timedelta(days=1)
        except Exception: break
    leads = [L for L in range(1, 16) if t0.date() + dt.timedelta(days=L) in days]
    print(f'forecast {init}Z · CHIRPS days {days[0]}–{days[-1]} · verifiable leads {leads}')
    obs = {L: .5 * chirps_day(t0.date() + dt.timedelta(days=L - 1)) + .5 * chirps_day(t0.date() + dt.timedelta(days=L)) for L in leads}
    shape = next(iter(obs.values())).shape
    rows = bq(a.project, f'SELECT level, dpa_code, name, lead_day, threshold_mm, probability, median_mm FROM ectwin_commons.area_exceedance '
                         f'WHERE init_time = TIMESTAMP("{init}:00+00") AND level IN ("canton","parroquia") AND lead_day <= {max(leads)} AND threshold_mm IN (20,30,50)')
    fc = {}
    for r in rows: fc[(r['level'], r['dpa_code'], int(r['lead_day']), int(r['threshold_mm']))] = (float(r['probability']), float(r['median_mm']), r['name'])
    result = {'init': init, 'observed': 'CHIRPS v3 preliminary daily (0.05°), 12Z windows approximated from two UTC days', 'leads': leads, 'levels': {}}
    for level, gfile in (('canton', 'cantones.json'), ('parroquia', 'parroquias.json')):
        masks = area_masks(gfile, shape)
        P = {t: [] for t in THRS}; O, M, worst = [], [], []
        for code, m in masks.items():
            for L in leads:
                if (level, code, L, 20) not in fc: continue
                o = float(np.nanmean(obs[L][m])); med = fc[(level, code, L, 20)][1]; O.append(o); M.append(med)
                for t in THRS: P[t].append(fc[(level, code, L, t)][0])
                p50 = fc[(level, code, L, 50)][0]
                if o > 50 and p50 < .2: worst.append({'name': fc[(level, code, L, 20)][2], 'lead': L, 'obs_mm': round(o, 1), 'p_gt50': p50, 'median_mm': med})
        O, M = np.array(O), np.array(M)
        result['levels'][level] = {
            'n_forecasts': int(len(O)),
            'amount': {'obs_mean_mm': round(float(O.mean()), 2), 'fc_median_mean_mm': round(float(M.mean()), 2), 'bias_mm': round(float((M - O).mean()), 2),
                       'mae_mm': round(float(np.abs(M - O).mean()), 2), 'corr': round(float(np.corrcoef(M, O)[0, 1]), 3)},
            'by_threshold': [scores(np.array(P[t]), O, M, t) for t in THRS],
            'big_misses': sorted(worst, key=lambda w: -w['obs_mm'])[:10]}
    path = OUT / f'verification_{init[:10]}.json'; path.write_text(json.dumps(result, ensure_ascii=False, indent=1))
    print(json.dumps(result, ensure_ascii=False, indent=1)[:6000]); print('wrote', path)


if __name__ == '__main__':
    main()
