---
name: refresh-forecast
description: Refresh a deployed GDE-Niño twin with the latest ECMWF ensemble and GEOGloWS river forecast, reload BigQuery and redeploy the page. Use when the user asks to update, refresh or re-run the forecast or pipeline.
---

# Refresh the forecast

1. Confirm the project ID, region and service name of the existing deployment (`gcloud run services list --project <PROJECT_ID>`).
2. Run from the repository root:

```bash
GCP_PROJECT_ID=<PROJECT_ID> REGION=<REGION> SERVICE=<SERVICE> demo/twin/refresh.sh
```

   This downloads the newest ECMWF 00/12 UTC run (~675 MB, ~10 min), computes probabilities per province, canton and parish, appends rows to `ectwin_commons.area_exceedance` and `ectwin_commons.river_forecast`, rebuilds the page and redeploys it. Note that `refresh.sh` keeps the service's existing access setting.
3. Report the ECMWF run time (printed as `ECMWF ENS run …`) and the five areas with the highest probability, quoting them as experimental, not official.

If the ECMWF download fails, the previous forecast stays online; report the error instead of retrying in a loop. ECMWF publishes runs about 7–9 hours after 00 and 12 UTC.
