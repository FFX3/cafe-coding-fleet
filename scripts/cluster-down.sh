#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"

echo "Shutting down GCP cluster (keeping disks)..."
echo "============================================="
echo ""
echo "This destroys the VM but keeps:"
echo "  - Data disk (talos-data)"
echo "  - Talos image"
echo "  - GCS bucket"
echo "  - Firewall rules"
echo ""
echo "To bring it back: terraform apply && ./scripts/bootstrap-gcp.sh"
echo ""

cd "$TERRAFORM_DIR"

terraform destroy -target=google_compute_instance.talos_controlplane

echo ""
echo "VM destroyed. You're now only paying for disk storage."
