# Firewall rules for Talos cluster

resource "google_compute_firewall" "talos_api" {
  name    = "talos-api"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["50000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["talos-node"]

  description = "Allow Talos API access (talosctl)"
}

resource "google_compute_firewall" "kubernetes_api" {
  name    = "kubernetes-api"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["talos-node"]

  description = "Allow Kubernetes API access"
}

resource "google_compute_firewall" "http_https" {
  name    = "http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["talos-node"]

  description = "Allow HTTP and HTTPS traffic"
}

resource "google_compute_firewall" "ssh_command_center" {
  name    = "ssh-command-center"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["2222"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["talos-node"]

  description = "SSH access to command-center via nginx-ingress"
}
