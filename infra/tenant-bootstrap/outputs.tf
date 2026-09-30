# -----------------------------------------------------------------------------
# outputs.tf - values the tenant admin (or the platform onboarding flow) needs
# after `terraform apply`.
# -----------------------------------------------------------------------------

output "bootstrap_version" {
  description = "Version of this bootstrap module (also stamped as label ectwin-bootstrap)."
  value       = local.bootstrap_version
}

output "project_number" {
  description = "Tenant project number used in the budget filter."
  value       = local.project_number
}

output "runner_service_account_email" {
  description = "ectwin-runner service account; register it in the web app ('Conectar proyecto')."
  value       = google_service_account.runner.email
}

output "runner_service_account_unique_id" {
  description = "Immutable numeric id of ectwin-runner (lets the platform detect a deleted-and-recreated account)."
  value       = google_service_account.runner.unique_id
}

output "broker_binding" {
  description = "The single grant to the platform, or null for connection path D."
  value = var.platform_broker_sa == "" ? null : {
    resource = google_service_account.runner.name
    role     = "roles/iam.serviceAccountTokenCreator"
    member   = "serviceAccount:${var.platform_broker_sa}"
  }
}

output "iam_matrix" {
  description = "Project-level roles held by ectwin-runner with their justification (resource-level grants are listed in README)."
  value       = local.runner_project_roles
}

output "enabled_services" {
  description = "APIs enabled by this module."
  value       = sort(tolist(local.services))
}

output "bigquery_datasets" {
  description = "Tenant datasets (location US)."
  value = {
    ectwin         = "${var.project_id}.${google_bigquery_dataset.ectwin.dataset_id}"
    ectwin_scratch = "${var.project_id}.${google_bigquery_dataset.scratch.dataset_id}"
  }
}

output "linked_datasets" {
  description = "Linked datasets on which ectwin-runner has dataViewer (created by this module or declared in linked_dataset_ids)."
  value       = sort(tolist(local.linked_dataset_ids))
}

output "bucket_name" {
  description = "Tenant bucket."
  value       = google_storage_bucket.ectwin.name
}

output "bucket_url" {
  description = "Tenant bucket URL."
  value       = google_storage_bucket.ectwin.url
}

output "firestore_database" {
  description = "Firestore database and location."
  value = {
    name     = "(default)"
    location = var.create_firestore_database ? google_firestore_database.default[0].location_id : "pre-existing (check with verify-tenant.sh)"
  }
}

output "budget" {
  description = "Budget resource name and alert topic."
  value = {
    name          = google_billing_budget.tenant.name
    amount        = "${var.monthly_budget_usd} ${var.budget_currency}"
    pubsub_topic  = google_pubsub_topic.budget_alerts.id
    guard_pull_id = google_pubsub_subscription.budget_guard.id
  }
}

output "notify_topic" {
  description = "Topic used by ectwin-notify-eval to request notifications."
  value       = google_pubsub_topic.notify.id
}

output "secret_ids" {
  description = "Secret placeholders (no versions yet)."
  value       = [for s in google_secret_manager_secret.placeholders : s.secret_id]
}

output "earth_engine_registration_url" {
  description = "Browser step: register the project for Earth Engine (noncommercial tier or commercial plan)."
  value       = "https://code.earthengine.google.com/register?project=${var.project_id}"
}

output "connection_payload" {
  description = "Non-secret summary to paste into the web app 'Conectar proyecto' screen (the broker re-verifies everything by preflight)."
  value = jsonencode({
    bootstrap_version  = local.bootstrap_version
    project_id         = var.project_id
    project_number     = local.project_number
    runner_sa_email    = google_service_account.runner.email
    broker_sa          = var.platform_broker_sa
    tier               = var.tier
    bq_location        = var.bq_location
    gcs_location       = var.gcs_location
    firestore_location = var.firestore_location
    bucket             = google_storage_bucket.ectwin.name
    connection_code    = var.connection_code != "" ? "set-on-dataset-label" : "none"
    features = {
      vertex            = var.enable_vertex
      batch             = var.enable_batch
      managed_pipelines = var.enable_managed_pipelines
      flood_api         = var.enable_flood_forecasting_api
    }
  })
}

output "next_steps" {
  description = "Manual post-steps (details in README.md)."
  value       = <<-EOT
    1. Web app > Conectar proyecto: paste project id ${var.project_id} (and the connection code) and run the preflight.
    2. Earth Engine: https://code.earthengine.google.com/register?project=${var.project_id} then set the daily EECU cap.
    3. WeatherNext: submit the WeatherNext Data Request form with the Google account that will subscribe.
    4. Analytics Hub: subscribe ectwin_commons (and weathernext_3 / weathernext_2 after approval) in location US, then re-apply with linked_dataset_ids or listing_subscriptions.
    5. BigQuery custom quota QueryUsagePerDay (e.g. 1 TiB for T1/T2) in IAM & Admin > Quotas.
    6. Optional keys: gcloud secrets versions add typesafe-api-key --data-file=- --project=${var.project_id}
    7. Check everything: scripts/verify-tenant.sh --project ${var.project_id}
  EOT
}
