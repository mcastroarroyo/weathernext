#!/usr/bin/env bash
# One-time set-up of the GDE-Niño TEST environment in an existing Google Cloud project,
# so that GitHub Actions in this repository can deploy and run pipelines there
# with Workload Identity Federation (no service-account keys).
#
# Run it in Cloud Shell, signed in as a project Owner, with the test project selected:
#
#   git clone https://github.com/mcastroarroyo/weathernext.git && cd weathernext
#   git checkout claude/ecuador-digital-twin-el-nino-xts888
#   bash scripts/testing/bootstrap-ci-wif.sh                 # uses the Cloud Shell project
#   bash scripts/testing/bootstrap-ci-wif.sh --project <ID>  # or name it explicitly
#
# Options:
#   --project <ID>        GCP project (default: `gcloud config get-value project`)
#   --repo <owner/name>   GitHub repository allowed to deploy (default: mcastroarroyo/weathernext)
#   --dry-run             print the commands instead of running them
#
# It is idempotent: re-running it skips what already exists.
# It creates, in the test project only:
#   * APIs needed by the test environment
#   * service accounts ectwin-ci (used by GitHub Actions) and ectwin-runner (runs pipelines/jobs)
#   * a GCS bucket <PROJECT_ID>-ectwin-tfstate for Terraform state
#   * a Workload Identity pool "ectwin-github" with provider "github" that trusts ONLY tokens
#     issued by GitHub Actions for the repository given in --repo
# and prints the three values to store as GitHub Actions *secrets* (secrets are masked in
# logs; this repository is public).
set -euo pipefail

PROJECT_ID=""
REPO="mcastroarroyo/weathernext"
DRY_RUN=0
POOL="ectwin-github"
PROVIDER="github"
CI_SA_NAME="ectwin-ci"
RUNNER_SA_NAME="ectwin-runner"
LOCATION_GCS="us-central1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then echo "+ $*"; else "$@"; fi
}

command -v gcloud >/dev/null || { echo "gcloud not found (run this in Cloud Shell)" >&2; exit 1; }
[[ -n "$PROJECT_ID" ]] || PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
[[ -n "$PROJECT_ID" ]] || { echo "No project: pass --project <ID> or run 'gcloud config set project <ID>'" >&2; exit 2; }
[[ "$REPO" == */* ]] || { echo "--repo must be owner/name" >&2; exit 2; }

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
CI_SA="${CI_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
RUNNER_SA="${RUNNER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
TFSTATE_BUCKET="${PROJECT_ID}-ectwin-tfstate"

echo "== GDE-Niño test environment bootstrap"
echo "   project:  ${PROJECT_ID} (${PROJECT_NUMBER})"
echo "   repo:     ${REPO}"
echo

echo "== 1/6 Enabling APIs (this can take a minute)"
run gcloud services enable --project="$PROJECT_ID" \
  iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  cloudresourcemanager.googleapis.com serviceusage.googleapis.com \
  bigquery.googleapis.com bigquerystorage.googleapis.com storage.googleapis.com \
  run.googleapis.com cloudscheduler.googleapis.com artifactregistry.googleapis.com \
  secretmanager.googleapis.com logging.googleapis.com earthengine.googleapis.com

echo "== 2/6 Service accounts"
for NAME in "$CI_SA_NAME" "$RUNNER_SA_NAME"; do
  if gcloud iam service-accounts describe "${NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
       --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "   ${NAME}: exists"
  else
    run gcloud iam service-accounts create "$NAME" --project="$PROJECT_ID" \
      --display-name="GDE-Nino ${NAME#ectwin-} (test)"
  fi
done

echo "== 3/6 Project roles"
# ectwin-ci deploys the test environment (Terraform) and runs pipelines from GitHub Actions.
# Scoped to what infra/testing manages; no project-IAM or service-account-admin rights.
CI_ROLES=(
  roles/bigquery.admin              # datasets, tables, loads, queries (test datasets only)
  roles/storage.admin               # test buckets and Terraform state
  roles/run.admin                   # Cloud Run jobs (later phases)
  roles/cloudscheduler.admin        # schedules (later phases)
  roles/artifactregistry.admin      # container repository
  roles/secretmanager.admin         # secret containers (values are added by people, not CI)
  roles/serviceusage.serviceUsageConsumer
  roles/logging.logWriter
)
# ectwin-runner runs pipeline jobs inside the project.
RUNNER_ROLES=(
  roles/bigquery.jobUser
  roles/bigquery.dataEditor
  roles/storage.objectAdmin
  roles/serviceusage.serviceUsageConsumer
  roles/logging.logWriter
)
for R in "${CI_ROLES[@]}"; do
  run gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${CI_SA}" \
    --role="$R" --condition=None --quiet >/dev/null
  echo "   ${CI_SA_NAME}: ${R}"
done
for R in "${RUNNER_ROLES[@]}"; do
  run gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${RUNNER_SA}" \
    --role="$R" --condition=None --quiet >/dev/null
  echo "   ${RUNNER_SA_NAME}: ${R}"
done
# CI may deploy jobs that run as ectwin-runner (actAs on that one account only).
run gcloud iam service-accounts add-iam-policy-binding "$RUNNER_SA" --project="$PROJECT_ID" \
  --member="serviceAccount:${CI_SA}" --role=roles/iam.serviceAccountUser --quiet >/dev/null
echo "   ${CI_SA_NAME}: iam.serviceAccountUser on ${RUNNER_SA_NAME} only"

echo "== 4/6 Terraform state bucket"
if gcloud storage buckets describe "gs://${TFSTATE_BUCKET}" >/dev/null 2>&1; then
  echo "   gs://${TFSTATE_BUCKET}: exists"
else
  run gcloud storage buckets create "gs://${TFSTATE_BUCKET}" --project="$PROJECT_ID" \
    --location="$LOCATION_GCS" --uniform-bucket-level-access --public-access-prevention
  run gcloud storage buckets update "gs://${TFSTATE_BUCKET}" --versioning
fi

echo "== 5/6 Workload Identity Federation for GitHub Actions"
if gcloud iam workload-identity-pools describe "$POOL" --project="$PROJECT_ID" \
     --location=global >/dev/null 2>&1; then
  echo "   pool ${POOL}: exists"
else
  run gcloud iam workload-identity-pools create "$POOL" --project="$PROJECT_ID" \
    --location=global --display-name="GDE-Nino GitHub Actions"
fi
if gcloud iam workload-identity-pools providers describe "$PROVIDER" --project="$PROJECT_ID" \
     --location=global --workload-identity-pool="$POOL" >/dev/null 2>&1; then
  echo "   provider ${PROVIDER}: exists"
else
  if ! run gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
      --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL" \
      --display-name="GitHub ${REPO}" \
      --issuer-uri="https://token.actions.githubusercontent.com" \
      --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
      --attribute-condition="assertion.repository=='${REPO}'"; then
    echo "!! Could not create the OIDC provider. If an organisation policy restricts identity" >&2
    echo "!! providers (constraints/iam.workloadIdentityPoolProviders), ask the org admin to allow" >&2
    echo "!! https://token.actions.githubusercontent.com for this project, then re-run." >&2
    exit 3
  fi
fi
PRINCIPAL_SET="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}"
run gcloud iam service-accounts add-iam-policy-binding "$CI_SA" --project="$PROJECT_ID" \
  --role=roles/iam.workloadIdentityUser --member="$PRINCIPAL_SET" --quiet >/dev/null
echo "   ${REPO} may impersonate ${CI_SA_NAME}"

echo "== 6/6 Done. Store these three values as GitHub Actions SECRETS"
echo "   (GitHub > ${REPO} > Settings > Secrets and variables > Actions > New repository secret):"
echo
echo "   GCP_PROJECT_ID    = ${PROJECT_ID}"
echo "   GCP_WIF_PROVIDER  = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}"
echo "   GCP_CI_SA         = ${CI_SA}"
echo
echo "   Or, if the GitHub CLI is signed in here:"
echo "   gh secret set GCP_PROJECT_ID   -R ${REPO} -b '${PROJECT_ID}'"
echo "   gh secret set GCP_WIF_PROVIDER -R ${REPO} -b 'projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}'"
echo "   gh secret set GCP_CI_SA        -R ${REPO} -b '${CI_SA}'"
echo
echo "   Optional, later: register Earth Engine for this project (browser):"
echo "   https://code.earthengine.google.com/register?project=${PROJECT_ID}"
