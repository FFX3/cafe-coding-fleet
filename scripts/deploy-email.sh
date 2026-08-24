#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
EMAIL_DIR="$ROOT_DIR/apps/email"

echo "Deploying Email relay..."
kubectl apply -f "$EMAIL_DIR/namespace.yaml"
sops --decrypt "$EMAIL_DIR/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$EMAIL_DIR/deployment.yaml"
kubectl apply -f "$EMAIL_DIR/service.yaml"
kubectl rollout status deployment/email -n email --timeout=120s

echo ""
echo "Email relay ready at smtp.email.svc.cluster.local:587"
