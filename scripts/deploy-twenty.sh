#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/twenty"
APPS_DIR="$ROOT_DIR/apps/twenty"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

# Ensure postgres is running (twenty depends on it)
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

# Database setup is now handled by deploy-postgres.sh via setup-databases.sh

echo "Deploying Twenty CRM..."
kubectl apply -f "$APPS_DIR/namespace.yaml"

# Apply config (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$CONFIG_DIR/config.yaml" | kubectl apply -f -
sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | kubectl apply -f -

# Apply manifests (with domain substitution for ingress)
kubectl apply -f "$APPS_DIR/redis/pv.yaml"
kubectl apply -f "$APPS_DIR/redis/pvc.yaml"
kubectl apply -f "$APPS_DIR/redis/statefulset.yaml"
kubectl apply -f "$APPS_DIR/redis/service.yaml"
kubectl rollout status statefulset/redis -n twenty --timeout=120s
kubectl apply -f "$APPS_DIR/server/pv.yaml"
kubectl apply -f "$APPS_DIR/server/pvc.yaml"
kubectl apply -f "$APPS_DIR/server/deployment.yaml"
kubectl apply -f "$APPS_DIR/server/service.yaml"
kubectl apply -f "$APPS_DIR/worker/deployment.yaml"
sed "s/\${DOMAIN}/$DOMAIN/g" "$APPS_DIR/ingress.yaml" | kubectl apply -f -

echo "Waiting for Twenty server to be ready (migrations may take a while)..."
kubectl rollout status deployment/twenty-server -n twenty --timeout=300s
kubectl rollout status deployment/twenty-worker -n twenty --timeout=120s

echo ""
echo "Twenty CRM ready at https://crm.$DOMAIN"
