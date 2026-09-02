#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/platform-services"
APPS_DIR="$ROOT_DIR/apps/platform-services"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

# Ensure postgres is running
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

# Database setup is now handled by deploy-postgres.sh via setup-databases.sh

echo "Deploying platform-services..."
kubectl apply -f "$APPS_DIR/namespace.yaml"

# Apply config (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$CONFIG_DIR/config.yaml" | kubectl apply -f -
sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | kubectl apply -f -

# Deploy GoTrue
kubectl apply -f "$APPS_DIR/gotrue/deployment.yaml"
kubectl apply -f "$APPS_DIR/gotrue/service.yaml"

# Deploy all PostgREST instances (postgrest-* directories)
for POSTGREST_DIR in "$APPS_DIR"/postgrest-*/; do
    if [[ -d "$POSTGREST_DIR" ]]; then
        POSTGREST_NAME=$(basename "$POSTGREST_DIR")
        echo "Deploying $POSTGREST_NAME..."
        sed "s/\${DOMAIN}/$DOMAIN/g" "$POSTGREST_DIR/deployment.yaml" | kubectl apply -f -
        kubectl apply -f "$POSTGREST_DIR/service.yaml"
    fi
done

# Apply ingress (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$APPS_DIR/ingress.yaml" | kubectl apply -f -

kubectl rollout restart deployment/gotrue -n platform-services
kubectl rollout status deployment/gotrue -n platform-services --timeout=120s

# Create users from config (direct database insert)
if [[ -f "$CONFIG_DIR/users.enc.yaml" ]]; then
    echo "Creating GoTrue users..."

    # Parse users from SOPS-encrypted YAML
    USERS_YAML=$(sops --decrypt "$CONFIG_DIR/users.enc.yaml")

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
echo "Platform services deployed:"
echo "  GoTrue: https://auth.$DOMAIN"
for POSTGREST_DIR in "$APPS_DIR"/postgrest-*/; do
    if [[ -d "$POSTGREST_DIR" ]]; then
        DB_NAME=$(basename "$POSTGREST_DIR" | sed 's/postgrest-//')
        echo "  PostgREST ($DB_NAME): https://api.$DOMAIN/$DB_NAME/"
    fi
done
echo ""
echo "Health check:"
echo "  curl https://auth.$DOMAIN/health"
