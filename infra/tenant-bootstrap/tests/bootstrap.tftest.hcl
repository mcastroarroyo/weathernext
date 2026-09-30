# -----------------------------------------------------------------------------
# Offline plan tests for the tenant bootstrap (no credentials, no API calls).
# Requires Terraform >= 1.7 (mock_provider). Run from infra/tenant-bootstrap:
#   terraform init -backend=false && terraform test
# Last run: 2026-09-30, Terraform 1.16.4, google/google-beta 8.5.0 -> 5 passed.
# The project id below is illustrative only.
# -----------------------------------------------------------------------------

mock_provider "google" {
  mock_data "google_project" {
    defaults = { number = "123456789012" }
  }
  mock_resource "google_service_account" {
    defaults = {
      email  = "ectwin-runner@gad-portoviejo-ectwin.iam.gserviceaccount.com"
      member = "serviceAccount:ectwin-runner@gad-portoviejo-ectwin.iam.gserviceaccount.com"
      name   = "projects/gad-portoviejo-ectwin/serviceAccounts/ectwin-runner@gad-portoviejo-ectwin.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_pubsub_topic" {
    defaults = { id = "projects/gad-portoviejo-ectwin/topics/ectwin-budget-alerts" }
  }
}
mock_provider "google" {
  alias = "tenant_quota"
}
mock_provider "google-beta" {}

variables {
  project_id      = "gad-portoviejo-ectwin"
  billing_account = "012345-6789AB-CDEF01"
}

run "light_defaults" {
  command = plan

  assert {
    condition     = length(google_project_service.apis) == 19
    error_message = "expected 19 base APIs"
  }
  assert {
    condition     = length(google_project_iam_member.runner) == 7
    error_message = "expected 7 base runner roles"
  }
  assert {
    condition     = google_service_account_iam_member.broker_token_creator[0].member == "serviceAccount:ectwin-broker@ectwin-platform-prod.iam.gserviceaccount.com"
    error_message = "broker binding wrong"
  }
  assert {
    condition     = length(google_service_account_iam_member.runner_self_act_as) == 0
    error_message = "no self actAs for T1"
  }
  assert {
    condition     = google_bigquery_dataset.scratch.default_table_expiration_ms == 604800000
    error_message = "scratch expiry must be 7 days"
  }
  assert {
    condition     = google_storage_bucket.ectwin.name == "gad-portoviejo-ectwin-ectwin"
    error_message = "bucket name"
  }
  assert {
    condition     = google_storage_bucket.ectwin.soft_delete_policy[0].retention_duration_seconds == 604800
    error_message = "soft delete 7 d"
  }
  assert {
    condition     = google_firestore_database.default[0].location_id == "southamerica-west1"
    error_message = "firestore location"
  }
  assert {
    condition     = one(google_billing_budget.tenant.budget_filter).projects == toset(["projects/123456789012"])
    error_message = "budget filter"
  }
  assert {
    condition     = length(google_billing_budget.tenant.threshold_rules) == 4
    error_message = "3 current + 1 forecast"
  }
  assert {
    condition     = length(google_secret_manager_secret.placeholders) == 2
    error_message = "2 secrets"
  }
  assert {
    condition     = length(google_pubsub_subscription.notify_push) == 0
    error_message = "no push sub by default"
  }
}

run "heavy_path_d" {
  command = plan
  variables {
    tier                     = "T3"
    enable_vertex            = true
    enable_batch             = true
    enable_managed_pipelines = true
    platform_broker_sa       = ""
    monthly_budget_usd       = 1300
    notifier_push_endpoint   = "https://api.example.org/internal/notify"
    linked_dataset_ids       = ["ectwin_commons"]
    listing_subscriptions = {
      weathernext_2 = {
        exchange_project = "gcp-public-data-weathernext"
        location         = "us"
        data_exchange_id = "weathernext_19397e1bcb7"
        listing_id       = "weathernext_2_19a39fe59dd"
      }
    }
  }
  assert {
    condition     = length(google_project_service.apis) == 22
    error_message = "19 + aiplatform + batch + compute"
  }
  assert {
    condition     = length(google_project_iam_member.runner) == 13
    error_message = "7 + 1 + 2 + 3 roles"
  }
  assert {
    condition     = length(google_service_account_iam_member.broker_token_creator) == 0
    error_message = "path D has no broker"
  }
  assert {
    condition     = length(google_service_account_iam_member.runner_self_act_as) == 1
    error_message = "self actAs"
  }
  assert {
    condition     = length(google_bigquery_dataset_iam_member.runner_linked_viewer) == 2
    error_message = "two linked datasets"
  }
  assert {
    condition     = length(google_pubsub_subscription.notify_push) == 1
    error_message = "push sub"
  }
}

run "reject_eu_bigquery" {
  command = plan
  variables {
    bq_location = "EU"
  }
  expect_failures = [google_bigquery_dataset.ectwin, google_bigquery_dataset.scratch]
}

run "reject_bad_billing" {
  command = plan
  variables {
    billing_account = "not-an-account"
  }
  expect_failures = [var.billing_account]
}

run "warn_us_firestore" {
  command = plan
  variables {
    firestore_location = "us-central1"
  }
  expect_failures = [check.firestore_residency]
}
