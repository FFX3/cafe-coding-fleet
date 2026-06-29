#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
PERSISTENT_DIR="$ROOT_DIR/terraform/persistent"
COMPUTE_DIR="$ROOT_DIR/terraform/compute"
TALOS_VERSION="v1.13.2"
IMAGE_NAME="talos-${TALOS_VERSION//./-}"

echo "Starting GCP cluster..."
echo "======================="
echo ""

# Check if persistent infrastructure exists, create if not
echo "Checking persistent infrastructure..."
cd "$PERSISTENT_DIR"
terraform init -upgrade -reconfigure

if ! terraform state list 2>/dev/null | grep -q "google_compute_disk.data"; then
    echo "Persistent resources not found, creating..."
    terraform apply -auto-approve
else
    echo "Persistent resources exist, skipping."
fi

PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)
ZONE=$(terraform output -raw zone)

# Check if Talos image exists, create if not
echo ""
echo "Checking Talos image..."
if ! gcloud compute images describe "$IMAGE_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo "Talos image not found, creating..."
    "$ROOT_DIR/scripts/internal/setup-gcp-image.sh"
else
    echo "Talos image exists, skipping."
fi

echo ""
echo "Creating compute resources..."
cd "$COMPUTE_DIR"
terraform init -upgrade -reconfigure
terraform apply -auto-approve \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -var="zone=$ZONE"

cd "$ROOT_DIR"
./scripts/internal/bootstrap-gcp.sh

echo ""
echo "Cluster is up!"
