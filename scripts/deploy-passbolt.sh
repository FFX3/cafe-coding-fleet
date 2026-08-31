#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/passbolt"
APPS_DIR="$ROOT_DIR/apps/passbolt"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

# Ensure postgres is running
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

# Create passbolt PostgreSQL user and database
echo "Creating passbolt database and user..."
PASSBOLT_PASSWORD=$(sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | grep DATASOURCES_DEFAULT_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='passbolt'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER passbolt WITH ENCRYPTED PASSWORD '$PASSBOLT_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='passbolt'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE passbolt OWNER passbolt"

echo "Deploying Passbolt..."
kubectl apply -f "$APPS_DIR/namespace.yaml"

# Apply config (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$CONFIG_DIR/config.yaml" | kubectl apply -f -
sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | kubectl apply -f -

# Apply manifests (with domain substitution for ingress)
kubectl apply -f "$APPS_DIR/pv.yaml"
kubectl apply -f "$APPS_DIR/pvc.yaml"
kubectl apply -f "$APPS_DIR/deployment.yaml"
kubectl apply -f "$APPS_DIR/service.yaml"
sed "s/\${DOMAIN}/$DOMAIN/g" "$APPS_DIR/ingress.yaml" | kubectl apply -f -
kubectl rollout status deployment/passbolt -n passbolt --timeout=300s

# Create users from config
if [[ -f "$CONFIG_DIR/users.enc.yaml" ]]; then
    echo "Creating Passbolt users..."

    USERS_YAML=$(sops --decrypt "$CONFIG_DIR/users.enc.yaml")

    # Extract each user block and process
    echo "$USERS_YAML" | grep -E "^\s*-\s*email:" | while read -r line; do
        EMAIL=$(echo "$line" | sed 's/.*email:\s*//' | tr -d '"' | xargs)

        # Get user details from the block
        FIRST_NAME=$(echo "$USERS_YAML" | grep -A4 "email:\s*$EMAIL" | grep "first_name:" | sed 's/.*first_name:\s*//' | tr -d '"' | xargs)
        LAST_NAME=$(echo "$USERS_YAML" | grep -A4 "email:\s*$EMAIL" | grep "last_name:" | sed 's/.*last_name:\s*//' | tr -d '"' | xargs)
        ROLE=$(echo "$USERS_YAML" | grep -A4 "email:\s*$EMAIL" | grep "role:" | sed 's/.*role:\s*//' | tr -d '"' | xargs)

        if [[ -z "$EMAIL" || -z "$FIRST_NAME" || -z "$LAST_NAME" ]]; then
            continue
        fi

        ROLE="${ROLE:-user}"

        # Check if user exists (query database)
        EXISTS=$(kubectl exec -n postgres statefulset/postgres -- psql -U passbolt -d passbolt -t -c \
            "SELECT 1 FROM users WHERE username='$EMAIL'" 2>/dev/null | tr -d ' ' || echo "")

        if [[ "$EXISTS" == "1" ]]; then
            echo "  User exists: $EMAIL"
        else
            # Create user via passbolt CLI and capture setup URL
            RESULT=$(kubectl exec -n passbolt deploy/passbolt -- su -c \
                "bin/cake passbolt register_user -u '$EMAIL' -f '$FIRST_NAME' -l '$LAST_NAME' -r '$ROLE'" \
                -s /bin/bash www-data 2>&1) || true

            if echo "$RESULT" | grep -q "setup/start"; then
                SETUP_URL=$(echo "$RESULT" | grep -o 'https://[^ ]*setup/start[^ ]*' | head -1)
                echo "  Created user: $EMAIL"
                echo "    Setup URL: $SETUP_URL"
            elif echo "$RESULT" | grep -qi "already exists"; then
                echo "  User exists: $EMAIL"
            else
                echo "  Warning: Could not create $EMAIL"
                echo "$RESULT" | head -3 | sed 's/^/    /'
            fi
        fi
    done
fi

echo ""
echo "Passbolt deployed at https://passbolt.$DOMAIN"
