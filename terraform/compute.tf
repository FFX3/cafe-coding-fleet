# Talos control plane node

resource "google_compute_instance" "talos_controlplane" {
  name         = "talos-controlplane"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["talos-node"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.talos.self_link
      size  = 20
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.data.self_link
    device_name = "data"
    mode        = "READ_WRITE"
  }

  network_interface {
    network = "default"

    access_config {
      # Ephemeral external IP
    }
  }

  # Talos machine config is applied post-boot via talosctl
  metadata = {
    enable-oslogin = "FALSE"
  }

  labels = {
    role = "controlplane"
  }

  # Allow stopping for updates
  allow_stopping_for_update = true
}
