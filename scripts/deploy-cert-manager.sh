#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

echo "Deploying cert-manager..."
kubectl apply -f "$ROOT_DIR/apps/cert-manager/deploy.yaml"

echo "Waiting for cert-manager to be ready..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "Creating ClusterIssuer..."
kubectl apply -f "$ROOT_DIR/apps/cert-manager/clusterissuer.yaml"

echo "cert-manager ready."
