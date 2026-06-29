#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Ensure postgres is running (twenty depends on it)
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

echo "Creating Twenty database and user..."
TWENTY_PASSWORD=$(sops --decrypt "$ROOT_DIR/apps/twenty/secret.enc.yaml" | grep PG_DATABASE_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='twenty'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER twenty WITH ENCRYPTED PASSWORD '$TWENTY_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='twenty'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE twenty OWNER twenty"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d twenty -c "GRANT ALL ON SCHEMA public TO twenty"

echo "Deploying Twenty CRM..."
kubectl apply -f "$ROOT_DIR/apps/twenty/namespace.yaml"
sops --decrypt "$ROOT_DIR/apps/twenty/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/statefulset.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/service.yaml"
kubectl rollout status statefulset/redis -n twenty --timeout=120s
kubectl apply -f "$ROOT_DIR/apps/twenty/server/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/server/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/server/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/server/service.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/worker/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/ingress.yaml"

echo "Waiting for Twenty server to be ready (migrations may take a while)..."
kubectl rollout status deployment/twenty-server -n twenty --timeout=300s
kubectl rollout status deployment/twenty-worker -n twenty --timeout=120s

echo "Twenty CRM ready."
