#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TALOS_DIR="$ROOT_DIR/talos"

cd "$TERRAFORM_DIR"
IP=$(terraform output -raw controlplane_external_ip 2>/dev/null) || {
    echo "Error: Could not get IP from terraform output"
    echo "Make sure the cluster is running: ./scripts/cluster-up.sh"
    exit 1
}

exec talosctl --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" dashboard
