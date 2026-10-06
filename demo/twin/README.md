# GDE-Niño twin demo

Interactive demo of the *Gemelo Digital Ecuador – El Niño*: a single HTML page that colours Ecuador by *nivel de riesgo* and lets users drill down **provincia → cantón → parroquia** (INEC 2024: 24 provinces, 221 cantons, 1,042 parishes). It has two data modes:

| Mode | Rain | Rivers | Use |
|---|---|---|---|
| **Pronóstico real** | ECMWF IFS ENS open data, 50 members, 15 days, area-weighted per province, canton and parish | GEOGloWS v2, 52 members, 9 demo gauges; 2/5/20-year floods from a Gumbel fit of the 1940–2025 daily simulation | Live demo with today's forecast (experimental, not official) |
| **Escenario El Niño** | Deterministic simulation (rain band drifting north along the coast + Andean storm cluster) | Simulated response | "What if" storytelling |

Views: **Riesgo** (map + gauges), **Vías · MIT** (state road network, coloured where a section crosses a level 3–4 parish), **ECU 911** (estimated call load) and a shortcut to the **Guayaquil** pilot. Deep links open an area directly: `#EC09` (province), `#EC0901` (canton), `#EC090150` (parish); prefix `mit-` for the roads view, e.g. `#mit-EC0901`. Vulnerability, population per area and ECU 911 calls are demo estimates in both modes, and the page says so.

Probability is counted, not guessed: for each area and day, `P(rain > threshold) = members above threshold / 50`. Risk score = `P × (0.45 + 0.55 × vulnerability)`, levels 1–4 at 0.15 / 0.35 / 0.60; a province takes the level of its worst canton. ECMWF cells are 0.25° (~28 km), so parish values are interpolated averages and miss local storms; the page states this.

## Layout

| Path | What it is |
|---|---|
| `twin.template.html` | The page (d3 + topojson from cdnjs); data placeholders are filled by `build_page.py` |
| `build_page.py` | Injects boundaries, names, MIT roads (if present) and the latest forecast; writes `gemelo-ecuador.html`, `preview.html`, `deploy/index.html` |
| `pipeline/pipeline.py` | ECMWF ENS + GEOGloWS → `pipeline/out/forecast.json` and NDJSON; `--bq <project>` loads `ectwin_commons.area_exceedance` and `ectwin_commons.river_forecast` |
| `data/prep_geo.sh` | Downloads INEC 2024 boundaries (OCHA COD-AB, CC BY-IGO), derives simplified GeoJSON/TopoJSON and, if `data/mit/` exists, the MIT road network |
| `data/annotate_roads.py` | Tags each road section with the parish/canton/province at its midpoint |
| `data/web/ecuador.topo.json` | Committed web boundaries (parishes; cantons and provinces are merged in the browser) |
| `deploy/` | nginx container for Cloud Run |
| `refresh.sh` | One command: pipeline → BigQuery → page → Cloud Run |

## MIT data (not in this repo)

The *Red Vial Estatal* shapefile (MIT, August 2026, 795 sections, 10,056 km) was shared with the programme for the demo and is **not authorised for redistribution**, so it is git-ignored. To use it, place the extracted shapefile in `data/mit/` (`Red_Vial_Estatal_Agosto.*`) and run `data/prep_geo.sh`. Only these fields are kept: section id, road code, section name, province, class, condition, surface, lanes, length (no editor names). Without it the page builds without the roads view data.

## Run

```bash
cd demo/twin
python3 -m venv pipeline/.venv && pipeline/.venv/bin/pip install -r pipeline/requirements.txt
data/prep_geo.sh                                   # once (~740 MB INEC download); needs Node for mapshaper
GCP_PROJECT_ID=<project> ./refresh.sh              # ~15 min: 675 MB ECMWF download, BigQuery load, Cloud Run deploy
```

Without GCP, run `pipeline/.venv/bin/python pipeline/pipeline.py` and `python3 build_page.py`, then open `preview.html` through any static server.

## Licences and notice

ECMWF Open Data and GEOGloWS: CC BY 4.0. INEC boundaries via OCHA COD-AB: CC BY-IGO. The page carries a draft legal notice (see [`docs/legal/aviso-legal-borrador.md`](../../docs/legal/aviso-legal-borrador.md)); it is pending legal review. This demo was built and is maintained with AI assistance (Claude Code) under human supervision.
