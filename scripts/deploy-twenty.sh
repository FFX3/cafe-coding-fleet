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

echo "Creating Twenty database and user..."
TWENTY_PASSWORD=$(sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | grep PG_DATABASE_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='twenty'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER twenty WITH ENCRYPTED PASSWORD '$TWENTY_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='twenty'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE twenty OWNER twenty"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d twenty -c "GRANT ALL ON SCHEMA public TO twenty"

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
