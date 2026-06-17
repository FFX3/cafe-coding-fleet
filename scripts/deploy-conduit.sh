#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Deploying Conduit (Matrix homeserver)..."

kubectl apply -f "$ROOT_DIR/apps/conduit/namespace.yaml"
sops --decrypt "$ROOT_DIR/apps/conduit/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/conduit/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/conduit/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/conduit/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/conduit/service.yaml"
kubectl apply -f "$ROOT_DIR/apps/conduit/ingress.yaml"

echo "Waiting for Conduit to be ready..."
kubectl rollout status deployment/conduit -n conduit --timeout=120s

echo "Conduit ready at https://matrix.justinmcintyre.com"
echo ""
echo "To register, use Element app with:"
echo "  Homeserver: matrix.justinmcintyre.com"
echo "  Registration token: (from secret)"
echo ""
echo "Admin account: @conduit:matrix.justinmcintyre.com"
