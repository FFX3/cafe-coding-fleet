#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

echo "Deploying test apps..."

# Apply non-ingress manifests directly
kubectl apply -f "$ROOT_DIR/apps/test-app/namespace.yaml" 2>/dev/null || true
kubectl apply -f "$ROOT_DIR/apps/test-app/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/test-app/service.yaml"
sed "s/\${DOMAIN}/$DOMAIN/g" "$ROOT_DIR/apps/test-app/ingress.yaml" | kubectl apply -f -

kubectl apply -f "$ROOT_DIR/apps/test-app-2/namespace.yaml" 2>/dev/null || true
kubectl apply -f "$ROOT_DIR/apps/test-app-2/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/test-app-2/service.yaml"
sed "s/\${DOMAIN}/$DOMAIN/g" "$ROOT_DIR/apps/test-app-2/ingress.yaml" | kubectl apply -f -

echo "Waiting for test apps to be ready..."
kubectl rollout status deployment/test-app --timeout=60s
kubectl rollout status deployment/test-app-2 --timeout=60s

echo "Test apps ready."
