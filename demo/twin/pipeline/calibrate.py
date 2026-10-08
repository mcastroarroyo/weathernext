"""Shadow calibration of area rain forecasts, learned only from days already observed.

For each region (Costa, Sierra, Amazonía, Galápagos) and lead bucket (d1–2, d3–5, d6–10, d11–15):
  amount       multiplicative bias factor on the forecast median, shrunk towards 1 when there are few pairs
  probability  Platt scaling per threshold, P' = sigmoid(a + b·logit P), regularised towards no change (a=0, b=1)
Groups with too little evidence fall back to the lead bucket over all regions, then to no change.
Results are shown on the verification page next to the raw forecast; the twin keeps the raw forecast until approved.
"""
import numpy as np

THRS = (20, 30, 50)
REGION = {**{p: 'costa' for p in ('07', '08', '09', '12', '13', '23', '24')},
          **{p: 'amazonia' for p in ('14', '15', '16', '19', '21', '22')}, '20': 'galapagos'}
MIN_PAIRS, MIN_EVENTS, PRIOR = 300, 15, 20.0     # evidence needed per group; strength of the pull towards "no change"


def region(code): return REGION.get(code[2:4], 'sierra')
def bucket(lead): return 'd1-2' if lead <= 2 else 'd3-5' if lead <= 5 else 'd6-10' if lead <= 10 else 'd11-15'


def platt(p, y):
    x = np.log(np.clip(p, .01, .99) / (1 - np.clip(p, .01, .99))); a, b = 0.0, 1.0
    for _ in range(30):                                 # Newton steps on log-loss + PRIOR·((a)² + (b−1)²)
        q = 1 / (1 + np.exp(-(a + b * x))); w = q * (1 - q)
        g = np.array([np.sum(q - y) + 2 * PRIOR * a, np.sum((q - y) * x) + 2 * PRIOR * (b - 1)])
        H = np.array([[w.sum() + 2 * PRIOR, (w * x).sum()], [(w * x).sum(), (w * x * x).sum() + 2 * PRIOR]])
        step = np.linalg.solve(H, g); a, b = a - step[0], b - step[1]
        if np.abs(step).max() < 1e-6: break
    return round(float(a), 4), round(float(b), 4)


def fit(pairs):
    """pairs: dicts with code, lead, obs, med, p20, p30, p50. Returns a model: {group: {n, factor, platt: {thr: (a, b)}}}."""
    model = {}
    if not pairs: return model
    groups = {}
    for r in pairs:
        groups.setdefault((region(r['code']), bucket(r['lead'])), []).append(r)
        groups.setdefault(('*', bucket(r['lead'])), []).append(r)
    for key, rows in groups.items():
        obs = np.array([r['obs'] for r in rows]); med = np.array([r['med'] for r in rows]); n = len(rows)
        if n < MIN_PAIRS: continue
        ratio = obs.sum() / med.sum() if med.sum() > 0 else 1.0
        g = {'n': n, 'factor': round(float(np.clip(1 + n / (n + 1000) * (ratio - 1), .3, 2)), 3), 'platt': {}}
        for t in THRS:
            y = (obs > t).astype(float)
            if y.sum() >= MIN_EVENTS: g['platt'][str(t)] = platt(np.array([r[f'p{t}'] for r in rows]), y)
        model['|'.join(key)] = g
    return model


def apply(model, r):
    """Calibrated copy of one area record: cmed and cp20/cp30/cp50 (unchanged where there is no evidence yet)."""
    b = bucket(r['lead']); g = model.get(f"{region(r['code'])}|{b}") or {}; g0 = model.get(f'*|{b}') or {}
    out = {'cmed': round(r['med'] * (g.get('factor') or g0.get('factor') or 1), 1)}
    for t in THRS:
        ab = g.get('platt', {}).get(str(t)) or g0.get('platt', {}).get(str(t))
        if ab:
            p = min(max(r[f'p{t}'], .01), .99); out[f'cp{t}'] = round(float(1 / (1 + np.exp(-(ab[0] + ab[1] * np.log(p / (1 - p)))))), 3)
        else:
            out[f'cp{t}'] = r[f'p{t}']
    return out
