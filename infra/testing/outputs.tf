output "datasets" {
  description = "BigQuery datasets created for the test environment."
  value       = [for d in google_bigquery_dataset.ds : d.dataset_id]
}

output "raw_bucket" {
  value = google_storage_bucket.raw.url
}

output "curated_bucket" {
  value = google_storage_bucket.curated.url
}

output "artifact_repository" {
  value = google_artifact_registry_repository.images.id
}
