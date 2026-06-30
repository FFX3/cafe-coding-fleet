#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

NAMESPACE="hermes"

# Check hermes pod is running
POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=hermes -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$POD_STATUS" != "Running" ]]; then
    echo "Error: Hermes pod not running (status: $POD_STATUS)"
    exit 1
fi

# Connect to Hermes TUI
kubectl exec -it -n "$NAMESPACE" deployment/hermes -- hermes "$@"
