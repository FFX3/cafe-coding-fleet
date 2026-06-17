output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "data_disk_name" {
  description = "Data disk name (for compute project to reference)"
  value       = google_compute_disk.data.name
}

output "data_disk_self_link" {
  description = "Data disk self_link"
  value       = google_compute_disk.data.self_link
}

output "artifacts_bucket" {
  description = "GCS bucket for images and artifacts"
  value       = google_storage_bucket.artifacts.name
}
