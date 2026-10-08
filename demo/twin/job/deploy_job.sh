#!/usr/bin/env bash
# Build and schedule the daily run as a Cloud Run Job, and point the web service at the published files.
# Usage: GCP_PROJECT_ID=<project> job/deploy_job.sh      (REGION, SERVICE, JOB, SCHEDULE, RUNNER, BUCKET can be overridden)
# Cost: one ~15 min execution a day at 1 vCPU / 2 GiB fits in Cloud Run's free tier; Cloud Scheduler ~US$0.10/month.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GCP_PROJECT_ID:?set GCP_PROJECT_ID}"; P="$GCP_PROJECT_ID"
REGION="${REGION:-us-central1}"; SERVICE="${SERVICE:-gde-nino-demo}"; JOB="${JOB:-gde-nino-daily}"
SCHEDULE="${SCHEDULE:-30 10 * * *}"                     # 10:30 UTC = 05:30 Ecuador, after the 00Z ECMWF ENS run is complete
RUNNER="${RUNNER:-ectwin-runner@$P.iam.gserviceaccount.com}"; BUCKET="${BUCKET:-$P-ectwin-curated}"
[ -f data/geo/parroquias.json ] || data/prep_geo.sh

# build context: only what the job needs (boundaries and page templates; MIT roads stay in the private image)
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/pipeline" "$STAGE/data/geo" "$STAGE/data/web" "$STAGE/deploy"
cp job/Dockerfile daily.py build_page.py export_gis.py twin.template.html verif.template.html "$STAGE/"
cp pipeline/pipeline.py pipeline/verify.py pipeline/requirements.txt "$STAGE/pipeline/"
cp data/geo/provincias.json data/geo/cantones.json data/geo/parroquias.json "$STAGE/data/geo/"
cp data/web/*.json "$STAGE/data/web/"

gcloud secrets add-iam-policy-binding floodforecasting-api-key --project "$P" --member "serviceAccount:$RUNNER" --role roles/secretmanager.secretAccessor --quiet >/dev/null
gcloud run jobs deploy "$JOB" --source "$STAGE" --project "$P" --region "$REGION" --service-account "$RUNNER" \
  --cpu 1 --memory 2Gi --task-timeout 3600 --max-retries 1 --labels app=ectwin \
  --set-env-vars "GCP_PROJECT_ID=$P,TWIN_BUCKET=$BUCKET" --set-secrets FLOOD_API_KEY=floodforecasting-api-key:latest --quiet
gcloud run jobs add-iam-policy-binding "$JOB" --project "$P" --region "$REGION" --member "serviceAccount:$RUNNER" --role roles/run.invoker --quiet >/dev/null

URI="https://run.googleapis.com/v2/projects/$P/locations/$REGION/jobs/$JOB:run"
if gcloud scheduler jobs describe "$JOB" --project "$P" --location "$REGION" >/dev/null 2>&1; then verb=update; else verb=create; fi
gcloud scheduler jobs "$verb" http "$JOB" --project "$P" --location "$REGION" --schedule "$SCHEDULE" --time-zone UTC \
  --uri "$URI" --http-method POST --oauth-service-account-email "$RUNNER" --attempt-deadline 60s --quiet

# web service: read pages and data from the bucket (no daily redeploys)
gcloud run services update "$SERVICE" --project "$P" --region "$REGION" --update-env-vars "TWIN_BUCKET=$BUCKET" --quiet >/dev/null
echo "job $JOB scheduled ($SCHEDULE UTC). Run now: gcloud run jobs execute $JOB --project $P --region $REGION"
