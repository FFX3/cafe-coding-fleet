#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$ROOT_DIR/certs"

mkdir -p "$CERTS_DIR"

# List of certificate secrets to export
CERT_SECRETS=("test-app-tls" "test-app-2-tls")

for secret in "${CERT_SECRETS[@]}"; do
    echo "Exporting $secret..."

    # Check if certificate is ready
    status=$(kubectl get certificate "$secret" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [[ "$status" != "True" ]]; then
        echo "  Warning: Certificate $secret is not ready, skipping"
        continue
    fi

    # Export secret (strip cluster-specific metadata) directly to .enc.yaml
    # (SOPS matches rules based on filename)
    kubectl get secret "$secret" -o yaml | \
        grep -v '^\s*creationTimestamp:' | \
        grep -v '^\s*resourceVersion:' | \
        grep -v '^\s*uid:' | \
        grep -v '^\s*namespace:' > "$CERTS_DIR/$secret.enc.yaml"

    # Encrypt with SOPS in place
    sops --encrypt --in-place "$CERTS_DIR/$secret.enc.yaml"

    echo "  Saved to certs/$secret.enc.yaml"
done

echo ""
echo "Done! Commit the certs/*.enc.yaml files to your repo."
