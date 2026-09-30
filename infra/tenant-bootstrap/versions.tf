# -----------------------------------------------------------------------------
# GDE-Nino (Ecuador El Nino Digital Twin) - tenant bootstrap module
# versions.tf: Terraform/provider requirements and provider configurations.
#
# This is a ROOT module. A tenant administrator applies it in THEIR OWN Google
# Cloud project (Cloud Shell, Infrastructure Manager, or the platform's one-time
# OAuth path B). See README.md.
#
# Validated with Terraform 1.16.4 and hashicorp/google + hashicorp/google-beta
# 8.5.0 on 2026-09-30 (`terraform validate`). The module uses no language
# feature newer than Terraform 1.5, so `required_version` can be relaxed to
# ">= 1.5.7" if a runner (e.g. Infrastructure Manager) only offers 1.5.x.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0, < 9.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 8.0, < 9.0"
    }
  }
}

# Default provider: every resource lives in the tenant project. `default_labels`
# stamps the ectwin labels on every resource type that supports labels.
provider "google" {
  project        = var.project_id
  region         = var.gcs_location
  default_labels = local.labels
}

# google-beta is only used for google_project_service_identity (Pub/Sub service
# agent), which is not available in the GA provider.
provider "google-beta" {
  project        = var.project_id
  region         = var.gcs_location
  default_labels = local.labels
}

# Calls that must carry the tenant project as the explicit quota project
# (X-Goog-User-Project):
#   - Billing Budgets API: rejects end-user credentials (Cloud Shell ADC) that
#     have no quota project **(known provider behaviour; to confirm)**;
#   - Analytics Hub subscribe: the listing lives in the PUBLISHER project, but
#     quota and billing must land on the tenant (AP-02);
#   - Cloud Quotas preferences.
# The caller needs serviceusage.services.use on the tenant project (Owner/Editor
# have it; roles/serviceusage.serviceUsageConsumer grants it explicitly).
provider "google" {
  alias                 = "tenant_quota"
  project               = var.project_id
  region                = var.gcs_location
  billing_project       = var.project_id
  user_project_override = true
}
