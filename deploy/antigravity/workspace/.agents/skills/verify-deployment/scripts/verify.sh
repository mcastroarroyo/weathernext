#!/usr/bin/env bash
# Read-only checks of a GDE-Niño deployment.   verify.sh --project <id> [--region us-central1] [--service gde-nino]
set -uo pipefail
PROJECT="" REGION="us-central1" SERVICE="gde-nino"
while [ $# -gt 0 ]; do case "$1" in --project) PROJECT="$2"; shift 2;; --region) REGION="$2"; shift 2;; --service) SERVICE="$2"; shift 2;; *) shift;; esac; done
[ -n "$PROJECT" ] || { echo "--project is required" >&2; exit 2; }
ok() { echo "PASS  $*"; } ; ko() { echo "FAIL  $*"; FAILED=1; }
FAILED=0

URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" --format='value(status.url)' 2>/dev/null)"
[ -n "$URL" ] && ok "Cloud Run service $SERVICE: $URL" || ko "Cloud Run service $SERVICE not found in $REGION"
if [ -n "$URL" ]; then
  PUBLIC="$(gcloud run services get-iam-policy "$SERVICE" --region "$REGION" --project "$PROJECT" --format=json 2>/dev/null | grep -c allUsers)"
  [ "$PUBLIC" -gt 0 ] && echo "INFO  service is PUBLIC" || echo "INFO  service is private"
  if [ "$PUBLIC" -gt 0 ]; then CODE="$(curl -s -o /tmp/gde-verify.html -w '%{http_code}' "$URL")"
  else CODE="$(curl -s -o /tmp/gde-verify.html -w '%{http_code}' -H "Authorization: Bearer $(gcloud auth print-identity-token 2>/dev/null)" "$URL")"; fi
  [ "$CODE" = 200 ] && ok "page responds (HTTP 200)" || ko "page returned HTTP $CODE"
  grep -q 'Aviso legal' /tmp/gde-verify.html 2>/dev/null && ok "legal notice present" || ko "legal notice not found in page"
  grep -q '"init":' /tmp/gde-verify.html 2>/dev/null && ok "real forecast embedded" || echo "INFO  no real forecast embedded (scenario mode only)"
  rm -f /tmp/gde-verify.html
fi
for t in area_exceedance river_forecast; do
  N="$(bq --project_id="$PROJECT" query --use_legacy_sql=false --format=csv "SELECT COUNT(*) FROM ectwin_commons.$t" 2>/dev/null | tail -1)"
  [ -n "$N" ] && [ "$N" -gt 0 ] 2>/dev/null && ok "BigQuery ectwin_commons.$t: $N rows" || echo "INFO  ectwin_commons.$t empty or missing (expected without --with-forecast)"
done
exit $FAILED
