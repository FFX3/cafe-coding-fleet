#!/usr/bin/env bash
set -euo pipefail

# Configuration
TALOS_VERSION="v1.13.2"
PROJECT_ID="cafe-coding-fleet"
BUCKET_NAME="${PROJECT_ID}-talos-images"
REGION="northamerica-northeast1"

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

# Create bucket if it doesn't exist
if ! gsutil ls "gs://${BUCKET_NAME}" &>/dev/null; then
    echo "Creating GCS bucket..."
    gsutil mb -l "$REGION" "gs://${BUCKET_NAME}"
fi

# Download and upload if not in GCS
if ! gsutil stat "$GCS_PATH" &>/dev/null; then
    echo "Downloading Talos image from factory.talos.dev..."
    echo "URL: $IMAGE_URL"
    curl -L --progress-bar -o /tmp/talos-gcp.raw.tar.gz "$IMAGE_URL"

    echo "Uploading to GCS..."
    gsutil cp /tmp/talos-gcp.raw.tar.gz "$GCS_PATH"
    rm /tmp/talos-gcp.raw.tar.gz
else
    echo "Image already in GCS bucket."
fi

# Create GCP compute image
echo "Creating GCP compute image..."
gcloud compute images create "$IMAGE_NAME" \
    --project="$PROJECT_ID" \
    --source-uri="$GCS_PATH" \
    --guest-os-features=VIRTIO_SCSI_MULTIQUEUE

echo ""
echo "Done! Image '$IMAGE_NAME' is ready."
echo "You can now run: cd terraform && terraform apply"
