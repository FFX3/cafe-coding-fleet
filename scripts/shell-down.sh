#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

echo "Scaling down command-center..."
kubectl scale deployment/command-center -n command-center --replicas=0

echo "Done. Tmux sessions are gone."
