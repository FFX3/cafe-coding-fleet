# Infrastructure Project

## Overview

Self-hosted internal business tools on a single-node Talos Linux Kubernetes cluster. Everything defined as code for long-term maintainability.

## Design Goals

- **Confidence**: The whole point is being able to take it down, redeploy, and extend over the coming years without fear. If it's not in this repo, it doesn't exist.
- **Reproducibility**: Nix flake ensures correct local tooling; Talos config is pure YAML
- **Local-first**: No GitHub dependency; push updates via Talos mTLS API
- **No escape hatches**: Talos has no SSH - forces declarative config, no undocumented bash fixes
- **Portable**: Talos runs identically local and on GCP (no vendor lock-in)
- **Cost control**: Cluster can be destroyed and recreated at will (`cluster-down.sh` / `cluster-up.sh`)

## Tech Stack

| Layer | Tool |
|-------|------|
| Local environment | Nix flake (terraform, talosctl, kubectl, sops) |
| Provisioning | Terraform |
| Cloud | GCP |
| OS | Talos Linux |
| Orchestration | Kubernetes (single-node) |
| Database | PostgreSQL 16 |
| Cache/Queue | Redis 7 |
| Secrets | SOPS (age or PGP key) |

## Applications

### Frappe Bench (single server, multiple apps/sites)
- **ERPNext** - Business management
- **Frappe CRM** - Fork: https://github.com/FFX3/crm (local: `~/infrastructure_/forks/crm`)

Frappe uses hostname to determine which "site" to serve. Both apps run in one bench process.

### Other Services
- **Nextcloud** - File storage
- **OneDev** - Git/CI

### Routing

Single nginx ingress routes by hostname:
- `erp.domain.com` → Frappe bench (ERPNext site)
- `crm.domain.com` → Frappe bench (CRM site)
- `cloud.domain.com` → Nextcloud
- `git.domain.com` → OneDev

## Talos Linux

- Immutable OS configured via YAML
- Managed through `talosctl` using mTLS (no SSH)
- `talosconfig` contains client credentials
- Broken nodes get replaced, not fixed

## Workflow

```bash
nix develop                    # Enter environment
terraform apply                # Provision GCP + boot Talos
talosctl gen config            # Generate machine config
talosctl apply-config          # Bootstrap cluster
kubectl apply -k ./apps/       # Deploy apps
```

## Reference

See `docs/previous-attempt-reference.md` for GCP terraform patterns from earlier attempt.
