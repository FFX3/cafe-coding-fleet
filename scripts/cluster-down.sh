#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PERSISTENT_DIR="$ROOT_DIR/terraform/persistent"
COMPUTE_DIR="$ROOT_DIR/terraform/compute"

echo "Shutting down GCP cluster (keeping persistent disk)..."
echo "======================================================="
echo ""
echo "This destroys:"
echo "  - VM instance"
echo "  - Firewall rules"
echo "  - DNS records"
echo ""
echo "This keeps (in terraform/persistent):"
echo "  - Data disk (talos-data)"
echo "  - Artifacts bucket"
echo ""
echo "Cost savings: ~\$70 CAD/month -> ~\$4 CAD/month (disk only)"
echo ""
echo "To bring it back: ./scripts/cluster-up.sh"
echo ""

# Export certificates before destroying
echo "Exporting certificates..."
"$ROOT_DIR/scripts/internal/export-certs.sh" || echo "Warning: Failed to export certs (cluster may not be reachable)"
echo ""

# Get config from persistent
cd "$PERSISTENT_DIR"
PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)
ZONE=$(terraform output -raw zone)

cd "$COMPUTE_DIR"
terraform destroy \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -var="zone=$ZONE"

echo ""
echo "Compute resources destroyed. You're now only paying for disk storage."
