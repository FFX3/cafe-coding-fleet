#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/email"
APPS_DIR="$ROOT_DIR/apps/email"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

echo "Deploying Email relay..."
kubectl apply -f "$APPS_DIR/namespace.yaml"

# Apply config (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$CONFIG_DIR/config.yaml" | kubectl apply -f -
sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | kubectl apply -f -

kubectl apply -f "$APPS_DIR/deployment.yaml"
kubectl apply -f "$APPS_DIR/service.yaml"
kubectl rollout status deployment/email -n email --timeout=120s

echo ""
echo "Email relay ready at smtp.email.svc.cluster.local:587"
