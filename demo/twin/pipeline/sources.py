"""Extra rain ensembles, verified alongside ECMWF IFS ENS (and, later, blended by demonstrated skill).

  aifs  ECMWF AIFS ENS open data (machine-learning ensemble, 50 members, 0.25°, CC BY 4.0) from the Google Cloud mirror
  gefs  NOAA GEFS (31 members, 0.5°, public domain) from the NOAA bucket on Google Cloud; only the rain field is read (byte ranges)

Each fetch(init, workdir) returns (init, lat, lon, steps, tp) like pipeline.read_ens(): tp[member, step, lat, lon] is rain
accumulated since init in metres, cut to Ecuador, at steps 0, 24, ..., 360 h. Both use the same init as the IFS run so the
three are verified on identical days.
"""
import datetime as dt, pathlib, socket, time
from concurrent.futures import ThreadPoolExecutor
import numpy as np, requests, eccodes
from pipeline import LAT_N, LAT_S, LON_W, LON_E, DAYS

STEPS = list(range(0, 24 * DAYS + 1, 24))


def crop(gid):
    """Ecuador window of one GRIB message: (values, lat, lon) with longitudes in −180..180."""
    ni, nj = eccodes.codes_get(gid, 'Ni'), eccodes.codes_get(gid, 'Nj')
    lat0, lon0 = eccodes.codes_get(gid, 'latitudeOfFirstGridPointInDegrees'), eccodes.codes_get(gid, 'longitudeOfFirstGridPointInDegrees')
    dlat, dlon = eccodes.codes_get(gid, 'jDirectionIncrementInDegrees'), eccodes.codes_get(gid, 'iDirectionIncrementInDegrees')
    v = eccodes.codes_get_values(gid).reshape(nj, ni)
    lats = lat0 - np.arange(nj) * dlat
    lons = (lon0 + np.arange(ni) * dlon + 180) % 360 - 180
    rows = np.where((lats <= LAT_N) & (lats >= LAT_S))[0]; cols = np.where((lons >= LON_W) & (lons <= LON_E))[0]
    return v[np.ix_(rows, cols)].astype('float32'), lats[rows], lons[cols]


def finish(init, lat, lon, tp):
    order = np.argsort(lon)
    return init, lat, lon[order], STEPS, tp[..., order]


# ---------------- ECMWF AIFS ENS ----------------
def aifs(init, workdir, retries=4):
    from ecmwf.opendata import Client
    socket.setdefaulttimeout(90)
    workdir.mkdir(parents=True, exist_ok=True)
    c = Client(source='google', model='aifs-ens')
    fields, lat, lon = {}, None, None
    for step in STEPS[1:]:
        target = workdir / f'aifs_{step:03d}.grib2'
        for attempt in range(1, retries + 1):
            try:
                c.retrieve(date=init.replace(tzinfo=None), type='pf', stream='enfo', param='tp', step=step, number=list(range(1, 51)), target=str(target)); break
            except Exception as e:
                print(f'AIFS step {step}: attempt {attempt} failed ({type(e).__name__})'); time.sleep(5 * attempt)
        else:
            raise RuntimeError(f'AIFS step {step} unavailable')
        with open(target, 'rb') as f:
            while (gid := eccodes.codes_grib_new_from_file(f)) is not None:
                try:
                    v, lat, lon = crop(gid); fields[(eccodes.codes_get(gid, 'number'), step)] = v
                    units = eccodes.codes_get(gid, 'units')
                finally:
                    eccodes.codes_release(gid)
        target.unlink()
    members = sorted({m for m, _ in fields})
    tp = np.stack([np.stack([np.zeros_like(fields[(m, 24)])] + [fields[(m, s)] for s in STEPS[1:]]) for m in members])
    if units in ('kg m**-2', 'kg m-2', 'mm'): tp = tp / 1000            # AIFS may publish mm; the pipeline works in metres
    print(f'AIFS ENS: {len(members)} members, grid {len(lat)}×{len(lon)}, units {units}')
    return finish(init, lat, lon, tp)


# ---------------- NOAA GEFS ----------------
GEFS = 'https://storage.googleapis.com/gfs-ensemble-forecast-system/gefs.{d:%Y%m%d}/{d:%H}/atmos/pgrb2ap5/{m}.t{d:%H}z.pgrb2a.0p50.f{h:03d}'
GEFS_MEMBERS = ['gec00'] + [f'gep{i:02d}' for i in range(1, 31)]


def gefs_field(url, session):
    """Only the 6-hour rain bucket (APCP) of one GEFS file, located through its .idx and read with an HTTP byte range."""
    for attempt in range(4):
        try:
            idx = session.get(url + '.idx', timeout=60); idx.raise_for_status()
            lines = idx.text.strip().splitlines()
            k = next(i for i, l in enumerate(lines) if ':APCP:surface:' in l)
            start = int(lines[k].split(':')[1]); end = int(lines[k + 1].split(':')[1]) - 1 if k + 1 < len(lines) else ''
            r = session.get(url, headers={'Range': f'bytes={start}-{end}'}, timeout=60); r.raise_for_status()
            gid = eccodes.codes_new_from_message(r.content)
            try: return crop(gid)
            finally: eccodes.codes_release(gid)
        except Exception:
            if attempt == 3: raise
            time.sleep(3 * (attempt + 1))


def gefs(init, workdir=None):
    s = requests.Session()
    s.mount('https://', requests.adapters.HTTPAdapter(pool_maxsize=16))
    hours = list(range(6, 24 * DAYS + 1, 6))
    jobs = [(m, h) for m in GEFS_MEMBERS for h in hours]
    with ThreadPoolExecutor(16) as ex:
        out = dict(zip(jobs, ex.map(lambda j: gefs_field(GEFS.format(d=init, m=j[0], h=j[1]), s), jobs)))
    lat, lon = out[jobs[0]][1], out[jobs[0]][2]
    # 6-hour buckets in mm -> accumulation since init in metres at 0, 24, ..., 360 h
    buckets = np.stack([np.stack([out[(m, h)][0] for h in hours]) for m in GEFS_MEMBERS])        # [member, bucket, lat, lon]
    acc = np.concatenate([np.zeros_like(buckets[:, :1]), np.cumsum(buckets, axis=1)], axis=1) / 1000
    tp = acc[:, [h // 6 for h in STEPS]]
    print(f'GEFS: {len(GEFS_MEMBERS)} members, {len(jobs)} rain fields, grid {len(lat)}×{len(lon)}')
    return finish(init, lat, lon, tp)


SOURCES = {'ecmwf_aifs_ens': aifs, 'noaa_gefs': gefs}
