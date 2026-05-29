# Persistent disk for data storage (PostgreSQL, etc.)

resource "google_compute_disk" "data" {
  name = "talos-data"
  type = "pd-ssd"
  zone = var.zone
  size = var.disk_size_gb

  labels = {
    purpose = "data"
  }
}
