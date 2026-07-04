#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

PORT=2222

# Check if already running
REPLICAS=$(kubectl get deployment/command-center -n command-center -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

if [[ "$REPLICAS" == "0" ]]; then
    echo "Starting command-center..."
    kubectl scale deployment/command-center -n command-center --replicas=1

    echo "Waiting for pod to be ready..."
    kubectl rollout status deployment/command-center -n command-center --timeout=120s
else
    echo "Command center already running"
fi

echo ""
echo "Connecting to command-center via SSH..."
echo "All data available at /command-center/<service>"
echo "Detach tmux with Ctrl+B, D to keep session alive"
echo "Scale down with: ./scripts/shell-down.sh"
echo ""
ssh -p "$PORT" "justin@shell.justinmcintyre.com"
