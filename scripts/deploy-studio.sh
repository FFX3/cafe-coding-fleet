#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
STUDIO_DIR="$ROOT_DIR/apps/studio"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"

# Get registry URL from terraform
cd "$TERRAFORM_DIR"
REGISTRY=$(terraform output -raw registry_url 2>/dev/null || echo "")

if [[ -z "$REGISTRY" ]]; then
    echo "Error: Could not get registry URL from terraform"
    echo "Run: cd terraform/compute && terraform apply"
    exit 1
fi

IMAGE_NAME="studio"
IMAGE_TAG="latest"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Configure docker to authenticate with GCP Artifact Registry
echo "Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGISTRY%%/*}" --quiet

echo "Building Studio image..."
docker build -t "$FULL_IMAGE" "$STUDIO_DIR"

echo "Pushing image to Artifact Registry..."
docker push "$FULL_IMAGE"

echo "Deploying Studio..."
kubectl apply -f "$STUDIO_DIR/namespace.yaml"

# Create image pull secret from terraform output
echo "Creating image pull secret..."
REGISTRY_KEY=$(terraform output -raw registry_reader_key)
kubectl create secret docker-registry gcr-credentials \
    --namespace=studio \
    --docker-server="${REGISTRY%%/*}" \
    --docker-username="_json_key_base64" \
    --docker-password="$REGISTRY_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# Update deployment with actual image and apply
cat "$STUDIO_DIR/deployment.yaml" | \
    sed "s|image: studio:latest|image: $FULL_IMAGE|g" | \
    sed 's|imagePullPolicy: Never|imagePullPolicy: Always|g' | \
    kubectl apply -f -

kubectl apply -f "$STUDIO_DIR/service.yaml"
kubectl apply -f "$STUDIO_DIR/ingress.yaml"
kubectl rollout restart deployment/studio -n studio
kubectl rollout status deployment/studio -n studio --timeout=120s

echo ""
echo "Studio deployed at https://studio.justinmcintyre.com"
