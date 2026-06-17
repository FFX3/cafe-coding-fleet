#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PERSISTENT_DIR="$ROOT_DIR/terraform/persistent"

# Get config from terraform
cd "$PERSISTENT_DIR"
PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)

# Temporary bucket for image upload (cleaned up after)
BUCKET_NAME="${PROJECT_ID}-talos-image-upload"

# Talos version
TALOS_VERSION="v1.13.2"

# Default schematic ID (vanilla Talos, no extensions)
# Get custom ones from https://factory.talos.dev/
SCHEMATIC_ID="376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"

IMAGE_URL="https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_VERSION}/gcp-amd64.raw.tar.gz"
IMAGE_NAME="talos-${TALOS_VERSION//./-}"
GCS_PATH="gs://${BUCKET_NAME}/talos-${TALOS_VERSION}.raw.tar.gz"

echo "Talos GCP Image Setup"
echo "====================="
echo "Version: ${TALOS_VERSION}"
echo "Project: ${PROJECT_ID}"
echo ""

# Check if image already exists in GCP
if gcloud compute images describe "$IMAGE_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo "Image '$IMAGE_NAME' already exists in GCP. Nothing to do."
    exit 0
fi

# Create temporary bucket
echo "Creating temporary GCS bucket..."
gsutil mb -l "$REGION" "gs://${BUCKET_NAME}"

# Cleanup on exit (success or failure)
cleanup() {
    echo "Cleaning up temporary bucket..."
    gsutil rm -r "gs://${BUCKET_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# Download and upload
echo "Downloading Talos image from factory.talos.dev..."
echo "URL: $IMAGE_URL"
curl -L --progress-bar -o /tmp/talos-gcp.raw.tar.gz "$IMAGE_URL"

echo "Uploading to GCS..."
gsutil cp /tmp/talos-gcp.raw.tar.gz "$GCS_PATH"
rm /tmp/talos-gcp.raw.tar.gz

# Create GCP compute image
echo "Creating GCP compute image..."
gcloud compute images create "$IMAGE_NAME" \
    --project="$PROJECT_ID" \
    --source-uri="$GCS_PATH" \
    --guest-os-features=VIRTIO_SCSI_MULTIQUEUE

echo ""
echo "Done! Image '$IMAGE_NAME' is ready."
