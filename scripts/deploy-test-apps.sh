#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

echo "Deploying test apps..."
kubectl apply -f "$ROOT_DIR/apps/test-app/"
kubectl apply -f "$ROOT_DIR/apps/test-app-2/"

echo "Waiting for test apps to be ready..."
kubectl rollout status deployment/test-app --timeout=60s
kubectl rollout status deployment/test-app-2 --timeout=60s

echo "Test apps ready."
