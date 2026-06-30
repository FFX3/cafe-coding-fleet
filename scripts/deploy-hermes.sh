#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Ensure postgres is running (hermes depends on it)
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

# Create Hermes PostgreSQL user and database (same pattern as twenty)
echo "Creating Hermes database and user..."
HERMES_PASSWORD=$(sops --decrypt "$ROOT_DIR/apps/hermes/secret.enc.yaml" | grep PG_DATABASE_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='hermes'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER hermes WITH ENCRYPTED PASSWORD '$HERMES_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='hermes'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE hermes OWNER hermes"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d hermes -c "GRANT ALL ON SCHEMA public TO hermes"

echo "Deploying Hermes..."
kubectl apply -f "$ROOT_DIR/apps/hermes/namespace.yaml"
sops --decrypt "$ROOT_DIR/apps/hermes/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/hermes/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/hermes/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/hermes/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/hermes/service.yaml"
kubectl apply -f "$ROOT_DIR/apps/hermes/ingress.yaml"
kubectl rollout status deployment/hermes -n hermes --timeout=120s

echo ""
echo "Hermes deployed at https://hermes.justinmcintyre.com"
echo ""
echo "TUI access:"
echo "  nix run .#hermes"
