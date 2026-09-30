#!/usr/bin/env bash
# =============================================================================
# scripts/verify-tenant.sh
#
# GDE-Nino - READ-ONLY checks of a tenant project created by
# infra/tenant-bootstrap (Terraform) or scripts/bootstrap-tenant.sh.
# It changes nothing. Run it as a tenant Owner/Viewer in Cloud Shell; the
# platform runs the same checks as its preflight (FR-009) using the runner token.
#
# Checks (IDs are stable and referenced in README/runbook):
#   VT-01 project ACTIVE              VT-11 linked datasets (info)
#   VT-02 billing enabled             VT-12 bucket settings + IAM
#   VT-03 APIs enabled                VT-13 Firestore (default) native + location
#   VT-04 ectwin-runner exists        VT-14 session TTL policy
#   VT-05 no user-managed SA keys     VT-15 Pub/Sub topics + guard subscription
#   VT-06 runner project roles        VT-16 budget -> ectwin-budget-alerts
#   VT-07 broker has no project role  VT-17 secret placeholders + accessor
#   VT-08 broker binding on runner    VT-18 Earth Engine registration state
#   VT-09 dataset ectwin (US)         VT-19 org policy domain restriction (info)
#   VT-10 dataset ectwin_scratch      VT-20 runner impersonation test (--impersonate)
#
# Usage:  scripts/verify-tenant.sh --project PROJECT_ID [options]
# Exit:   0 no FAIL (WARN allowed unless --strict); 1 at least one FAIL; 2 usage.
# =============================================================================
set -euo pipefail

readonly VERSION="0.1.0"
readonly SCRIPT_NAME="${0##*/}"
readonly DEFAULT_BROKER_SA="ectwin-broker@ectwin-platform-prod.iam.gserviceaccount.com"
readonly TOKEN_CREATOR_ROLE="roles/iam.serviceAccountTokenCreator"

PROJECT_ID="${PROJECT_ID:-}"
PLATFORM_SA="${PLATFORM_SA-$DEFAULT_BROKER_SA}"
EXPECT_BROKER=true
BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"
BQ_LOCATION="${BQ_LOCATION:-US}"
GCS_LOCATION="${GCS_LOCATION:-us-central1}"
FIRESTORE_LOCATION="${FIRESTORE_LOCATION:-southamerica-west1}"
ENABLE_VERTEX=false
ENABLE_BATCH=false
ENABLE_MANAGED_PIPELINES=false
ENABLE_FLOOD_API=false
IMPERSONATE=false
JSON_OUT=false
STRICT=false

PROJECT_NUMBER=""
SA_EMAIL=""
TOKEN=""
TMP_DIR=""
BODY=""
CODE=""
N_PASS=0
N_WARN=0
N_FAIL=0
N_INFO=0

usage() {
  cat <<EOF
${SCRIPT_NAME} v${VERSION} - read-only checks of a GDE-Nino tenant project

Usage: ${SCRIPT_NAME} --project PROJECT_ID [options]

  --project ID              Tenant project (env PROJECT_ID)
  --platform-sa EMAIL       Expected broker SA (default ${DEFAULT_BROKER_SA})
  --no-broker               Expect NO broker binding (path D, or after revocation)
  --billing-account ID      Billing account for the budget check (default: the linked one)
  --bq-location LOC         Expected BigQuery location (default US)
  --gcs-location REGION     Expected bucket region (default us-central1)
  --firestore-location LOC  Expected Firestore location (default southamerica-west1)
  --enable-vertex | --enable-batch | --enable-managed-pipelines | --enable-flood-api
                            Expect the matching APIs/roles (same flags as bootstrap-tenant.sh)
  --impersonate             Also mint a runner token and test it (caller needs TokenCreator
                            on ectwin-runner: normally only the platform operator)
  --json                    Print a machine-readable JSON report at the end
  --strict                  Treat WARN as failure (exit 1)
  -h, --help                This help
EOF
}

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
# shellcheck disable=SC2329 # invoked through the EXIT trap
cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then rm -rf "${TMP_DIR}"; fi
}
trap cleanup EXIT

record() { # STATUS ID MESSAGE
  local status=$1 id=$2 msg=$3
  printf '[%-4s] %s  %s\n' "$status" "$id" "$msg"
  printf '%s\t%s\t%s\n' "$id" "$status" "$msg" >>"${TMP_DIR}/results.tsv"
  case "$status" in
  PASS) N_PASS=$((N_PASS + 1)) ;;
  WARN) N_WARN=$((N_WARN + 1)) ;;
  FAIL) N_FAIL=$((N_FAIL + 1)) ;;
  *) N_INFO=$((N_INFO + 1)) ;;
  esac
}
pass() { record PASS "$@"; }
warn() { record WARN "$@"; }
fail() { record FAIL "$@"; }
info() { record INFO "$@"; }
die() {
  printf 'ERROR %s\n' "$*" >&2
  exit 2
}

# py EXPR  - evaluate a Python expression over JSON on stdin (d) and extra args (a)
py() {
  local expr=$1
  shift
  python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw) if raw.strip() else {}
except Exception:
    d = {}
a = sys.argv[2:]
try:
    v = eval(sys.argv[1], {"d": d, "a": a})
except Exception:
    v = ""
if isinstance(v, bool):
    print("true" if v else "false")
elif isinstance(v, (dict, list)):
    print(json.dumps(v))
elif v is None:
    print("")
else:
    print(v)
' "$expr" "$@"
}

# http METHOD URL [BODY] [TOKEN] -> sets globals CODE and BODY (never exits)
http() {
  local method=$1 url=$2 data=${3:-} tok=${4:-$TOKEN}
  local out="${TMP_DIR}/resp.json"
  local args=(-sS -o "$out" -w '%{http_code}' -X "$method"
    -H "Authorization: Bearer ${tok}" -H "x-goog-user-project: ${PROJECT_ID}")
  if [[ -n "$data" ]]; then args+=(-H "Content-Type: application/json" -d "$data"); fi
  CODE="$(curl "${args[@]}" "$url" 2>/dev/null || true)"
  [[ -n "$CODE" ]] || CODE="000"
  BODY="$(cat "$out" 2>/dev/null || true)"
}

err_msg() { py 'd.get("error",{}).get("message","")[:160]' <<<"$BODY"; }

# ----------------------------------------------------------------------------
# Arguments
# ----------------------------------------------------------------------------
while (($#)); do
  case "$1" in
  --project) PROJECT_ID="${2:?}"; shift 2 ;;
  --platform-sa) PLATFORM_SA="${2:?}"; shift 2 ;;
  --no-broker) EXPECT_BROKER=false; shift ;;
  --billing-account) BILLING_ACCOUNT="${2:?}"; shift 2 ;;
  --bq-location) BQ_LOCATION="${2:?}"; shift 2 ;;
  --gcs-location) GCS_LOCATION="${2:?}"; shift 2 ;;
  --firestore-location) FIRESTORE_LOCATION="${2:?}"; shift 2 ;;
  --enable-vertex) ENABLE_VERTEX=true; shift ;;
  --enable-batch) ENABLE_BATCH=true; shift ;;
  --enable-managed-pipelines) ENABLE_MANAGED_PIPELINES=true; shift ;;
  --enable-flood-api) ENABLE_FLOOD_API=true; shift ;;
  --impersonate) IMPERSONATE=true; shift ;;
  --json) JSON_OUT=true; shift ;;
  --strict) STRICT=true; shift ;;
  -h | --help) usage; exit 0 ;;
  *) printf 'Unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$PROJECT_ID" ]] || { usage >&2; exit 2; }
[[ "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || die "invalid project id: ${PROJECT_ID}"
if [[ -z "$PLATFORM_SA" ]]; then EXPECT_BROKER=false; fi
for c in gcloud curl python3; do
  command -v "$c" >/dev/null 2>&1 || die "missing command '${c}'"
done

TMP_DIR="$(mktemp -d)"
: >"${TMP_DIR}/results.tsv"
SA_EMAIL="ectwin-runner@${PROJECT_ID}.iam.gserviceaccount.com"
TOKEN="$(gcloud auth print-access-token 2>/dev/null)" || die "no gcloud credentials; run: gcloud auth login"
BUCKET="${PROJECT_ID}-ectwin"

printf '%s v%s - project %s - %s\n\n' "$SCRIPT_NAME" "$VERSION" "$PROJECT_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ----------------------------------------------------------------------------
# VT-01 / VT-02 project and billing
# ----------------------------------------------------------------------------
if pj="$(gcloud projects describe "$PROJECT_ID" --format=json 2>/dev/null)"; then
  PROJECT_NUMBER="$(py 'd.get("projectNumber","")' <<<"$pj")"
  state="$(py 'd.get("lifecycleState","")' <<<"$pj")"
  if [[ "$state" == "ACTIVE" ]]; then
    pass VT-01 "project ${PROJECT_ID} (${PROJECT_NUMBER}) is ACTIVE"
  else
    fail VT-01 "project state is ${state:-unknown}"
  fi
else
  fail VT-01 "cannot read project ${PROJECT_ID}"
  printf '\nCannot continue without project access.\n'
  exit 1
fi

if bj="$(gcloud billing projects describe "$PROJECT_ID" --format=json 2>/dev/null)"; then
  linked="$(py 'd.get("billingAccountName","").split("/")[-1]' <<<"$bj")"
  if [[ "$(py 'd.get("billingEnabled", False)' <<<"$bj")" == "true" ]]; then
    pass VT-02 "billing enabled (account ${linked})"
  else
    fail VT-02 "billing is NOT enabled"
  fi
  [[ -n "$BILLING_ACCOUNT" ]] || BILLING_ACCOUNT="$linked"
else
  warn VT-02 "cannot read billing info (needs billing viewer rights)"
fi

# ----------------------------------------------------------------------------
# VT-03 APIs
# ----------------------------------------------------------------------------
required=(serviceusage.googleapis.com cloudresourcemanager.googleapis.com iam.googleapis.com
  iamcredentials.googleapis.com bigquery.googleapis.com bigquerystorage.googleapis.com
  analyticshub.googleapis.com storage.googleapis.com firestore.googleapis.com run.googleapis.com
  cloudscheduler.googleapis.com workflows.googleapis.com pubsub.googleapis.com
  secretmanager.googleapis.com logging.googleapis.com monitoring.googleapis.com
  earthengine.googleapis.com billingbudgets.googleapis.com cloudquotas.googleapis.com)
if [[ "$ENABLE_VERTEX" == "true" ]]; then required+=(aiplatform.googleapis.com); fi
if [[ "$ENABLE_BATCH" == "true" ]]; then required+=(batch.googleapis.com compute.googleapis.com); fi
if [[ "$ENABLE_FLOOD_API" == "true" ]]; then required+=(floodforecasting.googleapis.com); fi
enabled="$(gcloud services list --enabled --project="$PROJECT_ID" --format='value(config.name)' 2>/dev/null || true)"
missing=()
for s in "${required[@]}"; do grep -qx "$s" <<<"$enabled" || missing+=("$s"); done
if ((${#missing[@]} == 0)); then
  pass VT-03 "all ${#required[@]} required APIs enabled"
else
  fail VT-03 "missing APIs: ${missing[*]}"
fi

# ----------------------------------------------------------------------------
# VT-04 / VT-05 runner service account
# ----------------------------------------------------------------------------
runner_ok=false
if sa="$(gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" --format=json 2>/dev/null)"; then
  if [[ "$(py 'd.get("disabled", False)' <<<"$sa")" == "true" ]]; then
    fail VT-04 "${SA_EMAIL} exists but is DISABLED (pipelines and broker calls will fail)"
  else
    pass VT-04 "${SA_EMAIL} exists and is enabled (uniqueId $(py 'd.get("uniqueId","")' <<<"$sa"))"
    runner_ok=true
  fi
  keys="$(gcloud iam service-accounts keys list --iam-account="$SA_EMAIL" --project="$PROJECT_ID" --managed-by=user --format='value(name)' 2>/dev/null || true)"
  if [[ -z "$keys" ]]; then
    pass VT-05 "no user-managed keys on ${SA_EMAIL} (AP-06)"
  else
    fail VT-05 "user-managed keys exist on ${SA_EMAIL}: delete them (the design needs none)"
  fi
else
  fail VT-04 "${SA_EMAIL} not found"
  info VT-05 "skipped (no runner)"
fi

# ----------------------------------------------------------------------------
# VT-06 / VT-07 project IAM
# ----------------------------------------------------------------------------
expected_roles=(roles/bigquery.jobUser roles/bigquery.readSessionUser roles/serviceusage.serviceUsageConsumer
  roles/earthengine.writer roles/datastore.user roles/run.invoker roles/logging.logWriter)
if [[ "$ENABLE_VERTEX" == "true" ]]; then expected_roles+=(roles/aiplatform.user); fi
if [[ "$ENABLE_BATCH" == "true" ]]; then expected_roles+=(roles/batch.jobsEditor roles/batch.agentReporter); fi
if [[ "$ENABLE_MANAGED_PIPELINES" == "true" ]]; then
  expected_roles+=(roles/run.developer roles/cloudscheduler.admin roles/pubsub.editor)
fi
if policy="$(gcloud projects get-iam-policy "$PROJECT_ID" --format=json 2>/dev/null)"; then
  have="$(py '" ".join(sorted({b["role"] for b in d.get("bindings",[]) if a[0] in b.get("members",[])}))' "serviceAccount:${SA_EMAIL}" <<<"$policy")"
  miss=()
  for r in "${expected_roles[@]}"; do [[ " $have " == *" $r "* ]] || miss+=("$r"); done
  extra=()
  for r in $have; do [[ " ${expected_roles[*]} " == *" $r "* ]] || extra+=("$r"); done
  broad=()
  for r in "${extra[@]}"; do
    case "$r" in roles/owner | roles/editor | roles/*.admin | roles/iam.*) broad+=("$r") ;; esac
  done
  if ((${#miss[@]})); then
    fail VT-06 "runner is missing project roles: ${miss[*]}"
  elif ((${#broad[@]})); then
    fail VT-06 "runner holds broad roles beyond the least-privilege matrix: ${broad[*]}"
  elif ((${#extra[@]})); then
    warn VT-06 "runner has ${#expected_roles[@]} expected roles plus extra: ${extra[*]}"
  else
    pass VT-06 "runner holds exactly the ${#expected_roles[@]} expected project roles"
  fi
  if [[ -n "$PLATFORM_SA" ]]; then
    broker_roles="$(py '" ".join(sorted({b["role"] for b in d.get("bindings",[]) if a[0] in b.get("members",[])}))' "serviceAccount:${PLATFORM_SA}" <<<"$policy")"
    if [[ -z "$broker_roles" ]]; then
      pass VT-07 "broker has no project-level role (only the SA-level grant)"
    else
      fail VT-07 "broker holds project-level roles it must not have: ${broker_roles}"
    fi
  fi
else
  warn VT-06 "cannot read project IAM policy (needs resourcemanager.projects.getIamPolicy)"
fi

# ----------------------------------------------------------------------------
# VT-08 broker binding on the runner SA only
# ----------------------------------------------------------------------------
if [[ "$runner_ok" == "true" ]] && sapol="$(gcloud iam service-accounts get-iam-policy "$SA_EMAIL" --project="$PROJECT_ID" --format=json 2>/dev/null)"; then
  has_broker="false"
  if [[ -n "$PLATFORM_SA" ]]; then
    has_broker="$(py 'any(b["role"]==a[0] and a[1] in b.get("members",[]) for b in d.get("bindings",[]))' "$TOKEN_CREATOR_ROLE" "serviceAccount:${PLATFORM_SA}" <<<"$sapol")"
  fi
  others="$(py '" ".join(sorted({m for b in d.get("bindings",[]) if b["role"] in ("roles/iam.serviceAccountTokenCreator","roles/iam.serviceAccountUser","roles/owner","roles/iam.serviceAccountAdmin") for m in b.get("members",[]) if m not in (a[0], a[1])}))' "serviceAccount:${PLATFORM_SA}" "serviceAccount:${SA_EMAIL}" <<<"$sapol")"
  if [[ "$EXPECT_BROKER" == "true" ]]; then
    if [[ "$has_broker" == "true" ]]; then
      pass VT-08 "${TOKEN_CREATOR_ROLE} on ${SA_EMAIL} -> ${PLATFORM_SA}"
    else
      fail VT-08 "broker binding missing: the platform cannot connect (re-run the bootstrap; check domain-restricted sharing)"
    fi
  else
    if [[ "$has_broker" == "true" ]]; then
      fail VT-08 "broker binding still present although --no-broker was requested"
    else
      pass VT-08 "no broker binding (path D or revoked)"
    fi
  fi
  if [[ -n "$others" ]]; then
    warn VT-08 "other principals can impersonate or act as ${SA_EMAIL}: ${others}"
  fi
else
  info VT-08 "skipped (runner missing or SA policy unreadable)"
fi

# ----------------------------------------------------------------------------
# VT-09 / VT-10 / VT-11 BigQuery
# ----------------------------------------------------------------------------
check_dataset() { # ID CHECK_ID EXPECT_EXPIRY_MS
  local ds=$1 id=$2 exp=${3:-}
  http GET "https://bigquery.googleapis.com/bigquery/v2/projects/${PROJECT_ID}/datasets/${ds}"
  if [[ "$CODE" != "200" ]]; then
    fail "$id" "dataset ${ds} not readable (HTTP ${CODE}) $(err_msg)"
    return 0
  fi
  local loc writer expiry
  loc="$(py 'd.get("location","")' <<<"$BODY")"
  writer="$(py 'any((x.get("userByEmail")==a[0] or x.get("iamMember")=="serviceAccount:"+a[0]) and x.get("role") in ("WRITER","roles/bigquery.dataEditor","OWNER","roles/bigquery.dataOwner") for x in d.get("access",[]))' "$SA_EMAIL" <<<"$BODY")"
  expiry="$(py 'd.get("defaultTableExpirationMs","")' <<<"$BODY")"
  if [[ "$loc" != "$BQ_LOCATION" ]]; then
    fail "$id" "dataset ${ds} is in ${loc}, expected ${BQ_LOCATION} (joins with WeatherNext/Commons will fail)"
  elif [[ "$writer" != "true" ]]; then
    fail "$id" "dataset ${ds} (${loc}) lacks dataEditor/WRITER for ${SA_EMAIL}"
  elif [[ -n "$exp" && "$expiry" != "$exp" ]]; then
    warn "$id" "dataset ${ds} default table expiration is '${expiry:-none}' ms, expected ${exp}"
  else
    pass "$id" "dataset ${ds} in ${loc}, runner can write${exp:+, tables expire after $((exp / 86400000)) d}"
  fi
  if [[ "$ds" == "ectwin" ]]; then
    local code
    code="$(py 'd.get("labels",{}).get("ectwin-connection","")' <<<"$BODY")"
    if [[ -n "$code" ]]; then info "$id" "connection code label present on ${ds}"; fi
  fi
}
check_dataset ectwin VT-09
check_dataset ectwin_scratch VT-10 604800000

for ds in ectwin_commons ectwin_commons_nc weathernext_3 weathernext_2; do
  http GET "https://bigquery.googleapis.com/bigquery/v2/projects/${PROJECT_ID}/datasets/${ds}"
  if [[ "$CODE" == "200" ]]; then
    linked="$(py '"linkedDatasetSource" in d' <<<"$BODY")"
    reader="$(py 'any((x.get("userByEmail")==a[0] or x.get("iamMember")=="serviceAccount:"+a[0]) and x.get("role") in ("READER","roles/bigquery.dataViewer") for x in d.get("access",[]))' "$SA_EMAIL" <<<"$BODY")"
    loc="$(py 'd.get("location","")' <<<"$BODY")"
    if [[ "$reader" != "true" ]]; then
      warn VT-11 "${ds} present (linked=${linked}, ${loc}) but runner has no dataViewer: add it to linked_dataset_ids and re-apply"
    else
      pass VT-11 "${ds} present (linked=${linked}, ${loc}); runner can read"
    fi
  elif [[ "$CODE" == "404" ]]; then
    info VT-11 "${ds} not subscribed yet"
  else
    warn VT-11 "${ds}: HTTP ${CODE} $(err_msg)"
  fi
done

# ----------------------------------------------------------------------------
# VT-12 bucket
# ----------------------------------------------------------------------------
http GET "https://storage.googleapis.com/storage/v1/b/${BUCKET}"
if [[ "$CODE" == "200" ]]; then
  problems="$(py '"; ".join(p for p in [
      "location " + d.get("location","") + " != " + a[0].upper() if d.get("location","").upper() != a[0].upper() else "",
      "uniform bucket-level access OFF" if not d.get("iamConfiguration",{}).get("uniformBucketLevelAccess",{}).get("enabled") else "",
      "public access prevention not enforced" if d.get("iamConfiguration",{}).get("publicAccessPrevention") != "enforced" else "",
      "soft delete < 7 d" if int(d.get("softDeletePolicy",{}).get("retentionDurationSeconds","0") or 0) < 604800 else "",
      "no scratch/ delete rule" if not any(r.get("action",{}).get("type")=="Delete" and "scratch/" in r.get("condition",{}).get("matchesPrefix",[]) for r in d.get("lifecycle",{}).get("rule",[])) else "",
      "no NEARLINE rule" if not any(r.get("action",{}).get("storageClass")=="NEARLINE" for r in d.get("lifecycle",{}).get("rule",[])) else "",
      "requester pays ON" if d.get("billing",{}).get("requesterPays") else ""] if p)' "$GCS_LOCATION" <<<"$BODY")"
  if [[ -z "$problems" ]]; then
    pass VT-12 "gs://${BUCKET}: $(py 'd.get("location","")' <<<"$BODY"), uniform access, PAP enforced, soft delete, lifecycle OK"
  else
    fail VT-12 "gs://${BUCKET}: ${problems}"
  fi
  http GET "https://storage.googleapis.com/storage/v1/b/${BUCKET}/iam"
  if [[ "$CODE" == "200" ]]; then
    public="$(py 'any(m in ("allUsers","allAuthenticatedUsers") for b in d.get("bindings",[]) for m in b.get("members",[]))' <<<"$BODY")"
    admin="$(py 'any(b["role"]=="roles/storage.objectAdmin" and a[0] in b.get("members",[]) for b in d.get("bindings",[]))' "serviceAccount:${SA_EMAIL}" <<<"$BODY")"
    if [[ "$public" == "true" ]]; then
      fail VT-12 "gs://${BUCKET} has a public IAM binding"
    elif [[ "$admin" != "true" ]]; then
      fail VT-12 "gs://${BUCKET}: runner lacks roles/storage.objectAdmin"
    else
      pass VT-12 "gs://${BUCKET} IAM: runner objectAdmin, no public members"
    fi
  else
    warn VT-12 "cannot read bucket IAM (HTTP ${CODE})"
  fi
else
  fail VT-12 "bucket gs://${BUCKET} not readable (HTTP ${CODE}) $(err_msg)"
fi

# ----------------------------------------------------------------------------
# VT-13 / VT-14 Firestore
# ----------------------------------------------------------------------------
http GET "https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)"
if [[ "$CODE" == "200" ]]; then
  ftype="$(py 'd.get("type","")' <<<"$BODY")"
  floc="$(py 'd.get("locationId","")' <<<"$BODY")"
  fprot="$(py 'd.get("deleteProtectionState","")' <<<"$BODY")"
  if [[ "$ftype" != "FIRESTORE_NATIVE" ]]; then
    fail VT-13 "Firestore (default) is ${ftype}, expected FIRESTORE_NATIVE"
  elif [[ "$floc" != southamerica-* ]]; then
    warn VT-13 "Firestore (default) in ${floc}: personal data outside southamerica-* needs an LOPDP review (FR-013)"
  elif [[ "$floc" != "$FIRESTORE_LOCATION" ]]; then
    warn VT-13 "Firestore (default) in ${floc}, expected ${FIRESTORE_LOCATION} (record the actual region in the registry)"
  else
    pass VT-13 "Firestore (default) FIRESTORE_NATIVE in ${floc} (${fprot:-protection unknown})"
  fi
  http GET "https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/collectionGroups/sessions/fields/expire_at"
  ttl="$(py 'd.get("ttlConfig",{}).get("state","")' <<<"$BODY")"
  case "$ttl" in
  ACTIVE) pass VT-14 "TTL policy sessions.expire_at ACTIVE" ;;
  CREATING) info VT-14 "TTL policy sessions.expire_at CREATING (can take a while)" ;;
  *) warn VT-14 "no TTL policy on sessions.expire_at (sessions will not expire after 30 days)" ;;
  esac
else
  fail VT-13 "Firestore (default) not found/readable (HTTP ${CODE}) $(err_msg)"
  info VT-14 "skipped"
fi

# ----------------------------------------------------------------------------
# VT-15 Pub/Sub
# ----------------------------------------------------------------------------
ps_missing=()
for r in topics/ectwin-budget-alerts topics/ectwin-notify subscriptions/ectwin-budget-alerts-guard; do
  http GET "https://pubsub.googleapis.com/v1/projects/${PROJECT_ID}/${r}"
  [[ "$CODE" == "200" ]] || ps_missing+=("${r} (HTTP ${CODE})")
done
if ((${#ps_missing[@]})); then
  fail VT-15 "missing Pub/Sub resources: ${ps_missing[*]}"
else
  pass VT-15 "topics ectwin-budget-alerts, ectwin-notify and subscription ectwin-budget-alerts-guard exist"
  http GET "https://pubsub.googleapis.com/v1/projects/${PROJECT_ID}/topics/ectwin-budget-alerts:getIamPolicy"
  pubs="$(py '" ".join(m for b in d.get("bindings",[]) if b["role"]=="roles/pubsub.publisher" for m in b.get("members",[]))' <<<"$BODY")"
  info VT-15 "publishers on ectwin-budget-alerts: ${pubs:-none listed (Cloud Billing adds its own on budget save - to confirm)}"
fi

# ----------------------------------------------------------------------------
# VT-16 budget
# ----------------------------------------------------------------------------
if [[ -n "$BILLING_ACCOUNT" && -n "$PROJECT_NUMBER" ]]; then
  http GET "https://billingbudgets.googleapis.com/v1/billingAccounts/${BILLING_ACCOUNT}/budgets?pageSize=100"
  if [[ "$CODE" == "200" ]]; then
    found="$(py '[{"name": b.get("displayName",""), "topic": b.get("notificationsRule",{}).get("pubsubTopic",""), "n": len(b.get("thresholdRules",[])), "amount": b.get("amount",{}).get("specifiedAmount",{}).get("units","")} for b in d.get("budgets",[]) if "projects/"+a[0] in b.get("budgetFilter",{}).get("projects",[])][:1]' "$PROJECT_NUMBER" <<<"$BODY")"
    if [[ "$found" == "[]" || -z "$found" ]]; then
      fail VT-16 "no budget scoped to projects/${PROJECT_NUMBER} on ${BILLING_ACCOUNT} (first page only)"
    else
      topic="$(py 'd[0]["topic"]' <<<"$found")"
      if [[ "$topic" == "projects/${PROJECT_ID}/topics/ectwin-budget-alerts" ]]; then
        pass VT-16 "budget $(py 'd[0]["name"]' <<<"$found"): $(py 'd[0]["amount"]' <<<"$found") units, $(py 'd[0]["n"]' <<<"$found") thresholds -> ectwin-budget-alerts"
      else
        warn VT-16 "budget found but notifications go to '${topic:-none}', expected ectwin-budget-alerts"
      fi
    fi
  else
    warn VT-16 "cannot list budgets on ${BILLING_ACCOUNT} (HTTP ${CODE}; needs billing budget viewer rights) - check Billing > Budgets & alerts"
  fi
else
  warn VT-16 "billing account unknown; budget not checked"
fi

# ----------------------------------------------------------------------------
# VT-17 secrets
# ----------------------------------------------------------------------------
for s in typesafe-api-key floodforecasting-api-key; do
  http GET "https://secretmanager.googleapis.com/v1/projects/${PROJECT_ID}/secrets/${s}"
  if [[ "$CODE" != "200" ]]; then
    fail VT-17 "secret ${s} missing (HTTP ${CODE})"
    continue
  fi
  http GET "https://secretmanager.googleapis.com/v1/projects/${PROJECT_ID}/secrets/${s}:getIamPolicy"
  acc="$(py 'any(b["role"]=="roles/secretmanager.secretAccessor" and a[0] in b.get("members",[]) for b in d.get("bindings",[]))' "serviceAccount:${SA_EMAIL}" <<<"$BODY")"
  http GET "https://secretmanager.googleapis.com/v1/projects/${PROJECT_ID}/secrets/${s}/versions?filter=state:ENABLED"
  nver="$(py 'len(d.get("versions",[]))' <<<"$BODY")"
  if [[ "$acc" == "true" ]]; then
    pass VT-17 "secret ${s} exists, runner can access, enabled versions: ${nver:-0}"
  else
    fail VT-17 "secret ${s} exists but runner lacks secretAccessor"
  fi
done

# ----------------------------------------------------------------------------
# VT-18 Earth Engine registration (browser step; API field is output-only)
# ----------------------------------------------------------------------------
http GET "https://earthengine.googleapis.com/v1/projects/${PROJECT_ID}/config"
if [[ "$CODE" == "200" ]]; then
  reg="$(py 'd.get("registrationState","")' <<<"$BODY")"
  case "$reg" in
  REGISTERED_COMMERCIALLY) pass VT-18 "Earth Engine: REGISTERED_COMMERCIALLY" ;;
  REGISTERED_NOT_COMMERCIALLY) pass VT-18 "Earth Engine: REGISTERED_NOT_COMMERCIALLY (noncommercial tier; re-verify yearly; operational government use may need commercial)" ;;
  NOT_REGISTERED | "") warn VT-18 "Earth Engine NOT registered: https://code.earthengine.google.com/register?project=${PROJECT_ID}" ;;
  *) info VT-18 "Earth Engine registrationState=${reg}" ;;
  esac
else
  warn VT-18 "Earth Engine config not readable (HTTP ${CODE}) $(err_msg)"
fi

# ----------------------------------------------------------------------------
# VT-19 org policy (information only)
# ----------------------------------------------------------------------------
drs="none detected"
for c in iam.allowedPolicyMemberDomains iam.managed.allowedPolicyMembers; do
  if pol="$(gcloud org-policies describe "$c" --project="$PROJECT_ID" --effective --format=json 2>/dev/null)"; then
    if grep -Eq '"allowedValues"|"enforce": *true' <<<"$pol"; then drs="${c} active"; fi
  fi
done
info VT-19 "domain-restricted sharing: ${drs}"

# ----------------------------------------------------------------------------
# VT-20 impersonation test (optional; operator or anyone with TokenCreator)
# ----------------------------------------------------------------------------
if [[ "$IMPERSONATE" == "true" ]]; then
  if rtok="$(gcloud auth print-access-token --impersonate-service-account="$SA_EMAIL" 2>/dev/null)"; then
    http POST "https://bigquery.googleapis.com/bigquery/v2/projects/${PROJECT_ID}/jobs" \
      '{"configuration":{"dryRun":true,"query":{"query":"SELECT 1","useLegacySql":false}}}' "$rtok"
    if [[ "$CODE" == "200" ]]; then
      pass VT-20 "runner token works: BigQuery dry run billed to ${PROJECT_ID}"
    else
      fail VT-20 "runner token cannot run a BigQuery dry run (HTTP ${CODE}) $(err_msg)"
    fi
    http POST "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:testIamPermissions" \
      '{"permissions":["resourcemanager.projects.setIamPolicy","iam.serviceAccountKeys.create","iam.serviceAccounts.create","storage.buckets.delete","bigquery.datasets.delete","resourcemanager.projects.delete"]}' "$rtok"
    danger="$(py '" ".join(d.get("permissions",[]))' <<<"$BODY")"
    if [[ "$CODE" == "200" && -z "$danger" ]]; then
      pass VT-20 "runner cannot change IAM, create keys/accounts or delete buckets, datasets or the project"
    elif [[ "$CODE" == "200" ]]; then
      fail VT-20 "runner holds dangerous permissions: ${danger}"
    else
      warn VT-20 "could not test runner permissions (HTTP ${CODE})"
    fi
  else
    warn VT-20 "cannot impersonate ${SA_EMAIL} with the current account (expected unless you are the platform operator)"
  fi
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
printf '\nSummary: %d PASS, %d WARN, %d FAIL, %d INFO\n' "$N_PASS" "$N_WARN" "$N_FAIL" "$N_INFO"
if [[ "$JSON_OUT" == "true" ]]; then
  python3 - "${TMP_DIR}/results.tsv" "$PROJECT_ID" "$VERSION" "$N_PASS" "$N_WARN" "$N_FAIL" "$N_INFO" <<'PY'
import json, sys, datetime
path, project, version, p, w, f, i = sys.argv[1:8]
rows = [l.rstrip("\n").split("\t", 2) for l in open(path) if l.strip()]
print(json.dumps({
    "project_id": project, "verifier_version": version,
    "checked_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "summary": {"pass": int(p), "warn": int(w), "fail": int(f), "info": int(i)},
    "results": [{"id": r[0], "status": r[1], "message": r[2]} for r in rows]}, indent=2))
PY
fi
if ((N_FAIL > 0)); then exit 1; fi
if [[ "$STRICT" == "true" ]] && ((N_WARN > 0)); then exit 1; fi
exit 0
