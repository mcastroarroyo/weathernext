#!/usr/bin/env bash
# Deploy the GDE-Niño twin into the user's own Google Cloud project.
#
#   deploy.sh --project <id> [--region us-central1] [--service gde-nino] [--public] [--with-forecast] [--dry-run]
#
# Steps: preflight checks -> enable APIs -> BigQuery dataset -> (optional) forecast pipeline -> build page -> Cloud Run.
# The service is private by default (Cloud Run IAM); --public allows unauthenticated access.
set -euo pipefail

PROJECT="" REGION="us-central1" SERVICE="gde-nino" PUBLIC=0 FORECAST=0 DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --public) PUBLIC=1; shift ;;
    --with-forecast) FORECAST=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$PROJECT" ] || { echo "--project is required" >&2; exit 2; }

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
TWIN="$ROOT/demo/twin"
run() { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }
step() { printf '\n== %s\n' "$*"; }

step "Preflight"
command -v gcloud >/dev/null || { echo "gcloud CLI not found: https://cloud.google.com/sdk/docs/install" >&2; exit 1; }
command -v bq >/dev/null || { echo "bq CLI not found (part of the gcloud SDK)" >&2; exit 1; }
ACCOUNT="$(gcloud config get-value account 2>/dev/null)"
[ -n "$ACCOUNT" ] || { echo "Not signed in: run 'gcloud auth login'" >&2; exit 1; }
echo "account: $ACCOUNT"
gcloud projects describe "$PROJECT" --format='value(projectId)' >/dev/null || { echo "Project $PROJECT not found or no access" >&2; exit 1; }
BILLING="$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)' 2>/dev/null || echo unknown)"
echo "billing enabled: $BILLING"
[ "$BILLING" = "True" ] || [ "$BILLING" = "true" ] || echo "WARNING: billing is not confirmed as enabled; Cloud Build and Cloud Run need it."
ROLES="$(gcloud projects get-iam-policy "$PROJECT" --flatten='bindings[].members' --filter="bindings.members:user:$ACCOUNT" --format='value(bindings.role)' 2>/dev/null | tr '\n' ' ')"
echo "your roles: ${ROLES:-none found (may be inherited from folder/org)}"

step "Enable APIs"
run gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com bigquery.googleapis.com --project "$PROJECT"

step "BigQuery dataset ectwin_commons"
if bq --project_id="$PROJECT" show --format=none ectwin_commons 2>/dev/null; then echo "exists"
else run bq --project_id="$PROJECT" --location=US mk --dataset --label=app:ectwin --description="GDE-Niño shared products" "$PROJECT:ectwin_commons"; fi

if [ "$FORECAST" = 1 ]; then
  step "Forecast pipeline (ECMWF ENS + GEOGloWS, ~675 MB download)"
  [ -d "$TWIN/pipeline/.venv" ] || run python3 -m venv "$TWIN/pipeline/.venv"
  run "$TWIN/pipeline/.venv/bin/pip" install -q -r "$TWIN/pipeline/requirements.txt"
  [ -f "$TWIN/data/geo/parroquias.json" ] || run "$TWIN/data/prep_geo.sh"
  run "$TWIN/pipeline/.venv/bin/python" "$TWIN/pipeline/pipeline.py" --bq "$PROJECT"
else
  [ -f "$TWIN/data/geo/parroquias.json" ] || { step "Boundaries (INEC 2024, ~740 MB download, once)"; run "$TWIN/data/prep_geo.sh"; }
fi

step "Build page"
run python3 "$TWIN/build_page.py"

step "Deploy Cloud Run service $SERVICE ($REGION)"
ACCESS="--no-allow-unauthenticated"; [ "$PUBLIC" = 1 ] && ACCESS="--allow-unauthenticated"
run gcloud run deploy "$SERVICE" --source "$TWIN/deploy" --region "$REGION" --project "$PROJECT" \
  --labels app=ectwin,env=tenant --memory 256Mi --max-instances 3 "$ACCESS" --quiet

if [ "$DRY" = 0 ]; then
  URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" --format='value(status.url)')"
  echo; echo "Deployed: $URL"
  [ "$PUBLIC" = 1 ] || echo "Private service: open it with 'gcloud run services proxy $SERVICE --region $REGION --project $PROJECT' or grant roles/run.invoker to your users."
fi
