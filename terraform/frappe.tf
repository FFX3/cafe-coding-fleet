# Service account for Frappe to access pre-built assets in GCS

resource "google_service_account" "frappe_assets" {
  account_id   = "frappe-assets-reader"
  display_name = "Frappe Assets Reader"
  description  = "Service account for downloading pre-built Frappe assets from GCS"
}

# Grant read access to the Talos images bucket (where frappe assets are stored)
resource "google_storage_bucket_iam_member" "frappe_assets_reader" {
  bucket = "${var.project_id}-talos-images"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.frappe_assets.email}"
}

output "frappe_service_account_email" {
  value       = google_service_account.frappe_assets.email
  description = "Email of the Frappe assets service account. Generate a key with: gcloud iam service-accounts keys create"
}
