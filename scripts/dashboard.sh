#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

TALOS_DIR="$ROOT_DIR/talos"

if [[ -z "${NODE_IP:-}" ]]; then
    echo "Error: Could not get IP from terraform output"
    echo "Make sure the cluster is running: ./scripts/cluster-up.sh"
    exit 1
fi
IP="$NODE_IP"

exec talosctl --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" dashboard
