#!/usr/bin/env bash
# =============================================================================
# scripts/bootstrap-tenant.sh
#
# GDE-Nino (Gemelo Digital Ecuador - El Nino) - tenant bootstrap with gcloud/bq.
# Idempotent shell equivalent of the Terraform module infra/tenant-bootstrap.
# Run it in Cloud Shell (or any shell with gcloud, bq, curl and python3) as a
# user who is Owner of the tenant project. Re-running converges; it never
# deletes anything.
#
# It creates in the TENANT project (names fixed by docs/03-architecture.md):
#   - APIs; service account ectwin-runner with least-privilege roles
#   - ONE grant to the platform: roles/iam.serviceAccountTokenCreator on the
#     ectwin-runner service-account resource for the platform broker
#   - BigQuery datasets ectwin and ectwin_scratch (US, 7-day table expiry)
#   - bucket gs://<PROJECT_ID>-ectwin (uniform access, public access
#     prevention, soft delete, lifecycle)
#   - Firestore (default) native database + session TTL
#   - Pub/Sub ectwin-budget-alerts (+ guard pull subscription) and ectwin-notify
#   - project-scoped budget 50/90/100% (+ forecast 100%) -> ectwin-budget-alerts
#   - Secret Manager placeholders typesafe-api-key, floodforecasting-api-key
#
# Usage:  scripts/bootstrap-tenant.sh --project PROJECT_ID [options]
#         scripts/bootstrap-tenant.sh --help
#
# Exit codes: 0 complete; 1 error (nothing or part applied - safe to re-run);
#             2 usage error; 3 complete but with actionable warnings.
#
# Tested 2026-09-30 with stubbed gcloud/bq/curl (fresh run, idempotent re-run,
# domain-restricted-sharing refusal, dry run, revoke). CLI flags still TO
# CONFIRM against the current Cloud SDK in Cloud Shell (acceptance AC-01):
#   gcloud storage buckets create/update --public-access-prevention,
#     --soft-delete-duration, --lifecycle-file ({"lifecycle":{"rule":[...]}}),
#     --update-labels, --cors-file
#   gcloud firestore databases create --delete-protection
#   gcloud firestore fields ttls update --enable-ttl --async
#   gcloud billing budgets create --filter-projects, --threshold-rule
#     percent=1.00,basis=forecasted-spend, --notifications-rule-pubsub-topic
#   bq update --source FILE (dataset access list with legacy WRITER/READER)
# =============================================================================
set -euo pipefail

readonly BOOTSTRAP_VERSION="0.1.0"
readonly SCRIPT_NAME="${0##*/}"
readonly RUNNER_ID="ectwin-runner"
readonly DEFAULT_BROKER_SA="ectwin-broker@ectwin-platform-prod.iam.gserviceaccount.com"
readonly TOKEN_CREATOR_ROLE="roles/iam.serviceAccountTokenCreator"
readonly BUDGET_TOPIC="ectwin-budget-alerts"
readonly BUDGET_GUARD_SUB="ectwin-budget-alerts-guard"
readonly NOTIFY_TOPIC="ectwin-notify"

# ----------------------------------------------------------------------------
# Defaults (environment variables override; command-line flags override both)
# ----------------------------------------------------------------------------
PROJECT_ID="${PROJECT_ID:-}"
BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"
PLATFORM_SA="${PLATFORM_SA-$DEFAULT_BROKER_SA}" # empty string = path D (no broker)
BQ_LOCATION="${BQ_LOCATION:-US}"
GCS_LOCATION="${GCS_LOCATION:-us-central1}"
FIRESTORE_LOCATION="${FIRESTORE_LOCATION:-southamerica-west1}"
MONTHLY_BUDGET_USD="${MONTHLY_BUDGET_USD:-20}"
TIER="${TIER:-T1}"
ENABLE_VERTEX="${ENABLE_VERTEX:-false}"
ENABLE_BATCH="${ENABLE_BATCH:-false}"
ENABLE_MANAGED_PIPELINES="${ENABLE_MANAGED_PIPELINES:-false}"
ENABLE_FLOOD_API="${ENABLE_FLOOD_API:-false}"
CONNECTION_CODE="${CONNECTION_CODE:-}"
APP_ORIGINS="${APP_ORIGINS:-}" # comma-separated https origins for bucket CORS
SCRATCH_RETENTION_DAYS="${SCRATCH_RETENTION_DAYS:-7}"
NEARLINE_AFTER_DAYS="${NEARLINE_AFTER_DAYS:-90}"
SOFT_DELETE_DAYS="${SOFT_DELETE_DAYS:-7}"
SUBSCRIBE_COMMONS="${SUBSCRIBE_COMMONS:-false}"
COMMONS_PROJECT="${COMMONS_PROJECT:-ectwin-commons-prod}"
COMMONS_EXCHANGE="${COMMONS_EXCHANGE:-ectwin_exchange}"
COMMONS_LISTING="${COMMONS_LISTING:-ectwin_commons_v1}"
ALLOW_NON_US_BQ="${ALLOW_NON_US_BQ:-false}"
DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"
MODE="bootstrap" # or revoke
LOG_FILE="${LOG_FILE:-}"

ACTION_WARNINGS=() # actionable -> exit 3
NOTES=()           # informational only
DRS_BLOCKED=false
PROJECT_NUMBER=""
SA_EMAIL=""
TMP_DIR=""

usage() {
  cat <<EOF
${SCRIPT_NAME} v${BOOTSTRAP_VERSION} - GDE-Nino tenant bootstrap (gcloud/bq)

Usage: ${SCRIPT_NAME} --project PROJECT_ID [options]

Required:
  --project ID                 Tenant project (env PROJECT_ID). Must have billing enabled.

Common options:
  --billing-account ID         XXXXXX-XXXXXX-XXXXXX (env BILLING_ACCOUNT). Default: the
                               account currently linked to the project.
  --platform-sa EMAIL          Broker SA granted TokenCreator on ectwin-runner
                               (env PLATFORM_SA, default ${DEFAULT_BROKER_SA}).
  --no-broker                  Path D (self-deployed): grant nothing to the platform.
  --budget-usd N               Monthly budget, whole USD (env MONTHLY_BUDGET_USD, default 20).
  --tier T1|T2|T3|T4           Label only (env TIER, default T1).
  --connection-code CODE       One-time code from the web app; stored as a dataset label.

Locations (D10):
  --bq-location LOC            Default US. Anything else is refused unless --allow-non-us-bigquery.
  --gcs-location REGION        Default us-central1.
  --firestore-location LOC     Default southamerica-west1 (LOPDP residency; cannot change later).

Feature flags:
  --enable-vertex              T3: aiplatform API + roles/aiplatform.user
  --enable-batch               T3: batch + compute APIs + Batch roles
  --enable-managed-pipelines   Let the platform (via ectwin-runner) deploy/pause tenant jobs
  --enable-flood-api           Enable floodforecasting.googleapis.com (own allow-listed access)
  --app-origins LIST           Comma-separated https origins for bucket CORS (signed URL reads)
  --subscribe-commons          Subscribe the Commons listing into dataset ectwin_commons
                               (only after the listing is published; request shape to confirm)

Other:
  --revoke-broker              Remove the broker grant (disconnect the platform) and exit.
  --dry-run                    Print mutating commands instead of running them.
  --yes                        Do not ask for confirmation.
  --log-file PATH              Default: \$HOME/ectwin-bootstrap-<project>-<utc>.log
  -h, --help                   This help.

Examples:
  ${SCRIPT_NAME} --project gad-portoviejo-ectwin --budget-usd 20
  ${SCRIPT_NAME} --project minagua-ectwin --tier T3 --budget-usd 1000 --enable-vertex --enable-batch
  ${SCRIPT_NAME} --project sovereign-ectwin --no-broker
  ${SCRIPT_NAME} --project gad-portoviejo-ectwin --revoke-broker
EOF
}

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
ts() { date -u +%H:%M:%SZ; }
info() { printf '[%s] INFO  %s\n' "$(ts)" "$*"; }
ok() { printf '[%s] OK    %s\n' "$(ts)" "$*"; }
note() {
  printf '[%s] NOTE  %s\n' "$(ts)" "$*" >&2
  NOTES+=("$*")
}
warn() {
  printf '[%s] WARN  %s\n' "$(ts)" "$*" >&2
  ACTION_WARNINGS+=("$*")
}
die() {
  printf '[%s] ERROR %s\n' "$(ts)" "$*" >&2
  exit 1
}
step() { printf '\n==== %s ====\n' "$*"; }
is_true() { [[ "${1,,}" == "true" || "$1" == "1" || "${1,,}" == "yes" ]]; }

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then rm -rf "${TMP_DIR}"; fi
}
trap cleanup EXIT

# Run a mutating command, or print it in dry-run mode (to stderr, so callers
# may redirect stdout of the real command).
run() {
  if is_true "$DRY_RUN"; then
    printf '  [dry-run]' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

# retry ATTEMPTS cmd... : exponential back-off for IAM/API eventual consistency.
retry() {
  local attempts=$1
  shift
  local n=1 delay=5
  until "$@"; do
    if ((n >= attempts)); then
      return 1
    fi
    printf '[%s] ...   retry %d/%d in %ds: %s\n' "$(ts)" "$n" "$attempts" "$delay" "$*" >&2
    sleep "$delay"
    n=$((n + 1))
    delay=$((delay * 2))
  done
}

# json_get EXPR  (reads JSON on stdin; EXPR is a Python expression over d)
json_get() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    v = eval(sys.argv[1], {"d": d})
except Exception:
    v = ""
if isinstance(v, (dict, list)):
    print(json.dumps(v))
elif v is None:
    print("")
else:
    print(v)
' "$1"
}

# api METHOD URL [BODY] [QUOTA_PROJECT] -> prints response body; 0 on HTTP 2xx.
api() {
  local method=$1 url=$2 body=${3:-} quota=${4:-}
  local token out code
  token="$(gcloud auth print-access-token)"
  local args=(-sS -X "$method" -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" -w $'\n%{http_code}')
  if [[ -n "$quota" ]]; then args+=(-H "x-goog-user-project: ${quota}"); fi
  if [[ -n "$body" ]]; then args+=(-d "$body"); fi
  out="$(curl "${args[@]}" "$url")" || return 1
  code="${out##*$'\n'}"
  printf '%s' "${out%$'\n'*}"
  [[ "$code" =~ ^2[0-9][0-9]$ ]]
}

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------
parse_args() {
  while (($#)); do
    case "$1" in
    --project) PROJECT_ID="${2:?}"; shift 2 ;;
    --billing-account) BILLING_ACCOUNT="${2:?}"; shift 2 ;;
    --platform-sa) PLATFORM_SA="${2:?}"; shift 2 ;;
    --no-broker) PLATFORM_SA=""; shift ;;
    --bq-location) BQ_LOCATION="${2:?}"; shift 2 ;;
    --gcs-location) GCS_LOCATION="${2:?}"; shift 2 ;;
    --firestore-location) FIRESTORE_LOCATION="${2:?}"; shift 2 ;;
    --budget-usd) MONTHLY_BUDGET_USD="${2:?}"; shift 2 ;;
    --tier) TIER="${2:?}"; shift 2 ;;
    --connection-code) CONNECTION_CODE="${2:?}"; shift 2 ;;
    --enable-vertex) ENABLE_VERTEX=true; shift ;;
    --enable-batch) ENABLE_BATCH=true; shift ;;
    --enable-managed-pipelines) ENABLE_MANAGED_PIPELINES=true; shift ;;
    --enable-flood-api) ENABLE_FLOOD_API=true; shift ;;
    --app-origins) APP_ORIGINS="${2:?}"; shift 2 ;;
    --subscribe-commons) SUBSCRIBE_COMMONS=true; shift ;;
    --allow-non-us-bigquery) ALLOW_NON_US_BQ=true; shift ;;
    --revoke-broker) MODE="revoke"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes | -y) ASSUME_YES=true; shift ;;
    --log-file) LOG_FILE="${2:?}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
  done
}

validate_inputs() {
  [[ -n "$PROJECT_ID" ]] || { usage >&2; exit 2; }
  [[ "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || die "invalid project id: ${PROJECT_ID}"
  if [[ -n "$BILLING_ACCOUNT" && ! "$BILLING_ACCOUNT" =~ ^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$ ]]; then
    die "invalid billing account '${BILLING_ACCOUNT}' (expected XXXXXX-XXXXXX-XXXXXX, uppercase hex)"
  fi
  if [[ -n "$PLATFORM_SA" && ! "$PLATFORM_SA" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}[a-z0-9]\.iam\.gserviceaccount\.com$ ]]; then
    die "invalid platform service account: ${PLATFORM_SA}"
  fi
  [[ "$MONTHLY_BUDGET_USD" =~ ^[1-9][0-9]*$ ]] || die "--budget-usd must be a positive whole number"
  [[ "$TIER" =~ ^T[1-4]$ ]] || die "--tier must be T1, T2, T3 or T4"
  if [[ -n "$CONNECTION_CODE" && ! "$CONNECTION_CODE" =~ ^[a-z0-9_-]{8,63}$ ]]; then
    die "--connection-code must be 8-63 chars of [a-z0-9_-]"
  fi
  [[ "$GCS_LOCATION" =~ ^[a-z]+-[a-z]+[0-9]+$ ]] || die "--gcs-location must be a single region, e.g. us-central1"
  for n in "$SCRATCH_RETENTION_DAYS" "$NEARLINE_AFTER_DAYS" "$SOFT_DELETE_DAYS"; do
    [[ "$n" =~ ^[0-9]+$ ]] || die "retention values must be whole numbers of days"
  done
  if [[ "$BQ_LOCATION" != "US" ]] && ! is_true "$ALLOW_NON_US_BQ"; then
    die "BigQuery location must be US (WeatherNext and Commons linked datasets are in US; D10, FR-013)."
  fi
  if [[ "$FIRESTORE_LOCATION" != southamerica-* ]]; then
    note "Firestore location ${FIRESTORE_LOCATION} is outside southamerica-*: personal/session data would leave the region; LOPDP review needed (FR-013)."
  fi
  if [[ "$GCS_LOCATION" != "us-central1" ]]; then
    note "Bucket region ${GCS_LOCATION} differs from us-central1 (D10 cost co-location with BigQuery US and ARCO-ERA5)."
  fi
}

# ----------------------------------------------------------------------------
# Pre-checks
# ----------------------------------------------------------------------------
prechecks() {
  step "Pre-checks"
  local c
  for c in gcloud bq curl python3; do
    command -v "$c" >/dev/null 2>&1 || die "missing command '${c}'. Run from Cloud Shell or install the Google Cloud CLI."
  done

  local account
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n1 || true)"
  [[ -n "$account" ]] || die "no active gcloud account. Run: gcloud auth login"
  ok "gcloud account: ${account}"

  local pj
  pj="$(gcloud projects describe "$PROJECT_ID" --format=json 2>/dev/null)" ||
    die "cannot read project ${PROJECT_ID} (does it exist and do you have access?)"
  PROJECT_NUMBER="$(json_get 'd.get("projectNumber","")' <<<"$pj")"
  local state
  state="$(json_get 'd.get("lifecycleState","")' <<<"$pj")"
  [[ "$state" == "ACTIVE" ]] || die "project ${PROJECT_ID} is ${state:-unknown}, expected ACTIVE"
  ok "project ${PROJECT_ID} (number ${PROJECT_NUMBER}) is ACTIVE"
  SA_EMAIL="${RUNNER_ID}@${PROJECT_ID}.iam.gserviceaccount.com"

  [[ "$MODE" == "revoke" ]] && return 0

  local bj enabled linked
  bj="$(gcloud billing projects describe "$PROJECT_ID" --format=json 2>/dev/null)" ||
    die "cannot read billing info (need resourcemanager.projects.get and billing access)."
  enabled="$(json_get 'd.get("billingEnabled", False)' <<<"$bj")"
  linked="$(json_get 'd.get("billingAccountName","").split("/")[-1]' <<<"$bj")"
  [[ "$enabled" == "True" ]] ||
    die "billing is not enabled on ${PROJECT_ID}. Link a billing account, or request a sponsored project (T4) in the web app."
  if [[ -z "$BILLING_ACCOUNT" ]]; then
    BILLING_ACCOUNT="$linked"
  elif [[ "$BILLING_ACCOUNT" != "$linked" ]]; then
    die "project is billed to ${linked} but --billing-account is ${BILLING_ACCOUNT}; the budget would never see this project's spend."
  fi
  ok "billing enabled on account ${BILLING_ACCOUNT}"

  # Can the caller do everything? (best effort; invalid permission names make the call fail -> note only)
  local perms resp missing
  perms='["resourcemanager.projects.setIamPolicy","iam.serviceAccounts.create","iam.serviceAccounts.setIamPolicy","serviceusage.services.enable","bigquery.datasets.create","storage.buckets.create","datastore.databases.create","pubsub.topics.create","pubsub.topics.setIamPolicy","secretmanager.secrets.create"]'
  if resp="$(api POST "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:testIamPermissions" "{\"permissions\":${perms}}")"; then
    missing="$(python3 -c '
import json, sys
want = json.loads(sys.argv[1]); got = set(json.loads(sys.argv[2] or "{}").get("permissions", []))
print(" ".join(p for p in want if p not in got))' "$perms" "$resp")"
    if [[ -n "$missing" ]]; then
      die "missing permissions on ${PROJECT_ID}: ${missing}. Ask a project Owner to run this script (or grant these)."
    fi
    ok "caller holds all permissions needed on the project"
  else
    note "could not test IAM permissions (continuing): ${resp:0:200}"
  fi

  # Domain-restricted sharing (secure-by-default orgs created on/after 2024-05-03). Best effort.
  if [[ -n "$PLATFORM_SA" ]]; then
    local pol
    for c in iam.allowedPolicyMemberDomains iam.managed.allowedPolicyMembers; do
      if pol="$(gcloud org-policies describe "$c" --project="$PROJECT_ID" --effective --format=json 2>/dev/null)"; then
        if grep -Eq '"allowedValues"|"enforce": *true' <<<"$pol"; then
          note "org policy ${c} is active: the broker grant may be refused. If so, see README 'Domain-restricted sharing' (exception request or path C)."
        fi
      fi
    done
  fi
}

confirm() {
  step "Plan"
  cat <<EOF
  Project            : ${PROJECT_ID} (${PROJECT_NUMBER})
  Billing account    : ${BILLING_ACCOUNT}
  Runner SA          : ${SA_EMAIL}
  Platform broker SA : ${PLATFORM_SA:-<none - path D>}
  Tier / budget      : ${TIER} / ${MONTHLY_BUDGET_USD} USD per month (alerts 50/90/100% + forecast 100%)
  BigQuery           : ${PROJECT_ID}:ectwin, ${PROJECT_ID}:ectwin_scratch in ${BQ_LOCATION}
  Bucket             : gs://${PROJECT_ID}-ectwin in ${GCS_LOCATION}
  Firestore          : (default) FIRESTORE_NATIVE in ${FIRESTORE_LOCATION}
  Flags              : vertex=${ENABLE_VERTEX} batch=${ENABLE_BATCH} managed_pipelines=${ENABLE_MANAGED_PIPELINES} flood_api=${ENABLE_FLOOD_API}
  Dry run            : ${DRY_RUN}
EOF
  if ! is_true "$ASSUME_YES" && ! is_true "$DRY_RUN"; then
    local ans
    read -r -p "Proceed? / Continuar? [y/N] " ans
    [[ "$ans" =~ ^[yYsS] ]] || die "aborted by user"
  fi
}

# ----------------------------------------------------------------------------
# 1. APIs
# ----------------------------------------------------------------------------
enable_apis() {
  step "1/10 APIs"
  local services=(
    serviceusage.googleapis.com cloudresourcemanager.googleapis.com iam.googleapis.com
    iamcredentials.googleapis.com bigquery.googleapis.com bigquerystorage.googleapis.com
    analyticshub.googleapis.com storage.googleapis.com firestore.googleapis.com
    run.googleapis.com cloudscheduler.googleapis.com workflows.googleapis.com
    pubsub.googleapis.com secretmanager.googleapis.com logging.googleapis.com
    monitoring.googleapis.com earthengine.googleapis.com billingbudgets.googleapis.com
    cloudquotas.googleapis.com
  )
  if is_true "$ENABLE_VERTEX"; then services+=(aiplatform.googleapis.com); fi
  if is_true "$ENABLE_BATCH"; then services+=(batch.googleapis.com compute.googleapis.com); fi
  if is_true "$ENABLE_FLOOD_API"; then services+=(floodforecasting.googleapis.com); fi

  local enabled_now s to_enable=()
  enabled_now="$(gcloud services list --enabled --project="$PROJECT_ID" --format='value(config.name)' 2>/dev/null || true)"
  for s in "${services[@]}"; do
    grep -qx "$s" <<<"$enabled_now" || to_enable+=("$s")
  done
  if ((${#to_enable[@]} == 0)); then
    ok "all ${#services[@]} APIs already enabled"
    return 0
  fi
  info "enabling ${#to_enable[@]} API(s): ${to_enable[*]}"
  local i
  for ((i = 0; i < ${#to_enable[@]}; i += 15)); do
    retry 3 run gcloud services enable "${to_enable[@]:i:15}" --project="$PROJECT_ID" ||
      die "could not enable APIs. If floodforecasting failed, re-run without --enable-flood-api (access is allow-listed)."
  done
  ok "APIs enabled"
}

# ----------------------------------------------------------------------------
# 2-3. Runner service account and roles
# ----------------------------------------------------------------------------
ensure_runner() {
  step "2/10 Service account ${RUNNER_ID}"
  local disabled
  if disabled="$(gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" --format='value(disabled)' 2>/dev/null)"; then
    ok "exists: ${SA_EMAIL}"
    if [[ "${disabled,,}" == "true" ]]; then
      warn "${SA_EMAIL} is DISABLED (tenant pause?). Re-enable with: gcloud iam service-accounts enable ${SA_EMAIL} --project=${PROJECT_ID}"
    fi
  else
    run gcloud iam service-accounts create "$RUNNER_ID" --project="$PROJECT_ID" \
      --display-name="GDE-Nino runner (ectwin-runner)" \
      --description="Runs GDE-Nino tenant pipelines; impersonated by the platform broker with <=15 min tokens. Bootstrap v${BOOTSTRAP_VERSION}."
    if ! is_true "$DRY_RUN"; then
      retry 6 gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" --format='value(email)' >/dev/null 2>&1 ||
        die "service account created but not yet visible; wait a minute and re-run"
    fi
    ok "created: ${SA_EMAIL}"
  fi
}

grant_project_roles() {
  step "3/10 Least-privilege project roles for ${RUNNER_ID}"
  # role|justification (the same matrix as infra/tenant-bootstrap/main.tf)
  local roles=(
    "roles/bigquery.jobUser|Run BigQuery jobs billed to the tenant; data access is per dataset"
    "roles/bigquery.readSessionUser|BigQuery Storage Read API for fast reads of permitted tables"
    "roles/serviceusage.serviceUsageConsumer|Bill API calls and Requester-Pays reads to this project; required by Earth Engine"
    "roles/earthengine.writer|Earth Engine computations and EE assets in this project"
    "roles/datastore.user|Read/write tenant Firestore documents (sessions, AOIs, runs)"
    "roles/run.invoker|Scheduler/Workflows (as ectwin-runner) execute the tenant's Cloud Run jobs"
    "roles/logging.logWriter|Write logs from jobs running as ectwin-runner"
  )
  if is_true "$ENABLE_VERTEX"; then
    roles+=("roles/aiplatform.user|Vertex AI custom jobs (WN2 scenarios) and Gemini requests")
  fi
  if is_true "$ENABLE_BATCH"; then
    roles+=("roles/batch.jobsEditor|Submit/manage Cloud Batch jobs (SFINCS/LISFLOOD-FP on Spot)")
    roles+=("roles/batch.agentReporter|Batch VMs running as ectwin-runner report task status")
  fi
  if is_true "$ENABLE_MANAGED_PIPELINES"; then
    roles+=("roles/run.developer|Create/update tenant Cloud Run jobs from platform images after Owner approval")
    roles+=("roles/cloudscheduler.admin|Create/update/pause tenant Scheduler jobs (budget guard)")
    roles+=("roles/pubsub.editor|Create tenant subscriptions to Commons topics")
  fi
  local entry role why
  for entry in "${roles[@]}"; do
    role="${entry%%|*}"
    why="${entry#*|}"
    retry 4 run gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:${SA_EMAIL}" --role="$role" --condition=None --quiet >/dev/null ||
      die "could not grant ${role}"
    ok "${role}  - ${why}"
  done
}

# ----------------------------------------------------------------------------
# 4. Service-account-level bindings: the single platform grant (+ self actAs)
# ----------------------------------------------------------------------------
grant_sa_bindings() {
  step "4/10 Platform grant on ${RUNNER_ID} only"
  if [[ -z "$PLATFORM_SA" ]]; then
    note "path D: no platform principal granted (zero standing operator access)"
  elif is_true "$DRY_RUN"; then
    run gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" --project="$PROJECT_ID" \
      --member="serviceAccount:${PLATFORM_SA}" --role="$TOKEN_CREATOR_ROLE" --condition=None --quiet
  else
    # Retry only for IAM eventual consistency (new SA); stop at once on an org-policy refusal.
    local err="" attempt granted=false
    for attempt in 1 2 3 4; do
      if err="$(gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" --project="$PROJECT_ID" \
        --member="serviceAccount:${PLATFORM_SA}" --role="$TOKEN_CREATOR_ROLE" --condition=None --quiet 2>&1 >/dev/null)"; then
        granted=true
        break
      fi
      if grep -Eqi 'permitted customer|allowedPolicyMemberDomains|allowedPolicyMembers|org(anization)? policy' <<<"$err"; then
        DRS_BLOCKED=true
        break
      fi
      sleep $((attempt * 5))
    done
    if is_true "$granted"; then
      ok "${TOKEN_CREATOR_ROLE} on ${SA_EMAIL} -> ${PLATFORM_SA}"
    elif is_true "$DRS_BLOCKED"; then
      warn "domain-restricted sharing blocked the broker grant. Ask your organisation admin for an exception for ${PLATFORM_SA} (README 'Domain-restricted sharing') or choose path C (Workload Identity Federation)."
    else
      warn "could not grant ${TOKEN_CREATOR_ROLE} to ${PLATFORM_SA}: ${err:0:300}"
    fi
  fi

  if is_true "$ENABLE_BATCH" || is_true "$ENABLE_VERTEX" || is_true "$ENABLE_MANAGED_PIPELINES"; then
    retry 4 run gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" --project="$PROJECT_ID" \
      --member="serviceAccount:${SA_EMAIL}" --role="roles/iam.serviceAccountUser" --condition=None --quiet >/dev/null ||
      die "could not grant self actAs on ${SA_EMAIL}"
    ok "roles/iam.serviceAccountUser on ${SA_EMAIL} for itself (jobs that run as ectwin-runner)"
  fi
}

# ----------------------------------------------------------------------------
# 5. BigQuery datasets (US) and dataset-level access
# ----------------------------------------------------------------------------
# grant_dataset_access DATASET LEGACY_ROLE EMAIL   (LEGACY_ROLE: WRITER|READER)
grant_dataset_access() {
  local ds=$1 role=$2 email=$3
  local ref="${PROJECT_ID}:${ds}" file rc=0
  if is_true "$DRY_RUN"; then
    run bq --project_id="$PROJECT_ID" update --source "<access-list-with-${role}-for-${email}>.json" "$ref"
    return 0
  fi
  file="${TMP_DIR}/${ds}.json"
  bq --project_id="$PROJECT_ID" show --format=prettyjson "$ref" >"$file"
  python3 - "$file" "$role" "$email" <<'PY' || rc=$?
import json, sys
path, role, email = sys.argv[1:4]
aliases = {"WRITER": {"WRITER", "roles/bigquery.dataEditor"},
           "READER": {"READER", "roles/bigquery.dataViewer"}}[role]
with open(path) as f:
    d = json.load(f)
acc = d.setdefault("access", [])
if any(a.get("userByEmail") == email and a.get("role") in aliases for a in acc):
    sys.exit(10)
acc.append({"role": role, "userByEmail": email})
with open(path, "w") as f:
    json.dump(d, f)
PY
  if ((rc == 10)); then
    ok "${ref}: ${role} for ${email} already present"
  elif ((rc == 0)); then
    retry 3 bq --project_id="$PROJECT_ID" update --source "$file" "$ref" >/dev/null ||
      die "could not update access on ${ref}"
    ok "${ref}: granted ${role} to ${email}"
  else
    die "could not edit access list of ${ref}"
  fi
}

# ensure_dataset ID DESCRIPTION [DEFAULT_TABLE_EXPIRATION_SECONDS]
ensure_dataset() {
  local ds=$1 desc=$2 exp=${3:-}
  local ref="${PROJECT_ID}:${ds}" json loc
  if json="$(bq --project_id="$PROJECT_ID" show --format=json "$ref" 2>/dev/null)"; then
    loc="$(json_get 'd.get("location","")' <<<"$json")"
    [[ "$loc" == "$BQ_LOCATION" ]] ||
      die "dataset ${ref} exists in ${loc}, expected ${BQ_LOCATION}. Datasets cannot be moved; see README troubleshooting."
    ok "${ref} exists in ${loc}"
    if [[ -n "$exp" ]]; then
      run bq --project_id="$PROJECT_ID" update --default_table_expiration "$exp" "$ref" >/dev/null
    fi
  else
    local args=(--project_id="$PROJECT_ID" --location="$BQ_LOCATION" mk --dataset
      --description="$desc" --label=app:ectwin --label=plane:tenant --label=managed-by:bootstrap-script
      --label="ectwin-tier:${TIER,,}")
    if [[ -n "$exp" ]]; then args+=(--default_table_expiration="$exp"); fi
    retry 3 run bq "${args[@]}" "$ref" >/dev/null || die "could not create ${ref}"
    ok "created ${ref} in ${BQ_LOCATION}"
  fi
}

ensure_datasets() {
  step "5/10 BigQuery datasets (${BQ_LOCATION})"
  ensure_dataset ectwin "GDE-Nino curated tenant data and outputs (schemas/bigquery/tenant/)."
  ensure_dataset ectwin_scratch "GDE-Nino scratch; tables expire after 7 days." 604800
  if [[ -n "$CONNECTION_CODE" ]]; then
    run bq --project_id="$PROJECT_ID" update --set_label "ectwin-connection:${CONNECTION_CODE}" "${PROJECT_ID}:ectwin" >/dev/null
    ok "connection code stored as label ectwin-connection on ${PROJECT_ID}:ectwin"
  fi
  grant_dataset_access ectwin WRITER "$SA_EMAIL"
  grant_dataset_access ectwin_scratch WRITER "$SA_EMAIL"
}

# ----------------------------------------------------------------------------
# 6. Bucket gs://<project>-ectwin
# ----------------------------------------------------------------------------
ensure_bucket() {
  local bucket="gs://${PROJECT_ID}-ectwin"
  step "6/10 Bucket ${bucket} (${GCS_LOCATION})"
  local loc
  if loc="$(gcloud storage buckets describe "$bucket" --format='value(location)' 2>/dev/null)"; then
    ok "${bucket} exists (${loc})"
    if [[ "${loc,,}" != "${GCS_LOCATION,,}" ]]; then
      note "${bucket} is in ${loc}, not ${GCS_LOCATION}; buckets cannot be moved (keeping it)."
    fi
  else
    retry 2 run gcloud storage buckets create "$bucket" --project="$PROJECT_ID" \
      --location="$GCS_LOCATION" --default-storage-class=STANDARD \
      --uniform-bucket-level-access --public-access-prevention ||
      die "could not create ${bucket}. If the name is taken by another project, see README troubleshooting (bucket_name_override)."
    ok "created ${bucket}"
  fi

  local lc="${TMP_DIR}/lifecycle.json"
  cat >"$lc" <<EOF
{
  "lifecycle": {
    "rule": [
      {"action": {"type": "Delete"},
       "condition": {"age": ${SCRATCH_RETENTION_DAYS}, "matchesPrefix": ["scratch/"]}},
      {"action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
       "condition": {"age": ${NEARLINE_AFTER_DAYS},
                     "matchesPrefix": ["runs/", "reports/", "evidence/", "exports/", "raw/"],
                     "matchesStorageClass": ["STANDARD"]}},
      {"action": {"type": "AbortIncompleteMultipartUpload"},
       "condition": {"age": 7}}
    ]
  }
}
EOF
  local upd=(storage buckets update "$bucket" --uniform-bucket-level-access --public-access-prevention
    --lifecycle-file="$lc"
    "--update-labels=app=ectwin,plane=tenant,managed-by=bootstrap-script,component=tenant-files,ectwin-tier=${TIER,,}")
  if ((SOFT_DELETE_DAYS > 0)); then
    upd+=(--soft-delete-duration="${SOFT_DELETE_DAYS}d")
  else
    upd+=(--clear-soft-delete)
  fi
  if [[ -n "$APP_ORIGINS" ]]; then
    local cors="${TMP_DIR}/cors.json"
    python3 - "$APP_ORIGINS" >"$cors" <<'PY'
import json, sys
origins = [o.strip() for o in sys.argv[1].split(",") if o.strip()]
print(json.dumps([{"origin": origins, "method": ["GET", "HEAD"],
                   "responseHeader": ["Content-Type", "Content-Range", "Range", "ETag", "Content-Encoding"],
                   "maxAgeSeconds": 3600}]))
PY
    upd+=(--cors-file="$cors")
  fi
  retry 3 run gcloud "${upd[@]}" >/dev/null || die "could not configure ${bucket}"
  ok "uniform access, public access prevention, soft delete ${SOFT_DELETE_DAYS} d, lifecycle (scratch/ ${SCRATCH_RETENTION_DAYS} d; NEARLINE after ${NEARLINE_AFTER_DAYS} d)"

  retry 4 run gcloud storage buckets add-iam-policy-binding "$bucket" \
    --member="serviceAccount:${SA_EMAIL}" --role=roles/storage.objectAdmin >/dev/null ||
    die "could not grant objectAdmin on ${bucket}"
  ok "roles/storage.objectAdmin on ${bucket} -> ${RUNNER_ID}"
}

# ----------------------------------------------------------------------------
# 7. Firestore (default)
# ----------------------------------------------------------------------------
ensure_firestore() {
  step "7/10 Firestore (default) in ${FIRESTORE_LOCATION}"
  local fs type loc
  if fs="$(gcloud firestore databases describe --database='(default)' --project="$PROJECT_ID" --format=json 2>/dev/null)"; then
    type="$(json_get 'd.get("type","")' <<<"$fs")"
    loc="$(json_get 'd.get("locationId","")' <<<"$fs")"
    ok "(default) exists: type=${type} location=${loc}"
    [[ "$type" == "FIRESTORE_NATIVE" ]] ||
      warn "(default) is ${type}; GDE-Nino needs Firestore Native mode. An empty Datastore-mode database can be switched in the console; otherwise use a new project."
    [[ "$loc" == "$FIRESTORE_LOCATION" ]] ||
      note "(default) is in ${loc} (not ${FIRESTORE_LOCATION}); the location cannot be changed. Record it in the tenant registry."
  else
    retry 3 run gcloud firestore databases create --database='(default)' --project="$PROJECT_ID" \
      --location="$FIRESTORE_LOCATION" --type=firestore-native --delete-protection ||
      die "could not create Firestore (default)"
    ok "created (default) FIRESTORE_NATIVE in ${FIRESTORE_LOCATION} with delete protection"
  fi
  if run gcloud firestore fields ttls update expire_at --collection-group=sessions --enable-ttl \
    --database='(default)' --project="$PROJECT_ID" --async >/dev/null; then
    ok "TTL policy sessions.expire_at requested (30-day sessions)"
  else
    note "could not set TTL on sessions.expire_at (it may already exist); check in the console"
  fi
}

# ----------------------------------------------------------------------------
# 8. Pub/Sub
# ----------------------------------------------------------------------------
ensure_topic() {
  local topic=$1 component=$2
  if gcloud pubsub topics describe "$topic" --project="$PROJECT_ID" >/dev/null 2>&1; then
    ok "topic ${topic} exists"
  else
    retry 3 run gcloud pubsub topics create "$topic" --project="$PROJECT_ID" \
      --labels="app=ectwin,plane=tenant,managed-by=bootstrap-script,component=${component}" >/dev/null ||
      die "could not create topic ${topic}"
    ok "created topic ${topic}"
  fi
}

ensure_pubsub() {
  step "8/10 Pub/Sub"
  ensure_topic "$BUDGET_TOPIC" cost-guardrails
  ensure_topic "$NOTIFY_TOPIC" notifications
  if gcloud pubsub subscriptions describe "$BUDGET_GUARD_SUB" --project="$PROJECT_ID" >/dev/null 2>&1; then
    ok "subscription ${BUDGET_GUARD_SUB} exists"
  else
    retry 3 run gcloud pubsub subscriptions create "$BUDGET_GUARD_SUB" --project="$PROJECT_ID" \
      --topic="$BUDGET_TOPIC" --ack-deadline=60 --message-retention-duration=7d --expiration-period=never \
      --labels="app=ectwin,plane=tenant,managed-by=bootstrap-script,component=cost-guardrails" >/dev/null ||
      die "could not create subscription ${BUDGET_GUARD_SUB}"
    ok "created pull subscription ${BUDGET_GUARD_SUB} (never expires)"
  fi
  retry 4 run gcloud pubsub subscriptions add-iam-policy-binding "$BUDGET_GUARD_SUB" --project="$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" --role=roles/pubsub.subscriber >/dev/null ||
    die "could not grant subscriber on ${BUDGET_GUARD_SUB}"
  retry 4 run gcloud pubsub topics add-iam-policy-binding "$NOTIFY_TOPIC" --project="$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" --role=roles/pubsub.publisher >/dev/null ||
    die "could not grant publisher on ${NOTIFY_TOPIC}"
  ok "${RUNNER_ID}: subscriber on ${BUDGET_GUARD_SUB}, publisher on ${NOTIFY_TOPIC}"
  note "the push subscription ${NOTIFY_TOPIC} -> ectwin-notifier is added once the platform domain is fixed (Terraform variable notifier_push_endpoint)."
}

# ----------------------------------------------------------------------------
# 9. Budget (alerts only; does not cap spend)
# ----------------------------------------------------------------------------
ensure_budget() {
  step "9/10 Budget ${MONTHLY_BUDGET_USD} USD/month"
  local display="ectwin-${PROJECT_ID}" existing
  existing="$(gcloud billing budgets list --billing-account="$BILLING_ACCOUNT" --billing-project="$PROJECT_ID" \
    --format='value(name,displayName)' 2>/dev/null | awk -F'\t' -v n="$display" '$2 == n { print $1; exit }' || true)"
  if [[ -n "$existing" ]]; then
    if run gcloud billing budgets update "$existing" --billing-account="$BILLING_ACCOUNT" \
      --billing-project="$PROJECT_ID" --budget-amount="${MONTHLY_BUDGET_USD}USD" >/dev/null; then
      ok "budget ${display} exists (${existing}); amount set to ${MONTHLY_BUDGET_USD} USD"
    else
      warn "budget ${display} exists but could not be updated"
    fi
    return 0
  fi
  if run gcloud billing budgets create --billing-account="$BILLING_ACCOUNT" --billing-project="$PROJECT_ID" \
    --display-name="$display" --budget-amount="${MONTHLY_BUDGET_USD}USD" --calendar-period=month \
    --filter-projects="projects/${PROJECT_NUMBER}" \
    --threshold-rule=percent=0.50 --threshold-rule=percent=0.90 --threshold-rule=percent=1.00 \
    --threshold-rule=percent=1.00,basis=forecasted-spend \
    --notifications-rule-pubsub-topic="projects/${PROJECT_ID}/topics/${BUDGET_TOPIC}" >/dev/null; then
    ok "created budget ${display} -> projects/${PROJECT_ID}/topics/${BUDGET_TOPIC}"
  else
    warn "budget NOT created. You need budget rights on billing account ${BILLING_ACCOUNT} (e.g. Billing Account Costs Manager) or project Owner for a project-scoped budget. Console: Billing > Budgets & alerts > Create (scope: this project; thresholds 50/90/100%; connect Pub/Sub topic ${BUDGET_TOPIC})."
  fi
}

# ----------------------------------------------------------------------------
# 10. Secret Manager placeholders (no versions)
# ----------------------------------------------------------------------------
ensure_secrets() {
  step "10/10 Secret Manager placeholders"
  local s
  for s in typesafe-api-key floodforecasting-api-key; do
    if gcloud secrets describe "$s" --project="$PROJECT_ID" >/dev/null 2>&1; then
      ok "secret ${s} exists"
    else
      retry 3 run gcloud secrets create "$s" --project="$PROJECT_ID" --replication-policy=automatic \
        --labels="app=ectwin,plane=tenant,managed-by=bootstrap-script,component=tenant-secrets" >/dev/null ||
        die "could not create secret ${s}"
      ok "created secret ${s} (no versions)"
    fi
    retry 4 run gcloud secrets add-iam-policy-binding "$s" --project="$PROJECT_ID" \
      --member="serviceAccount:${SA_EMAIL}" --role=roles/secretmanager.secretAccessor >/dev/null ||
      die "could not grant secretAccessor on ${s}"
  done
  ok "${RUNNER_ID} can read typesafe-api-key and floodforecasting-api-key"
}

# ----------------------------------------------------------------------------
# Optional: Commons listing subscription (after milestone M1.2)
# ----------------------------------------------------------------------------
subscribe_commons() {
  is_true "$SUBSCRIBE_COMMONS" || return 0
  step "Optional: Analytics Hub subscription ${COMMONS_LISTING} -> ${PROJECT_ID}:ectwin_commons"
  if bq --project_id="$PROJECT_ID" show --format=none "${PROJECT_ID}:ectwin_commons" >/dev/null 2>&1; then
    ok "linked dataset ectwin_commons exists"
  elif is_true "$DRY_RUN"; then
    run curl -X POST "https://analyticshub.googleapis.com/v1/projects/${COMMONS_PROJECT}/locations/us/dataExchanges/${COMMONS_EXCHANGE}/listings/${COMMONS_LISTING}:subscribe"
    return 0
  else
    local body resp
    body="{\"destinationDataset\":{\"datasetReference\":{\"projectId\":\"${PROJECT_ID}\",\"datasetId\":\"ectwin_commons\"},\"location\":\"${BQ_LOCATION}\"}}"
    if resp="$(api POST "https://analyticshub.googleapis.com/v1/projects/${COMMONS_PROJECT}/locations/us/dataExchanges/${COMMONS_EXCHANGE}/listings/${COMMONS_LISTING}:subscribe" "$body" "$PROJECT_ID")"; then
      ok "subscribed; linked dataset ${PROJECT_ID}:ectwin_commons created"
    else
      warn "Commons subscription failed (listing not published yet, or no subscriber access): ${resp:0:300}"
      return 0
    fi
  fi
  grant_dataset_access ectwin_commons READER "$SA_EMAIL"
}

# ----------------------------------------------------------------------------
# Revoke mode
# ----------------------------------------------------------------------------
revoke_broker() {
  step "Revoke platform access"
  [[ -n "$PLATFORM_SA" ]] || die "--revoke-broker needs the broker SA (--platform-sa or default)"
  if run gcloud iam service-accounts remove-iam-policy-binding "$SA_EMAIL" --project="$PROJECT_ID" \
    --member="serviceAccount:${PLATFORM_SA}" --role="$TOKEN_CREATOR_ROLE" --condition=None --quiet >/dev/null; then
    ok "removed ${TOKEN_CREATOR_ROLE} for ${PLATFORM_SA} on ${SA_EMAIL}"
  else
    note "binding not found (already revoked?) or could not be removed; check: gcloud iam service-accounts get-iam-policy ${SA_EMAIL} --project=${PROJECT_ID}"
  fi
  cat <<EOF

Platform access removed. At most one already-issued token (<=15 min) remains valid.
Your data (BigQuery ectwin*, gs://${PROJECT_ID}-ectwin, Firestore) is untouched.
Optional next steps:
  - Also stop your own scheduled pipelines:  gcloud iam service-accounts disable ${SA_EMAIL} --project=${PROJECT_ID}
  - In the web app: Proyecto y costos > Desconectar (deletes the registry entry, FR-015).
  - Verify:  scripts/verify-tenant.sh --project ${PROJECT_ID} --no-broker
EOF
}

# ----------------------------------------------------------------------------
# Summary and next steps
# ----------------------------------------------------------------------------
summary() {
  step "Summary"
  local payload
  payload="$(python3 - "$BOOTSTRAP_VERSION" "$PROJECT_ID" "$PROJECT_NUMBER" "$SA_EMAIL" "$PLATFORM_SA" "$TIER" \
    "$BQ_LOCATION" "$GCS_LOCATION" "$FIRESTORE_LOCATION" "$CONNECTION_CODE" <<'PY'
import json, sys
v, p, n, sa, broker, tier, bq, gcs, fs, code = sys.argv[1:11]
print(json.dumps({
    "bootstrap_version": v, "project_id": p, "project_number": n, "runner_sa_email": sa,
    "broker_sa": broker, "tier": tier, "bq_location": bq, "gcs_location": gcs,
    "firestore_location": fs, "bucket": p + "-ectwin",
    "connection_code": "set-on-dataset-label" if code else "none"}, indent=2))
PY
)"
  cat <<EOF
Connection summary (paste into the web app, 'Conectar proyecto'):
${payload}

Next steps (details: infra/tenant-bootstrap/README.md, "After the bootstrap"):
  1. Web app > Conectar proyecto: enter ${PROJECT_ID}; the broker mints a <=15-min token and runs the preflight.
  2. Earth Engine registration (browser, ~3 min):
       https://code.earthengine.google.com/register?project=${PROJECT_ID}
     Operational COE/ministry use usually needs a COMMERCIAL registration (Limited plan, usage fees only),
     or a noncommercial Partner-tier application. Then set the daily EECU cap
     (IAM & Admin > Quotas: earthengine.googleapis.com/daily_eecu_usage_time).
  3. WeatherNext Data Request form (per Google account; ~5-7 business days), then subscribe the
     WeatherNext listings as linked datasets weathernext_3 / weathernext_2 in location US.
  4. Commons listing (from 2026-11-06): re-run with --subscribe-commons, or subscribe in the console
     as dataset ectwin_commons.
  5. BigQuery custom quota "Query usage per day" (e.g. 1 TiB for T1/T2):
     IAM & Admin > Quotas & System Limits > filter "Query usage per day" > Edit (approximate).
  6. Optional keys (never paste keys into chat or tickets):
       printf %s "\$KEY" | gcloud secrets versions add typesafe-api-key --data-file=- --project=${PROJECT_ID}
  7. Verify:  scripts/verify-tenant.sh --project ${PROJECT_ID}
EOF
  if ((${#NOTES[@]})); then
    printf '\nNotes:\n'
    printf '  - %s\n' "${NOTES[@]}"
  fi
  if ((${#ACTION_WARNINGS[@]})); then
    printf '\nACTION NEEDED (%d):\n' "${#ACTION_WARNINGS[@]}"
    printf '  - %s\n' "${ACTION_WARNINGS[@]}"
    if is_true "$DRS_BLOCKED"; then
      printf '  -> The platform cannot connect until the broker grant exists. Re-run this script after the org-policy exception.\n'
    fi
    return 3
  fi
  printf '\nBootstrap v%s complete for %s.\n' "$BOOTSTRAP_VERSION" "$PROJECT_ID"
  return 0
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
  parse_args "$@"
  validate_inputs
  if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="${HOME:-/tmp}/ectwin-bootstrap-${PROJECT_ID}-$(date -u +%Y%m%dT%H%M%SZ).log"
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "${SCRIPT_NAME} v${BOOTSTRAP_VERSION}; log: ${LOG_FILE}"
  TMP_DIR="$(mktemp -d)"

  prechecks
  if [[ "$MODE" == "revoke" ]]; then
    revoke_broker
    return 0
  fi
  confirm
  enable_apis
  ensure_runner
  grant_project_roles
  grant_sa_bindings
  ensure_datasets
  ensure_bucket
  ensure_firestore
  ensure_pubsub
  ensure_budget
  ensure_secrets
  subscribe_commons
  summary
}

main "$@"
