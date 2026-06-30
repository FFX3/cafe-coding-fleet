#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
GOTRUE_DIR="$ROOT_DIR/apps/gotrue"

# Ensure postgres is running
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

# Create GoTrue PostgreSQL user and auth schema in main postgres database
echo "Creating GoTrue user and auth schema..."
GOTRUE_PASSWORD=$(sops --decrypt "$GOTRUE_DIR/secret.enc.yaml" | grep DATABASE_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='gotrue'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER gotrue WITH ENCRYPTED PASSWORD '$GOTRUE_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION gotrue"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "GRANT ALL ON SCHEMA auth TO gotrue"

echo "Deploying GoTrue..."
kubectl apply -f "$GOTRUE_DIR/namespace.yaml"
sops --decrypt "$GOTRUE_DIR/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$GOTRUE_DIR/deployment.yaml"
kubectl apply -f "$GOTRUE_DIR/service.yaml"
kubectl apply -f "$GOTRUE_DIR/ingress.yaml"
kubectl rollout status deployment/gotrue -n gotrue --timeout=120s

# Create users from config (using admin API with service role token)
if [[ -f "$GOTRUE_DIR/users.enc.yaml" ]]; then
    echo "Creating GoTrue users..."

    # Get JWT secret for generating admin token
    JWT_SECRET=$(sops --decrypt "$GOTRUE_DIR/secret.enc.yaml" | grep GOTRUE_JWT_SECRET | sed 's/.*GOTRUE_JWT_SECRET:\s*//' | tr -d '"' | xargs)

    # Generate a service_role JWT (valid for 1 hour)
    # JWT header: {"alg":"HS256","typ":"JWT"}
    # JWT payload: {"role":"service_role","iat":<now>,"exp":<now+3600>}
    NOW=$(date +%s)
    EXP=$((NOW + 3600))
    HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
    PAYLOAD=$(echo -n "{\"role\":\"service_role\",\"iat\":$NOW,\"exp\":$EXP}" | base64 -w0 | tr '+/' '-_' | tr -d '=')
    SIGNATURE=$(echo -n "$HEADER.$PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 -w0 | tr '+/' '-_' | tr -d '=')
    SERVICE_TOKEN="$HEADER.$PAYLOAD.$SIGNATURE"

    # Start port-forward in background
    kubectl port-forward -n gotrue svc/gotrue 9999:9999 &>/dev/null &
    PF_PID=$!
    trap "kill $PF_PID 2>/dev/null || true" EXIT
    sleep 2  # Wait for port-forward to establish

    # Parse users from SOPS-encrypted YAML
    USERS_YAML=$(sops --decrypt "$GOTRUE_DIR/users.enc.yaml")

    # Extract users and create them via admin API
    echo "$USERS_YAML" | grep -E "^\s*-\s*email:" | while read -r line; do
        EMAIL=$(echo "$line" | sed 's/.*email:\s*//' | tr -d '"' | xargs)

        # Get password from the block
        PASSWORD=$(echo "$USERS_YAML" | grep -A1 "email:\s*$EMAIL" | grep "password:" | sed 's/.*password:\s*//' | tr -d '"' | xargs)

        if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
            continue
        fi

        # Create user via admin API (bypasses signup restrictions)
        RESULT=$(curl -s -X POST "http://localhost:9999/admin/users" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $SERVICE_TOKEN" \
            -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"email_confirm\":true}") || true

        if echo "$RESULT" | grep -q '"id"'; then
            echo "  Created user: $EMAIL"
        elif echo "$RESULT" | grep -q "already been registered\|already exists"; then
            echo "  User exists: $EMAIL"
        else
            echo "  Warning: Could not create $EMAIL: $RESULT"
        fi
    done

    # Clean up port-forward
    kill $PF_PID 2>/dev/null || true
fi

echo ""
echo "GoTrue deployed at https://auth.justinmcintyre.com"
echo ""
echo "Health check:"
echo "  curl https://auth.justinmcintyre.com/health"
