#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/webstudio"
APPS_DIR="$ROOT_DIR/apps/webstudio"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

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
kubectl apply -f "$APPS_DIR/publisher/deployment.yaml"
kubectl apply -f "$APPS_DIR/publisher/service.yaml"
kubectl rollout status deployment/webstudio-publisher -n webstudio --timeout=120s

# Deploy Builder
echo "Deploying Builder..."
kubectl apply -f "$APPS_DIR/builder/deployment.yaml"
kubectl apply -f "$APPS_DIR/builder/service.yaml"

# Apply ingress (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$APPS_DIR/ingress.yaml" | kubectl apply -f -

echo "Waiting for Builder to be ready (migrations may take a while)..."
kubectl rollout status deployment/webstudio-builder -n webstudio --timeout=300s

echo ""
echo "Webstudio deployed:"
echo "  Builder: https://webstudio.$DOMAIN"
echo "  API: https://api.$DOMAIN/webstudio/"
echo ""
echo "Login with:"
echo "  Email: admin@$DOMAIN"
echo "  Password: (value of AUTH_SECRET in secret.enc.yaml)"
