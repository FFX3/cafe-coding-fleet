#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"
TALOS_DIR="$ROOT_DIR/talos"

cd "$TERRAFORM_DIR"
IP=$(terraform output -raw controlplane_external_ip 2>/dev/null) || {
    echo "Error: Could not get IP from terraform output"
    echo "Make sure the cluster is running: ./scripts/cluster-up.sh"
    exit 1
}

echo "Disk Usage - /var/mnt/data"
echo "=========================="
echo ""

# Get disk mount info
talosctl --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" \
    mounts 2>/dev/null | grep -E "SOURCE|/var/mnt/data" || true

echo ""
echo "Directory sizes:"
echo "----------------"

# Use kubectl to run du inside the postgres pod (has access to the mounted volume)
kubectl exec -n postgres postgres-0 -- sh -c 'du -sh /var/lib/postgresql/data/* 2>/dev/null' || echo "  (pod not running)"

echo ""
echo "PostgreSQL data size (from pod):"
echo "---------------------------------"
kubectl exec -n postgres postgres-0 -- df -h /var/lib/postgresql/data 2>/dev/null || echo "  (pod not running)"
