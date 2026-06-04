#!/usr/bin/env bash
set -euo pipefail

# Setup GCS service account key for Frappe assets
# Creates a SOPS-encrypted JSON file with the service account key

SERVICE_ACCOUNT="frappe-assets-reader@cafe-coding-fleet.iam.gserviceaccount.com"
SECRET_FILE="apps/frappe/gcs-key.enc.json"

echo "══════════════════════════════════════════════════════════════════"
echo "  Frappe GCS Service Account Key Setup"
echo "══════════════════════════════════════════════════════════════════"
echo ""

# Check prerequisites
for cmd in gcloud sops; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Run this inside 'nix develop'"
        exit 1
    fi
done

# Check service account exists
echo "Checking service account exists..."
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT" &>/dev/null; then
    echo "ERROR: Service account not found: $SERVICE_ACCOUNT"
    echo "Run 'cd terraform && terraform apply' first"
    exit 1
fi

# Warn if file already exists
if [ -f "$SECRET_FILE" ]; then
    echo "WARNING: $SECRET_FILE already exists, replacing..."
fi

# Generate key and encrypt directly to file
echo "Generating and encrypting service account key..."
gcloud iam service-accounts keys create /dev/stdout \
    --iam-account="$SERVICE_ACCOUNT" 2>/dev/null | \
    sops --encrypt \
        --filename-override "$SECRET_FILE" \
        --input-type json \
        --output-type json \
        --output "$SECRET_FILE" \
        /dev/stdin

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "  Key saved to: $SECRET_FILE"
echo ""
echo "  Next steps:"
echo "    1. Build assets:  ./scripts/build-frappe-assets.sh"
echo "    2. Deploy:        kubectl apply -f apps/frappe/"
echo "    3. Restart pod:   kubectl delete pod -n frappe -l app=frappe"
echo ""
