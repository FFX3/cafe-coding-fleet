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

# Decrypt secret once and extract values
HERMES_SECRET_YAML=$(sops --decrypt "$ROOT_DIR/apps/hermes/secret.enc.yaml")

# Create Hermes PostgreSQL user and database (same pattern as twenty)
echo "Creating Hermes database and user..."
HERMES_PASSWORD=$(echo "$HERMES_SECRET_YAML" | grep PG_DATABASE_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='hermes'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER hermes WITH ENCRYPTED PASSWORD '$HERMES_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='hermes'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE hermes OWNER hermes"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d hermes -c "GRANT ALL ON SCHEMA public TO hermes"

# Register Hermes as OAuth client in GoTrue (if GoTrue is deployed)
# Client ID is read from the SOPS secret to ensure consistency
HERMES_CLIENT_ID=$(echo "$HERMES_SECRET_YAML" | grep HERMES_DASHBOARD_OIDC_CLIENT_ID | sed 's/.*HERMES_DASHBOARD_OIDC_CLIENT_ID:\s*//' | tr -d '"' | xargs)
HERMES_REDIRECT_URI="https://hermes.justinmcintyre.com/auth/callback"

if [[ -z "$HERMES_CLIENT_ID" ]]; then
    echo "Warning: HERMES_DASHBOARD_OIDC_CLIENT_ID not found in secret, skipping OAuth registration"
elif kubectl get deployment gotrue -n gotrue &>/dev/null; then
    echo "Registering Hermes OAuth client in GoTrue..."

    # Upsert OAuth client for Hermes dashboard
    # client_secret_hash must be empty string (not NULL) for public clients
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d postgres -c \
        "INSERT INTO auth.oauth_clients (
            id,
            client_secret_hash,
            registration_type,
            redirect_uris,
            grant_types,
            client_name,
            client_type,
            token_endpoint_auth_method,
            created_at,
            updated_at
        ) VALUES (
            '$HERMES_CLIENT_ID',
            '',
            'manual',
            '$HERMES_REDIRECT_URI',
            'authorization_code',
            'hermes-dashboard',
            'public',
            'none',
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            client_secret_hash = EXCLUDED.client_secret_hash,
            redirect_uris = EXCLUDED.redirect_uris,
            grant_types = EXCLUDED.grant_types,
            client_name = EXCLUDED.client_name,
            client_type = EXCLUDED.client_type,
            token_endpoint_auth_method = EXCLUDED.token_endpoint_auth_method,
            updated_at = NOW()" \
        && echo "  Registered OAuth client: $HERMES_CLIENT_ID" || echo "  Warning: Could not register OAuth client"
else
    echo "GoTrue not deployed yet, skipping OAuth client registration"
    echo "  (Re-run deploy-hermes.sh after deploying GoTrue to register the OAuth client)"
fi

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
