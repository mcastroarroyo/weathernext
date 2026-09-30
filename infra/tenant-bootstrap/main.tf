# -----------------------------------------------------------------------------
# main.tf - resources created in the TENANT project by the GDE-Nino bootstrap.
#
# Design references (do not re-describe here):
#   docs/03-architecture.md  sections 2.4 (trust boundaries), 4.3-4.5 (broker,
#                            scheduled pipelines, notifications), 5.1 (buckets),
#                            5.2/5.4 (BigQuery), 5.6 (tenant Firestore)
#   docs/04-identity-tenancy-byo-gcp.md (connection paths A-D)
#
# What the platform gets: exactly ONE binding - roles/iam.serviceAccountTokenCreator
# on the ectwin-runner service-account resource (not on the project), granted to
# the platform broker. Everything the broker can do is therefore bounded by the
# roles ectwin-runner holds below.
# -----------------------------------------------------------------------------

locals {
  bootstrap_version = "0.1.0"

  runner_account_id = "ectwin-runner"
  bucket_name       = coalesce(var.bucket_name_override, "${var.project_id}-ectwin")
  project_number    = var.project_number != null ? var.project_number : data.google_project.this.number

  labels = merge(
    {
      app              = "ectwin"
      plane            = "tenant"
      managed-by       = "terraform"
      ectwin-bootstrap = replace(local.bootstrap_version, ".", "-")
      ectwin-tier      = lower(var.tier)
    },
    var.labels,
  )

  # --- APIs -------------------------------------------------------------------
  base_services = [
    "serviceusage.googleapis.com",         # enable/inspect APIs; quota-project checks
    "cloudresourcemanager.googleapis.com", # project IAM policy (Terraform, preflight)
    "iam.googleapis.com",                  # service accounts and SA-level IAM
    "iamcredentials.googleapis.com",       # generateAccessToken / signBlob for the broker
    "bigquery.googleapis.com",             # ectwin datasets, jobs billed to the tenant
    "bigquerystorage.googleapis.com",      # Storage Read API (to_dataframe, Xee/pandas)
    "analyticshub.googleapis.com",         # linked datasets: Commons + WeatherNext
    "storage.googleapis.com",              # gs://<project>-ectwin, Requester-Pays reads
    "firestore.googleapis.com",            # (default) database: sessions, AOIs, runs
    "run.googleapis.com",                  # Cloud Run jobs (tenant pipelines)
    "cloudscheduler.googleapis.com",       # pipeline triggers
    "workflows.googleapis.com",            # T2+ multi-step tenant pipelines
    "pubsub.googleapis.com",               # budget alerts, notify topic, Commons events
    "secretmanager.googleapis.com",        # tenant-owned third-party keys
    "logging.googleapis.com",              # job logs
    "monitoring.googleapis.com",           # metrics / notification channels
    "earthengine.googleapis.com",          # EE (registration is a separate browser step)
    "billingbudgets.googleapis.com",       # project-scoped budget
    "cloudquotas.googleapis.com",          # BigQuery / EE custom quotas
  ]

  services = toset(concat(
    local.base_services,
    var.enable_vertex ? ["aiplatform.googleapis.com"] : [],
    var.enable_batch ? ["batch.googleapis.com", "compute.googleapis.com"] : [],
    var.enable_flood_forecasting_api ? ["floodforecasting.googleapis.com"] : [],
    var.extra_services,
  ))

  # --- Least-privilege project-level roles for ectwin-runner ------------------
  # Map value = justification (also exported in outputs.iam_matrix so the web
  # app can show the tenant exactly what it granted). Data access is granted at
  # dataset / bucket / secret level further below, never project-wide.
  runner_project_roles = merge(
    {
      # Create BigQuery jobs (queries, loads, extracts) billed to THIS project.
      # Grants no data access by itself.
      "roles/bigquery.jobUser" = "Run BigQuery jobs billed to the tenant; data access is per dataset"

      # Create Storage Read API sessions (Python to_dataframe, Xee); 300 TiB/month free.
      "roles/bigquery.readSessionUser" = "Use the BigQuery Storage Read API for fast reads of permitted tables"

      # serviceusage.services.use: lets the runner (and the broker impersonating it)
      # name this project as quota/billing project (Requester-Pays WN3 reads,
      # x-goog-user-project) and is required by Earth Engine for every call.
      "roles/serviceusage.serviceUsageConsumer" = "Bill API calls and Requester-Pays reads to this project; required by Earth Engine"

      # Earth Engine computations and writing EE assets under this project.
      "roles/earthengine.writer" = "Run Earth Engine computations and write EE assets in this project"

      # Read/write documents in Firestore (default): sessions, AOIs, runs,
      # notifications. Could later be narrowed with an IAM condition on the
      # database resource name.
      "roles/datastore.user" = "Read and write the tenant Firestore documents (sessions, AOIs, runs)"

      # Cloud Scheduler calls the Cloud Run Jobs API as ectwin-runner; executing
      # jobs needs run.jobs.run. Could be narrowed to job-level bindings later.
      "roles/run.invoker" = "Let Scheduler/Workflows (as ectwin-runner) execute the tenant's Cloud Run jobs"

      # Cloud Run jobs and Batch VMs running as ectwin-runner write their logs.
      "roles/logging.logWriter" = "Write logs from jobs that run as ectwin-runner"
    },

    # T3: WN2 on-demand scenario runs (Vertex custom jobs) and Gemini calls.
    var.enable_vertex ? {
      "roles/aiplatform.user" = "Submit Vertex AI (Gemini Enterprise Agent Platform) custom jobs and Gemini requests"
    } : {},

    # T3: SFINCS / LISFLOOD-FP campaigns on Spot VMs.
    var.enable_batch ? {
      "roles/batch.jobsEditor"    = "Submit and manage Cloud Batch jobs (heavy hydraulic runs on Spot VMs)"
      "roles/batch.agentReporter" = "Let Batch VMs that run as ectwin-runner report task status"
    } : {},

    # Optional: platform-managed pipelines (off by default).
    var.enable_managed_pipelines ? {
      "roles/run.developer"        = "Create/update tenant Cloud Run jobs from platform images after Owner approval"
      "roles/cloudscheduler.admin" = "Create, update and pause tenant Scheduler jobs (budget guard pauses jobs)"
      "roles/pubsub.editor"        = "Create the tenant subscription to Commons topics and manage tenant topics"
    } : {},
  )

  # Submitting Batch / Vertex jobs or deploying Cloud Run jobs that run AS
  # ectwin-runner requires iam.serviceAccounts.actAs on ectwin-runner itself.
  runner_needs_self_act_as = var.enable_batch || var.enable_vertex || var.enable_managed_pipelines

  linked_dataset_ids = toset(concat(var.linked_dataset_ids, keys(var.listing_subscriptions)))
}

data "google_project" "this" {
  project_id = var.project_id
}

# -----------------------------------------------------------------------------
# Guard rails evaluated at plan time (warnings, never blocking)
# -----------------------------------------------------------------------------

check "project_number_matches" {
  assert {
    condition     = var.project_number == null || var.project_number == data.google_project.this.number
    error_message = "project_number does not match the number of project_id; the budget filter would target another project."
  }
}

check "firestore_residency" {
  assert {
    condition     = startswith(var.firestore_location, "southamerica-")
    error_message = "Firestore holds personal and session data. A location outside southamerica-* needs an LOPDP cross-border review (FR-013, docs/13-governance-legal-risk.md)."
  }
}

check "bucket_colocation" {
  assert {
    condition     = var.gcs_location == "us-central1"
    error_message = "gcs_location differs from us-central1: BigQuery US reads us-central1 buckets without transfer charge and us-central1 is in the GCS Always Free zone (D10)."
  }
}

# -----------------------------------------------------------------------------
# 1. APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "apis" {
  for_each = local.services

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false # never break a live tenant on destroy
  disable_dependent_services = false
}

# -----------------------------------------------------------------------------
# 2. Runner service account and its IAM
# -----------------------------------------------------------------------------

resource "google_service_account" "runner" {
  project      = var.project_id
  account_id   = local.runner_account_id
  display_name = "GDE-Nino runner (ectwin-runner)"
  description  = "Runs GDE-Nino tenant pipelines and is impersonated by the platform broker with <=15 min tokens. Bootstrap v${local.bootstrap_version}."

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "runner" {
  for_each = local.runner_project_roles

  project = var.project_id
  role    = each.key
  member  = google_service_account.runner.member
}

# THE single grant to the platform (D8): TokenCreator on the runner SA resource
# only. Lets ectwin-broker call generateAccessToken / signBlob for
# ectwin-runner; it does NOT give the broker any role on the project.
# Removing this binding disconnects the platform (at most one <=15-min token
# stays valid).
resource "google_service_account_iam_member" "broker_token_creator" {
  count = var.platform_broker_sa == "" ? 0 : 1

  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.platform_broker_sa}"
}

# actAs on itself, only when jobs must RUN AS ectwin-runner (Batch, Vertex,
# managed Cloud Run deployments). Scoped to this one service account.
resource "google_service_account_iam_member" "runner_self_act_as" {
  count = local.runner_needs_self_act_as ? 1 : 0

  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.runner.member
}

# -----------------------------------------------------------------------------
# 3. BigQuery datasets (location US, D10)
# -----------------------------------------------------------------------------

resource "google_bigquery_dataset" "ectwin" {
  project                    = var.project_id
  dataset_id                 = "ectwin"
  location                   = var.bq_location
  friendly_name              = "GDE-Nino tenant data"
  description                = "Curated tenant data and outputs (aoi, session, run, subscription, decision_log, audit_events, ...). Schemas: schemas/bigquery/tenant/."
  delete_contents_on_destroy = false # destroy fails while tables exist: protects tenant data

  labels = merge(
    { component = "curated" },
    var.connection_code == "" ? {} : { ectwin-connection = var.connection_code },
  )

  lifecycle {
    precondition {
      condition     = var.bq_location == "US" || var.allow_non_us_bigquery
      error_message = "bq_location must be US: WeatherNext and Commons linked datasets are in US and BigQuery jobs cannot mix locations (D10, FR-013)."
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_dataset" "scratch" {
  project                     = var.project_id
  dataset_id                  = "ectwin_scratch"
  location                    = var.bq_location
  friendly_name               = "GDE-Nino scratch"
  description                 = "Temporary results; tables expire automatically."
  default_table_expiration_ms = var.scratch_table_expiration_days * 24 * 60 * 60 * 1000
  max_time_travel_hours       = "48" # minimum window: scratch data is disposable
  delete_contents_on_destroy  = true

  labels = { component = "scratch" }

  lifecycle {
    precondition {
      condition     = var.bq_location == "US" || var.allow_non_us_bigquery
      error_message = "bq_location must be US (D10, FR-013)."
    }
  }

  depends_on = [google_project_service.apis]
}

# Dataset-level (not project-level) write access for the runner.
resource "google_bigquery_dataset_iam_member" "runner_editor" {
  for_each = {
    ectwin         = google_bigquery_dataset.ectwin.dataset_id
    ectwin_scratch = google_bigquery_dataset.scratch.dataset_id
  }

  project    = var.project_id
  dataset_id = each.value
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.runner.member
}

# Optional second pass: Analytics Hub subscriptions -> read-only linked datasets
# (ectwin_commons, weathernext_3, weathernext_2 ...). `project` is the
# PUBLISHER project that owns the data exchange; the linked dataset is created
# in the tenant project, and the subscriber pays for queries.
resource "google_bigquery_analytics_hub_listing_subscription" "this" {
  for_each = var.listing_subscriptions
  provider = google.tenant_quota

  project          = each.value.exchange_project
  location         = each.value.location
  data_exchange_id = each.value.data_exchange_id
  listing_id       = each.value.listing_id

  destination_dataset {
    location      = var.bq_location
    friendly_name = each.key
    description   = "Linked dataset created by the GDE-Nino tenant bootstrap (read-only; subscriber pays queries)."

    dataset_reference {
      project_id = var.project_id
      dataset_id = each.key
    }
  }

  depends_on = [google_project_service.apis]
}

# Read access for the runner on linked datasets (IAM on linked datasets:
# supported per Analytics Hub docs - to confirm on the first pilot tenant).
resource "google_bigquery_dataset_iam_member" "runner_linked_viewer" {
  for_each = local.linked_dataset_ids

  project    = var.project_id
  dataset_id = each.value
  role       = "roles/bigquery.dataViewer"
  member     = google_service_account.runner.member

  depends_on = [google_bigquery_analytics_hub_listing_subscription.this]
}

# OPTIONAL BigQuery daily query quota through Cloud Quotas (default: not
# managed here). quota_id "QueryUsagePerDay" comes from the BigQuery custom
# quota docs; the preferred_value unit (MiB assumed) is **to confirm** with
#   gcloud beta quotas info describe QueryUsagePerDay \
#     --service=bigquery.googleapis.com --project=PROJECT_ID
# before enabling. The quota is approximate and applies to on-demand only.
resource "google_cloud_quotas_quota_preference" "bq_query_usage_per_day" {
  count    = var.bq_query_usage_per_day_mib == null ? 0 : 1
  provider = google.tenant_quota

  parent        = "projects/${var.project_id}"
  name          = "ectwin-bq-query-usage-per-day"
  service       = "bigquery.googleapis.com"
  quota_id      = "QueryUsagePerDay"
  contact_email = var.quota_contact_email
  justification = "GDE-Nino tenant guardrail: cap on-demand BigQuery bytes per day (NFR-018)."

  # Lowering the default (200 TiB/day) by a large percentage trips a safety check.
  ignore_safety_checks = "QUOTA_DECREASE_PERCENTAGE_TOO_HIGH"

  quota_config {
    preferred_value = tostring(var.bq_query_usage_per_day_mib)
  }

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 4. Tenant bucket gs://<project>-ectwin (docs/03 section 5.1)
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "ectwin" {
  project                     = var.project_id
  name                        = local.bucket_name
  location                    = upper(var.gcs_location)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false # never delete tenant files on destroy

  labels = { component = "tenant-files" }

  versioning {
    enabled = false # soft delete protects against accidental deletes at lower cost
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_days * 24 * 60 * 60
  }

  # scratch/ is disposable.
  lifecycle_rule {
    condition {
      age            = var.scratch_retention_days
      matches_prefix = ["scratch/"]
    }
    action {
      type = "Delete"
    }
  }

  # Cold outputs (run artefacts, reports, evidence, exports, raw uploads) age
  # into NEARLINE. tiles/, curated/ and catalog/ stay STANDARD (read often).
  lifecycle_rule {
    condition {
      age                   = var.nearline_after_days
      matches_prefix        = var.nearline_prefixes
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Housekeeping: abandoned multipart uploads.
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # Browser range reads of tenant PMTiles/COGs through 60-min V4 signed URLs.
  dynamic "cors" {
    for_each = length(var.app_origins) > 0 ? [1] : []
    content {
      origin          = var.app_origins
      method          = ["GET", "HEAD"]
      response_header = ["Content-Type", "Content-Range", "Range", "ETag", "Content-Encoding"]
      max_age_seconds = 3600
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "runner_object_admin" {
  bucket = google_storage_bucket.ectwin.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.runner.member
}

# -----------------------------------------------------------------------------
# 5. Firestore (default), FIRESTORE_NATIVE, southamerica-west1 by default
# -----------------------------------------------------------------------------

resource "google_firestore_database" "default" {
  count = var.create_firestore_database ? 1 : 0

  project                           = var.project_id
  name                              = "(default)"
  location_id                       = var.firestore_location
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = var.firestore_pitr ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state           = var.firestore_delete_protection ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"
  deletion_policy                   = "ABANDON" # terraform destroy never deletes tenant data

  depends_on = [google_project_service.apis]
}

# TTL on users/{uid}/sessions/{sessionId}.expire_at (30-day sessions, docs/03 5.6).
resource "google_firestore_field" "session_ttl" {
  count = var.enable_session_ttl ? 1 : 0

  project    = var.project_id
  database   = "(default)"
  collection = "sessions"
  field      = "expire_at"

  ttl_config {}

  depends_on = [google_firestore_database.default, google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 6. Pub/Sub: budget alerts and notification requests
# -----------------------------------------------------------------------------

resource "google_pubsub_topic" "budget_alerts" {
  project = var.project_id
  name    = "ectwin-budget-alerts"
  labels  = { component = "cost-guardrails" }

  depends_on = [google_project_service.apis]
}

# Pull subscription read by the tenant budget guard (pauses Scheduler jobs,
# never disables billing - disabling billing may delete resources).
resource "google_pubsub_subscription" "budget_guard" {
  project                    = var.project_id
  name                       = "ectwin-budget-alerts-guard"
  topic                      = google_pubsub_topic.budget_alerts.id
  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  labels                     = { component = "cost-guardrails" }

  expiration_policy {
    ttl = "" # never expire, even if nobody pulls for 31 days
  }
}

resource "google_pubsub_subscription_iam_member" "runner_budget_guard" {
  project      = var.project_id
  subscription = google_pubsub_subscription.budget_guard.name
  role         = "roles/pubsub.subscriber"
  member       = google_service_account.runner.member
}

# Notify requests from ectwin-notify-eval to ectwin-notifier (docs/03 4.5).
resource "google_pubsub_topic" "notify" {
  project = var.project_id
  name    = "ectwin-notify"
  labels  = { component = "notifications" }

  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic_iam_member" "runner_notify_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.notify.name
  role    = "roles/pubsub.publisher"
  member  = google_service_account.runner.member
}

# Optional: Pub/Sub service agent identity (google-beta only) for push OIDC.
resource "google_project_service_identity" "pubsub" {
  count    = var.notifier_push_endpoint != "" && var.grant_pubsub_agent_token_creator ? 1 : 0
  provider = google-beta

  project = var.project_id
  service = "pubsub.googleapis.com"

  depends_on = [google_project_service.apis]
}

resource "google_service_account_iam_member" "pubsub_agent_token_creator" {
  count = length(google_project_service_identity.pubsub)

  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_project_service_identity.pubsub[0].member
}

# Push subscription to the platform notifier; the OIDC token is signed for
# ectwin-runner and the notifier checks it against the registry (docs/03 4.5).
resource "google_pubsub_subscription" "notify_push" {
  count = var.notifier_push_endpoint == "" ? 0 : 1

  project                    = var.project_id
  name                       = "ectwin-notify-push"
  topic                      = google_pubsub_topic.notify.id
  ack_deadline_seconds       = 30
  message_retention_duration = "86400s"
  labels                     = { component = "notifications" }

  push_config {
    push_endpoint = var.notifier_push_endpoint

    oidc_token {
      service_account_email = google_service_account.runner.email
      audience              = var.notifier_push_audience != "" ? var.notifier_push_audience : var.notifier_push_endpoint
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  expiration_policy {
    ttl = ""
  }

  depends_on = [google_service_account_iam_member.pubsub_agent_token_creator]
}

# -----------------------------------------------------------------------------
# 7. Budget (alerts only - a budget does NOT cap spend)
# -----------------------------------------------------------------------------

resource "google_billing_budget" "tenant" {
  provider = google.tenant_quota

  billing_account = var.billing_account
  display_name    = "ectwin-${var.project_id}"

  budget_filter {
    projects               = ["projects/${local.project_number}"]
    calendar_period        = "MONTH"
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.monthly_budget_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_forecast_alert ? [1.0] : []
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "FORECASTED_SPEND"
    }
  }

  # Programmatic notifications to ectwin-budget-alerts. When the budget is
  # saved, Cloud Billing adds its own publisher binding on the topic, so the
  # caller needs pubsub.topics.setIamPolicy (Owner has it) **(to confirm)**.
  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    disable_default_iam_recipients   = false
    enable_project_level_recipients  = true # also e-mail project Owners (tenant admins)
    monitoring_notification_channels = []
  }

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 8. Secret Manager placeholders (no versions: the tenant adds its own keys)
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "placeholders" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value
  labels    = { component = "tenant-secrets" }

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "runner_accessor" {
  for_each = google_secret_manager_secret.placeholders

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runner.member
}
