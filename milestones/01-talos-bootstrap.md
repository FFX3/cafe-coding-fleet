# Milestone 1: Talos Bootstrap

Get Talos Linux running both locally and on GCP.

## Goals

- [ ] Nix flake with talosctl, terraform, kubectl
- [ ] Local Talos cluster (QEMU or Docker)
- [ ] GCP Talos cluster (single node)
- [ ] Verify both respond to `talosctl health`

## Local Setup

Use `talosctl cluster create` with QEMU backend (no Docker daemon required).

## GCP Setup

Terraform to:
1. Create compute instance with Talos image
2. Create persistent disk for data
3. Configure firewall (talosctl port 50000, HTTP 80/443)

## Success Criteria

```bash
# Local
talosctl --nodes localhost health

# GCP
talosctl --nodes <GCP_IP> health
kubectl get nodes
```
