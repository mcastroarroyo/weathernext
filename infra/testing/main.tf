# GDE-Niño TEST environment inside an existing project.
# Creates only ectwin-prefixed resources so it can share a project with other work.

locals {
  runner_sa = "ectwin-runner@${var.project_id}.iam.gserviceaccount.com"
  datasets = merge(
    {
      ectwin_commons = "National shared products (test Commons): boundaries, flood baseline, forecasts, ENSO."
      ectwin_ops     = "Pipeline run log and operational tables."
    },
    { for k, v in var.pilot_tenants : "ectwin_pilot_${k}" => "Simulated tenant workspace: ${v}." }
  )
}

resource "google_bigquery_dataset" "ds" {
  for_each                   = local.datasets
  dataset_id                 = each.key
  location                   = var.bq_location
  description                = each.value
  labels                     = var.labels
  delete_contents_on_destroy = false
}

# Pipelines running as ectwin-runner write to every test dataset.
resource "google_bigquery_dataset_iam_member" "runner_editor" {
  for_each   = local.datasets
  dataset_id = google_bigquery_dataset.ds[each.key].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${local.runner_sa}"
}

resource "google_storage_bucket" "raw" {
  name                        = "${var.project_id}-ectwin-raw"
  location                    = var.gcs_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels
  # Raw captures are the archive (several sources keep no history): never auto-deleted.
  soft_delete_policy {
    retention_duration_seconds = 604800
  }
}

resource "google_storage_bucket" "curated" {
  name                        = "${var.project_id}-ectwin-curated"
  location                    = var.gcs_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels
  lifecycle_rule {
    condition {
      age            = 30
      matches_prefix = ["scratch/"]
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_artifact_registry_repository" "images" {
  location      = var.gcs_location
  repository_id = "ectwin"
  format        = "DOCKER"
  description   = "GDE-Niño pipeline images (test)"
  labels        = var.labels
}

resource "google_secret_manager_secret" "secret" {
  for_each  = toset(var.secret_ids)
  secret_id = each.value
  labels    = var.labels
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "runner_access" {
  for_each  = google_secret_manager_secret.secret
  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.runner_sa}"
}
