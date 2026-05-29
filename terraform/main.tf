terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Talos version - must match the image created by scripts/setup-gcp-image.sh
locals {
  talos_version = "v1.13.2"
}

# Reference the Talos image (created by scripts/setup-gcp-image.sh)
data "google_compute_image" "talos" {
  name    = "talos-${replace(local.talos_version, ".", "-")}"
  project = var.project_id
}
