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
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pgcrypto"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION gotrue"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "GRANT ALL ON SCHEMA auth TO gotrue"

echo "Deploying GoTrue..."
kubectl apply -f "$GOTRUE_DIR/namespace.yaml"
sops --decrypt "$GOTRUE_DIR/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$GOTRUE_DIR/deployment.yaml"
kubectl apply -f "$GOTRUE_DIR/service.yaml"
kubectl apply -f "$GOTRUE_DIR/ingress.yaml"
kubectl rollout restart deployment/gotrue -n gotrue
kubectl rollout status deployment/gotrue -n gotrue --timeout=120s

# Create users from config (direct database insert)
if [[ -f "$GOTRUE_DIR/users.enc.yaml" ]]; then
    echo "Creating GoTrue users..."

    # Parse users from SOPS-encrypted YAML
    USERS_YAML=$(sops --decrypt "$GOTRUE_DIR/users.enc.yaml")

    echo "$USERS_YAML" | grep -E "^\s*-\s*email:" | while read -r line; do
        EMAIL=$(echo "$line" | sed 's/.*email:\s*//' | tr -d '"' | xargs)
        PASSWORD=$(echo "$USERS_YAML" | grep -A1 "email:\s*$EMAIL" | grep "password:" | sed 's/.*password:\s*//' | tr -d '"' | xargs)

        if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
            continue
        fi

        # Check if user exists
        EXISTS=$(kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d postgres -t -c \
            "SELECT 1 FROM auth.users WHERE email='$EMAIL'" 2>/dev/null | tr -d ' ')

        if [[ "$EXISTS" == "1" ]]; then
            echo "  User exists: $EMAIL"
        else
            # Insert user with bcrypt-hashed password (GoTrue uses bcrypt cost 10)
            # Generate UUID and hash password
            USER_ID=$(cat /proc/sys/kernel/random/uuid)
            HASHED_PW=$(kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d postgres -t -c \
                "SELECT crypt('$PASSWORD', gen_salt('bf', 10))" 2>/dev/null | tr -d ' \n')

            kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d postgres -c \
                "INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, role, aud)
                 VALUES ('$USER_ID', '$EMAIL', '$HASHED_PW', NOW(), NOW(), NOW(), 'authenticated', 'authenticated')" \
                 &>/dev/null && echo "  Created user: $EMAIL" || echo "  Warning: Could not create $EMAIL"
        fi
    done
fi

echo ""
echo "GoTrue deployed at https://auth.justinmcintyre.com"
echo ""
echo "Health check:"
echo "  curl https://auth.justinmcintyre.com/health"
