#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

# Default to compute, allow specifying persistent
TARGET="${1:-compute}"

case "$TARGET" in
  compute|persistent)
    ;;
  *)
    echo "Usage: $0 [compute|persistent]"
    echo "  compute    - VM, networking, registry (default)"
    echo "  persistent - Storage resources"
    exit 1
    ;;
esac

if [[ "$TARGET" == "compute" ]]; then
    # Get variables from persistent terraform
    cd "$ROOT_DIR/terraform/persistent"
    terraform init -upgrade -reconfigure

    PROJECT_ID=$(terraform output -raw project_id)
    REGION=$(terraform output -raw region)
    ZONE=$(terraform output -raw zone)

    cd "$ROOT_DIR/terraform/compute"
    echo "Initializing terraform (compute)..."
    terraform init -upgrade -reconfigure

    echo ""
    echo "Applying terraform (compute)..."
    terraform apply \
        -var="project_id=$PROJECT_ID" \
        -var="region=$REGION" \
        -var="zone=$ZONE"
else
    cd "$ROOT_DIR/terraform/persistent"
    echo "Initializing terraform (persistent)..."
    terraform init -upgrade -reconfigure

    echo ""
    echo "Applying terraform (persistent)..."
    terraform apply
fi
