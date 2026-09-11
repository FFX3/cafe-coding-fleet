#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
WEBSTUDIO_SRC="$ROOT_DIR/forks/webstudio"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"

# Get registry URL from terraform
cd "$TERRAFORM_DIR"
REGISTRY=$(terraform output -raw registry_url 2>/dev/null || echo "")
cd "$ROOT_DIR"

if [[ -z "$REGISTRY" ]]; then
    echo "Error: Could not get registry URL from terraform"
    echo "Run: cd terraform/compute && terraform apply"
    exit 1
fi

IMAGE_TAG=$(cd "$WEBSTUDIO_SRC" && git rev-parse --short HEAD)

# Configure docker to authenticate with GCP Artifact Registry
echo "Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGISTRY%%/*}" --quiet

# Build the webstudio-builder image
BUILDER_IMAGE="${REGISTRY}/webstudio-builder:${IMAGE_TAG}"
echo "Building Webstudio builder image..."
docker build -f "$WEBSTUDIO_SRC/Dockerfile.builder" -t "$BUILDER_IMAGE" "$WEBSTUDIO_SRC"

echo "Pushing image to Artifact Registry..."
docker push "$BUILDER_IMAGE"
echo "Built and pushed: $BUILDER_IMAGE"

# Build the cloudflare-publisher image
PUBLISHER_IMAGE="${REGISTRY}/webstudio-publisher:${IMAGE_TAG}"
echo ""
echo "Building Webstudio publisher image..."
docker build -f "$WEBSTUDIO_SRC/Dockerfile.publisher" -t "$PUBLISHER_IMAGE" "$WEBSTUDIO_SRC"

echo "Pushing image to Artifact Registry..."
docker push "$PUBLISHER_IMAGE"
echo "Built and pushed: $PUBLISHER_IMAGE"

echo ""
echo "All images built and pushed."
