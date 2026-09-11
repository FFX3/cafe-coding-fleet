#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"
source "$(dirname "$0")/lib/services.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/studio"
APPS_DIR="$ROOT_DIR/apps/studio"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

# Get image from services config (built by cluster-deploy ensure_image)
FULL_IMAGE=$(get_full_image "studio")

if [[ -z "$FULL_IMAGE" ]]; then
    echo "Error: Could not determine studio image"
    echo "Run: nix run .#cluster-deploy studio"
    exit 1
fi

# Get registry for pull secret
REGISTRY=$(get_registry_url)

echo "Deploying Studio..."
echo "  Image: $FULL_IMAGE"

# Check if this is first deploy
FIRST_DEPLOY=false
if ! namespace_exists "studio"; then
    FIRST_DEPLOY=true
fi

kubectl apply -f "$APPS_DIR/namespace.yaml"

# Apply config (with domain substitution)
sed "s/\${DOMAIN}/$DOMAIN/g" "$CONFIG_DIR/config.yaml" | kubectl apply -f -

# Create image pull secret from terraform output
echo "Creating image pull secret..."
cd "$TERRAFORM_DIR"
REGISTRY_KEY=$(terraform output -raw registry_reader_key)
cd "$ROOT_DIR"

kubectl create secret docker-registry gcr-credentials \
    --namespace=studio \
    --docker-server="${REGISTRY%%/*}" \
    --docker-username="_json_key_base64" \
    --docker-password="$REGISTRY_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# Update deployment with actual image and apply
cat "$APPS_DIR/deployment.yaml" | \
    sed "s|image: studio:latest|image: $FULL_IMAGE|g" | \
    sed 's|imagePullPolicy: Never|imagePullPolicy: Always|g' | \
    kubectl apply -f -

kubectl apply -f "$APPS_DIR/service.yaml"
sed "s/\${DOMAIN}/$DOMAIN/g" "$APPS_DIR/ingress.yaml" | kubectl apply -f -

# Restart to pick up any config changes (skip on first deploy)
if [[ "$FIRST_DEPLOY" == "false" ]]; then
    kubectl rollout restart deployment/studio -n studio
fi
kubectl rollout status deployment/studio -n studio --timeout=120s

echo ""
echo "Studio deployed at https://studio.$DOMAIN"
