terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}

# Load encrypted secrets via SOPS
# Requires age private key at ~/.config/sops/age/keys.txt
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare_api_token"]
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
