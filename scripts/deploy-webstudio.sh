#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/webstudio"
APPS_DIR="$ROOT_DIR/apps/webstudio"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

# Get registry URL from terraform
cd "$TERRAFORM_DIR"
REGISTRY=$(terraform output -raw registry_url 2>/dev/null || echo "")
cd "$ROOT_DIR"

if [[ -z "$REGISTRY" ]]; then
    echo "Error: Could not get registry URL from terraform"
    echo "Run: cd terraform/compute && terraform apply"
    exit 1
fi

WEBSTUDIO_SRC="$ROOT_DIR/forks/webstudio"
IMAGE_TAG=$(cd "$WEBSTUDIO_SRC" && git rev-parse --short HEAD)
BUILDER_IMAGE="${REGISTRY}/webstudio-builder:${IMAGE_TAG}"
PUBLISHER_IMAGE="${REGISTRY}/webstudio-publisher:${IMAGE_TAG}"

# Check dependencies
if ! kubectl get statefulset postgres -n postgres &>/dev/null; then
    echo "Error: PostgreSQL must be deployed first"
    echo "Run: ./scripts/deploy-postgres.sh"
    exit 1
fi

if ! kubectl get deployment gotrue -n platform-services &>/dev/null; then
    echo "Error: Platform services must be deployed first"
    echo "Run: ./scripts/deploy-platform-services.sh"
    exit 1
fi

# Database setup is handled by deploy-postgres.sh via setup-databases.sh
# PostgREST role permissions (anon, authenticated) are configured by setup-databases.sh

# Register Webstudio as OAuth client in GoTrue
WEBSTUDIO_SECRET_YAML=$(sops --decrypt "$CONFIG_DIR/secret.enc.yaml")
WEBSTUDIO_CLIENT_ID=$(echo "$WEBSTUDIO_SECRET_YAML" | grep WEBSTUDIO_OIDC_CLIENT_ID | sed 's/.*WEBSTUDIO_OIDC_CLIENT_ID:\s*//' | tr -d '"' | xargs)
WEBSTUDIO_REDIRECT_URI="https://webstudio.$DOMAIN/auth/oidc/callback,https://*.webstudio.$DOMAIN/auth/ws/callback"

if [[ -z "$WEBSTUDIO_CLIENT_ID" ]]; then
    echo "Warning: WEBSTUDIO_OIDC_CLIENT_ID not found in secret, skipping OAuth registration"
else
    echo "Registering Webstudio OAuth client in GoTrue..."
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
            '$WEBSTUDIO_CLIENT_ID',
            '',
            'manual',
            '$WEBSTUDIO_REDIRECT_URI',
            'authorization_code',
            'webstudio',
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
        && echo "  Registered OAuth client: $WEBSTUDIO_CLIENT_ID" || echo "  Warning: Could not register OAuth client"
fi

echo "Deploying Webstudio..."
kubectl apply -f "$APPS_DIR/namespace.yaml"

# Apply config (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$CONFIG_DIR/config.yaml" | kubectl apply -f -
sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | kubectl apply -f -

# Deploy MinIO
echo "Deploying MinIO storage..."
kubectl apply -f "$APPS_DIR/minio/pv.yaml"
kubectl apply -f "$APPS_DIR/minio/pvc.yaml"
kubectl apply -f "$APPS_DIR/minio/statefulset.yaml"
kubectl apply -f "$APPS_DIR/minio/service.yaml"
kubectl rollout status statefulset/minio -n webstudio --timeout=120s

# Create MinIO bucket
echo "Creating MinIO bucket..."
kubectl run minio-setup --rm -i --restart=Never -n webstudio \
    --image=minio/mc:latest \
    --env="MINIO_ROOT_PASSWORD=$(sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | grep MINIO_ROOT_PASSWORD | sed 's/.*: *//' | tr -d '"')" \
    -- sh -c '
        mc alias set local http://minio:9000 minioadmin "$MINIO_ROOT_PASSWORD" && \
        mc mb --ignore-existing local/webstudio-assets && \
        mc anonymous set download local/webstudio-assets
    ' 2>/dev/null || echo "  Bucket may already exist"

# Deploy Publisher (internal service)
echo "Deploying Publisher..."
cat "$APPS_DIR/publisher/deployment.yaml" | \
    sed "s|image: webstudio-publisher:latest|image: $PUBLISHER_IMAGE|g" | \
    sed 's|imagePullPolicy: Never|imagePullPolicy: Always|g' | \
    kubectl apply -f -
kubectl apply -f "$APPS_DIR/publisher/service.yaml"
kubectl rollout status deployment/webstudio-publisher -n webstudio --timeout=120s

# Create image pull secret from terraform output
echo "Creating image pull secret..."
cd "$TERRAFORM_DIR"
REGISTRY_KEY=$(terraform output -raw registry_reader_key)
cd "$ROOT_DIR"

kubectl create secret docker-registry gcr-credentials \
    --namespace=webstudio \
    --docker-server="${REGISTRY%%/*}" \
    --docker-username="_json_key_base64" \
    --docker-password="$REGISTRY_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy Builder with actual image
echo "Deploying Builder..."
cat "$APPS_DIR/builder/deployment.yaml" | \
    sed "s|image: webstudio-builder:latest|image: $BUILDER_IMAGE|g" | \
    sed 's|imagePullPolicy: Never|imagePullPolicy: Always|g' | \
    kubectl apply -f -
kubectl apply -f "$APPS_DIR/builder/service.yaml"

# Apply ingress (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$APPS_DIR/ingress.yaml" | kubectl apply -f -

echo "Waiting for Builder to be ready (migrations may take a while)..."
kubectl rollout status deployment/webstudio-builder -n webstudio --timeout=300s

echo ""
echo "Webstudio deployed:"
echo "  Builder: https://webstudio.$DOMAIN"
echo ""
echo "Login via Studio (OIDC)"
