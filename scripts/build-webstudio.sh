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

IMAGE_NAME="webstudio-builder"
IMAGE_TAG=$(cd "$WEBSTUDIO_SRC" && git rev-parse --short HEAD)
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Configure docker to authenticate with GCP Artifact Registry
echo "Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGISTRY%%/*}" --quiet

# Build the webstudio-builder image
echo "Building Webstudio builder image from fork..."
docker build -f "$WEBSTUDIO_SRC/Dockerfile.builder" -t "$FULL_IMAGE" "$WEBSTUDIO_SRC"

echo "Pushing image to Artifact Registry..."
docker push "$FULL_IMAGE"

echo ""
echo "Built and pushed: $FULL_IMAGE"
