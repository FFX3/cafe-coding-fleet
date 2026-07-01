# Cloudflare DNS records
# Automatically updates when cluster IP changes

resource "cloudflare_record" "test" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "test"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "test2" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "test2"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "crm" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "crm"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "matrix" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "matrix"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "auth" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "auth"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "hermes" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "hermes"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "studio" {
  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = "studio"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}
