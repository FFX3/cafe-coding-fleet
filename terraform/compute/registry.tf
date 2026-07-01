# Google Artifact Registry for custom container images

# Enable Artifact Registry API
resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "main" {
  depends_on = [google_project_service.artifactregistry]

  location      = var.region
  repository_id = "infrastructure"
  description   = "Container images for infrastructure apps"
  format        = "DOCKER"
}

# Service account for pulling images from the registry
resource "google_service_account" "registry_reader" {
  account_id   = "registry-reader"
  display_name = "Registry Reader"
  description  = "Service account for Kubernetes to pull images from Artifact Registry"
}

# Grant the service account read access to the registry
resource "google_artifact_registry_repository_iam_member" "reader" {
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.registry_reader.email}"
}

# Create a key for the service account
resource "google_service_account_key" "registry_reader" {
  service_account_id = google_service_account.registry_reader.name
}

# Output the registry URL and credentials
output "registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
  description = "Artifact Registry URL for pushing images"
}

output "registry_reader_key" {
  value       = google_service_account_key.registry_reader.private_key
  sensitive   = true
  description = "Base64-encoded service account key for pulling images"
}
