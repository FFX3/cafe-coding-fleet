#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform"

echo "Starting GCP cluster..."
echo "======================="
echo ""

cd "$TERRAFORM_DIR"
terraform apply -auto-approve

cd "$ROOT_DIR"
./scripts/bootstrap-gcp.sh

echo ""
echo "Cluster is up!"
