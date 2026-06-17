# Talos Configuration

This directory contains Talos machine configs and client credentials.

## Files

| File | Purpose | Gitignored |
|------|---------|------------|
| `controlplane.yaml` | Machine config applied to the control plane node | Yes |
| `worker.yaml` | Machine config for worker nodes (unused in single-node) | Yes |
| `talosconfig` | Client credentials for `talosctl` commands | Yes |
| `patches/` | Config patches applied during generation | No |

## Sharing Access with Collaborators

The `talosconfig` file contains client certificates needed to authenticate with the Talos API. To give a collaborator access:

1. Send them the `talosconfig` file securely (Signal, encrypted email, etc.)
2. They place it at `talos/talosconfig` in their repo clone
3. They run `talosctl kubeconfig` to generate their kubectl config:
   ```bash
   cd terraform/compute
   IP=$(terraform output -raw controlplane_external_ip)
   talosctl kubeconfig --nodes "$IP" --endpoints "$IP" --talosconfig ../../talos/talosconfig --force
   ```

## When Configs Are Regenerated

Talos secrets live on the VM's boot disk (ephemeral), not the persistent data disk. This means:

- **Every `cluster-down.sh` + `cluster-up.sh` cycle regenerates configs**
- Running `cluster-up.sh` on an already-running cluster does NOT regenerate (idempotent)

After each down/up cycle, you'll need to re-share `talosconfig` with collaborators.
