# Persistent disk for data storage (PostgreSQL, etc.)

resource "google_compute_disk" "data" {
  name = "talos-data"
  type = "pd-ssd"
  zone = var.zone
  size = var.disk_size_gb

  labels = {
    purpose = "data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# GCS bucket for images and artifacts

resource "google_storage_bucket" "artifacts" {
  name     = "${var.project_id}-artifacts"
  location = var.region

  # Prevent accidental deletion
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}
