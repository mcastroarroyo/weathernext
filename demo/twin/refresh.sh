#!/usr/bin/env bash
# Refresh the twin with the latest ECMWF ENS + GEOGloWS forecast: pipeline -> BigQuery -> page -> Cloud Run.
# Usage: GCP_PROJECT_ID=<project> ./refresh.sh   (region and service can be overridden with REGION / SERVICE)
set -euo pipefail
cd "$(dirname "$0")"
: "${GCP_PROJECT_ID:?set GCP_PROJECT_ID to the Google Cloud project}"
REGION="${REGION:-us-central1}"; SERVICE="${SERVICE:-gde-nino-demo}"
[ -d pipeline/.venv ] || { python3 -m venv pipeline/.venv && pipeline/.venv/bin/pip install -q -r pipeline/requirements.txt; }
[ -f data/geo/parroquias.json ] || data/prep_geo.sh   # boundaries used by the pipeline and the page
pipeline/.venv/bin/python pipeline/pipeline.py --bq "$GCP_PROJECT_ID"
python3 build_page.py
gcloud run deploy "$SERVICE" --source deploy --region "$REGION" --project "$GCP_PROJECT_ID" --quiet
