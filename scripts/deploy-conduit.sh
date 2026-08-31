#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/conduit"
APPS_DIR="$ROOT_DIR/apps/conduit"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

echo "Deploying Conduit (Matrix homeserver)..."

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

echo "Waiting for Conduit to be ready..."
kubectl rollout status deployment/conduit -n conduit --timeout=120s

# Create users from config (using port-forward since Conduit is distroless)
if [[ -f "$CONFIG_DIR/users.enc.yaml" ]]; then
    echo "Creating Matrix users..."

    # Get registration token from secret
    REG_TOKEN=$(sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | grep "CONDUIT_REGISTRATION_TOKEN" | sed 's/.*CONDUIT_REGISTRATION_TOKEN:\s*//' | tr -d '"' | xargs)

    # Start port-forward in background
    kubectl port-forward -n conduit svc/conduit 6167:6167 &>/dev/null &
    PF_PID=$!
    trap "kill $PF_PID 2>/dev/null || true" EXIT
    sleep 2  # Wait for port-forward to establish

    # Parse users from SOPS-encrypted YAML
    USERS_YAML=$(sops --decrypt "$CONFIG_DIR/users.enc.yaml")

    # Extract usernames and create users in order (first user becomes admin)
    echo "$USERS_YAML" | grep -E "^\s*-\s*username:" | while read -r line; do
        USERNAME=$(echo "$line" | sed 's/.*username:\s*//' | tr -d '"' | xargs)

        # Get password from the block
        PASSWORD=$(echo "$USERS_YAML" | grep -A1 "username:\s*$USERNAME" | grep "password:" | sed 's/.*password:\s*//' | tr -d '"' | xargs)

        if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
            continue
        fi

        # Step 1: Start registration to get session
        STEP1=$(curl -s -X POST "http://localhost:6167/_matrix/client/r0/register" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}") || true

        # Check if user already exists
        if echo "$STEP1" | grep -q "M_USER_IN_USE"; then
            echo "  User exists: @$USERNAME:matrix.$DOMAIN"
            continue
        fi

        # Extract session from response
        SESSION=$(echo "$STEP1" | grep -o '"session":"[^"]*"' | sed 's/"session":"\([^"]*\)"/\1/')

        if [[ -z "$SESSION" ]]; then
            echo "  Warning: Could not get session for $USERNAME: $STEP1"
            continue
        fi

        # Step 2: Complete registration with token
        RESULT=$(curl -s -X POST "http://localhost:6167/_matrix/client/r0/register" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$REG_TOKEN\",\"session\":\"$SESSION\"}}") || true

        if echo "$RESULT" | grep -q "user_id"; then
            echo "  Created user: @$USERNAME:matrix.$DOMAIN"
        else
            echo "  Warning: Could not create $USERNAME: $RESULT"
        fi
    done

    # Clean up port-forward
    kill $PF_PID 2>/dev/null || true
fi

echo ""
echo "Conduit ready at https://matrix.$DOMAIN"
