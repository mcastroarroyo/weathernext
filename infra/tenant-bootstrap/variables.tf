# -----------------------------------------------------------------------------
# variables.tf - inputs of the GDE-Nino tenant bootstrap.
# Only project_id and billing_account are mandatory; everything else has a
# default that matches docs/03-architecture.md and the design decisions D6-D10.
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Identity of the tenant project and billing
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "ID of the tenant's own GCP project (TENANT_PROJECT). Organisations should use an org-owned project, not a personal one (D7)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID: 6-30 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "project_number" {
  description = "Numeric project number. Optional: when null the module looks it up; when set it must match (a check block verifies it). Get it with: gcloud projects describe PROJECT_ID --format='value(projectNumber)'."
  type        = string
  default     = null

  validation {
    condition     = var.project_number == null || can(regex("^[0-9]{6,20}$", var.project_number))
    error_message = "project_number must contain digits only."
  }
}

variable "billing_account" {
  description = "Billing account ID that pays for the tenant project (format XXXXXX-XXXXXX-XXXXXX). Used only to create the project-scoped budget."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account must look like 012345-6789AB-CDEF01 (uppercase hex)."
  }
}

variable "platform_broker_sa" {
  description = "Platform broker service account that may impersonate ectwin-runner (the ONLY grant to the platform). Set to \"\" for connection path D (fully self-deployed, zero standing operator access)."
  type        = string
  default     = "ectwin-broker@ectwin-platform-prod.iam.gserviceaccount.com"

  validation {
    condition     = var.platform_broker_sa == "" || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}[a-z0-9]\\.iam\\.gserviceaccount\\.com$", var.platform_broker_sa))
    error_message = "platform_broker_sa must be empty or a user-managed service account email (NAME@PROJECT.iam.gserviceaccount.com)."
  }
}

variable "connection_code" {
  description = "Optional one-time code shown by the web app in 'Conectar proyecto'. Stored as label ectwin-connection on the ectwin dataset so the broker can prove that the person connecting controls this project (anti confused-deputy check, see README)."
  type        = string
  default     = ""

  validation {
    condition     = var.connection_code == "" || can(regex("^[a-z0-9_-]{8,63}$", var.connection_code))
    error_message = "connection_code must be 8-63 characters of lowercase letters, digits, '_' or '-' (label value rules)."
  }
}

# ---------------------------------------------------------------------------
# Locations (D10)
# ---------------------------------------------------------------------------

variable "bq_location" {
  description = "BigQuery location for ectwin and ectwin_scratch. Must be US: WeatherNext and the Commons listing are in US and every dataset in a job must share the job's location."
  type        = string
  default     = "US"
}

variable "allow_non_us_bigquery" {
  description = "Escape hatch for sandbox tests only. When false (default) the module refuses any bq_location other than US (FR-013)."
  type        = bool
  default     = false
}

variable "gcs_location" {
  description = "Region for the tenant bucket and the default provider region. us-central1 is co-located with ARCO-ERA5, inside the GCS Always Free zone, and read by BigQuery US without transfer charge."
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.gcs_location))
    error_message = "gcs_location must be a single region such as us-central1."
  }
}

variable "firestore_location" {
  description = "Location of the Firestore (default) database that holds personal/session data. Default southamerica-west1 (Santiago) for Latin American residency; southamerica-east1 is the alternative. Cannot be changed after creation."
  type        = string
  default     = "southamerica-west1"

  validation {
    condition     = length(var.firestore_location) > 0
    error_message = "firestore_location must not be empty."
  }
}

# ---------------------------------------------------------------------------
# Tier, feature flags and labels
# ---------------------------------------------------------------------------

variable "tier" {
  description = "Onboarding tier (D9): T1 Light, T2 Standard, T3 Heavy, T4 Sponsored. Used for labels and documented defaults only."
  type        = string
  default     = "T1"

  validation {
    condition     = contains(["T1", "T2", "T3", "T4"], var.tier)
    error_message = "tier must be one of T1, T2, T3, T4."
  }
}

variable "enable_vertex" {
  description = "T3: enable aiplatform.googleapis.com and grant roles/aiplatform.user to ectwin-runner (WN2 on-demand scenario runs, Gemini)."
  type        = bool
  default     = false
}

variable "enable_batch" {
  description = "T3: enable batch.googleapis.com + compute.googleapis.com and grant Batch roles to ectwin-runner (SFINCS/LISFLOOD-FP on Spot VMs)."
  type        = bool
  default     = false
}

variable "enable_managed_pipelines" {
  description = "Allow the platform (through ectwin-runner) to create/update the tenant's Cloud Run jobs, Scheduler jobs and Pub/Sub subscriptions after Owner approval (FR-063), and to pause Scheduler jobs when the budget is exhausted. Off by default: the tenant deploys pipelines itself."
  type        = bool
  default     = false
}

variable "enable_flood_forecasting_api" {
  description = "Enable floodforecasting.googleapis.com in the tenant project (only if the tenant has its own allow-listed Flood Forecasting API access; the Commons key covers national products)."
  type        = bool
  default     = false
}

variable "extra_services" {
  description = "Additional APIs to enable, e.g. [\"dlp.googleapis.com\"] for Cloud DLP pseudonymisation (D18)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.extra_services : can(regex("^[a-z0-9.-]+\\.googleapis\\.com$", s))])
    error_message = "extra_services entries must be service names ending in .googleapis.com."
  }
}

variable "labels" {
  description = "Extra labels merged into every labelled resource (e.g. ectwin-sponsor, ectwin-dpa for T4 sponsored projects)."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys must start with a lowercase letter; keys and values may only contain lowercase letters, digits, '_' and '-' (max 63 characters)."
  }
}

# ---------------------------------------------------------------------------
# Cost guardrails
# ---------------------------------------------------------------------------

variable "monthly_budget_usd" {
  description = "Monthly budget amount (whole units of budget_currency). Suggested: T1 20, T2 75, T3 800 (1,250 in peak months). Budgets alert; they do NOT cap spend."
  type        = number
  default     = 20

  validation {
    condition     = var.monthly_budget_usd > 0 && floor(var.monthly_budget_usd) == var.monthly_budget_usd
    error_message = "monthly_budget_usd must be a positive whole number."
  }
}

variable "budget_currency" {
  description = "Currency of the budget amount. Must equal the billing account currency (USD for Ecuadorian accounts)."
  type        = string
  default     = "USD"
}

variable "budget_thresholds" {
  description = "Actual-spend alert thresholds as fractions of the budget."
  type        = list(number)
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = length(var.budget_thresholds) > 0 && alltrue([for t in var.budget_thresholds : t > 0 && t <= 5])
    error_message = "budget_thresholds must be a non-empty list of fractions between 0 and 5."
  }
}

variable "budget_forecast_alert" {
  description = "Also alert when FORECASTED month-end spend reaches 100% of the budget (early warning before actual spend)."
  type        = bool
  default     = true
}

variable "bq_query_usage_per_day_mib" {
  description = "OPTIONAL BigQuery 'QueryUsagePerDay' custom quota via Cloud Quotas, in MiB (1 TiB = 1048576). Null (default) = do not manage it here; set it in the console instead (README step 6). Quota ID and unit are marked (to confirm)."
  type        = number
  default     = null
}

variable "quota_contact_email" {
  description = "Contact email attached to the quota preference (only used when bq_query_usage_per_day_mib is set)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

variable "bucket_name_override" {
  description = "Leave null to use the standard name <project_id>-ectwin. Override only if that global bucket name is unavailable (then register the override with the platform)."
  type        = string
  default     = null
}

variable "scratch_retention_days" {
  description = "Delete objects under scratch/ after this many days."
  type        = number
  default     = 30
}

variable "nearline_after_days" {
  description = "Move objects under nearline_prefixes to NEARLINE after this many days."
  type        = number
  default     = 90
}

variable "nearline_prefixes" {
  description = "Prefixes that age into NEARLINE. Frequently read prefixes (tiles/, curated/, catalog/) are deliberately excluded to avoid retrieval fees. An empty list would apply the rule to ALL objects."
  type        = list(string)
  default     = ["runs/", "reports/", "evidence/", "exports/", "raw/"]
}

variable "soft_delete_retention_days" {
  description = "Bucket soft-delete retention in days (0 disables soft delete)."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days == 0 || (var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90)
    error_message = "soft_delete_retention_days must be 0 or between 7 and 90."
  }
}

variable "scratch_table_expiration_days" {
  description = "Default table expiration of the ectwin_scratch dataset, in days."
  type        = number
  default     = 7
}

variable "app_origins" {
  description = "Web app origins allowed to read the tenant bucket through V4 signed URLs (CORS), e.g. [\"https://app.example.org\"]. Empty = no CORS configuration (domain to confirm)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Firestore
# ---------------------------------------------------------------------------

variable "create_firestore_database" {
  description = "Create the Firestore (default) database. Set false if the project already has one (e.g. from App Engine) and check its mode/location with verify-tenant.sh."
  type        = bool
  default     = true
}

variable "firestore_delete_protection" {
  description = "Enable Firestore delete protection on (default)."
  type        = bool
  default     = true
}

variable "firestore_pitr" {
  description = "Enable Firestore point-in-time recovery (7-day version reads; billed as extra storage)."
  type        = bool
  default     = false
}

variable "enable_session_ttl" {
  description = "Create a TTL policy on collection group 'sessions', field 'expire_at' (sessions expire after 30 days, docs/03 section 5.6)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# BigQuery sharing (Analytics Hub) - optional, second pass after approvals
# ---------------------------------------------------------------------------

variable "listing_subscriptions" {
  description = "Optional Analytics Hub subscriptions to create as linked datasets. Map key = linked dataset id in the tenant (ectwin_commons, ectwin_commons_nc, weathernext_3, weathernext_2). The caller must already be allowed to subscribe (WeatherNext Data Request form approved; Commons listing published)."
  type = map(object({
    exchange_project = string
    location         = string
    data_exchange_id = string
    listing_id       = string
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.listing_subscriptions : can(regex("^[a-z][a-z0-9_]*$", k)) && length(k) <= 1024])
    error_message = "listing_subscriptions keys must be valid dataset ids (lowercase letters, digits, underscores)."
  }
}

variable "linked_dataset_ids" {
  description = "Linked datasets created OUTSIDE Terraform (console or REST) on which ectwin-runner gets roles/bigquery.dataViewer. Re-apply after each new subscription."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Pub/Sub notification path (docs/03 section 4.5)
# ---------------------------------------------------------------------------

variable "notifier_push_endpoint" {
  description = "HTTPS endpoint of ectwin-notifier (e.g. https://api.<DOMAIN>/internal/notify, domain to confirm). Empty = do not create the push subscription yet."
  type        = string
  default     = ""

  validation {
    condition     = var.notifier_push_endpoint == "" || startswith(var.notifier_push_endpoint, "https://")
    error_message = "notifier_push_endpoint must be empty or an https:// URL."
  }
}

variable "notifier_push_audience" {
  description = "Audience of the OIDC token on push requests. Empty = use notifier_push_endpoint."
  type        = string
  default     = ""
}

variable "grant_pubsub_agent_token_creator" {
  description = "Grant the Pub/Sub service agent TokenCreator on ectwin-runner so it can sign push OIDC tokens. Needed only on older projects (unverified cut-over date); harmless otherwise."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------

variable "secret_ids" {
  description = "Secret Manager placeholders created WITHOUT versions; the tenant adds its own keys later."
  type        = list(string)
  default     = ["typesafe-api-key", "floodforecasting-api-key"]
}
