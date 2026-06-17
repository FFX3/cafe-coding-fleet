# Reference persistent resources managed by ../persistent/

# Reference the data disk (created by persistent project)
data "google_compute_disk" "data" {
  name = "talos-data"
  zone = var.zone
}

# Reference the Talos image (created by scripts/setup-gcp-image.sh)
data "google_compute_image" "talos" {
  name    = "talos-${replace(local.talos_version, ".", "-")}"
  project = var.project_id
}
