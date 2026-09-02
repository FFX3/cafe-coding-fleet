# Cloudflare DNS records
# Automatically updates when cluster IP changes
# Subdomains are defined in gen-subdomains.tf (generated from config/domains.yaml)

resource "cloudflare_record" "services" {
  for_each = toset(local.gen_subdomains)

  zone_id = data.sops_file.secrets.data["cloudflare_zone_id"]
  name    = each.key
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false
}
