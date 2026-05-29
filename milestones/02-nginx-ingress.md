# Milestone 2: Nginx Ingress + Cloudflare DNS

Add nginx ingress and Cloudflare DNS management via Terraform.

## Goals

- [ ] Add Cloudflare provider to Terraform
- [ ] Create DNS A record pointing to cluster IP
- [ ] Deploy nginx ingress controller
- [ ] Create test static HTML page
- [ ] Configure ingress for `test.justinmcintyre.com`
- [ ] Verify end-to-end routing works

## Cloudflare Setup

### Prerequisites

1. Cloudflare API token with Zone:DNS:Edit permissions
2. Zone ID for justinmcintyre.com

### Terraform Resources

```hcl
# terraform/cloudflare.tf

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "test" {
  zone_id = var.cloudflare_zone_id
  name    = "test"
  content = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 60
  proxied = false  # Direct to IP for now, enable proxy later for SSL
}
```

### Variables (secrets via environment)

```bash
export TF_VAR_cloudflare_api_token="your-api-token"
export TF_VAR_cloudflare_zone_id="your-zone-id"
```

## Nginx Ingress

Deploy using Helm or raw manifests (TBD).

## Test

```bash
# After DNS propagates
curl -I http://test.justinmcintyre.com
```

Should return 200 and serve the static HTML page.

## Success Criteria

- Cloudflare DNS record created via Terraform
- DNS resolves to cluster IP
- Nginx ingress controller running
- Ingress resource routes by hostname
- curl to real domain returns static page
