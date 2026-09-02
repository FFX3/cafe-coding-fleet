#!/usr/bin/env bash
# Backup TLS certificates from cluster to certs/ directory
# Reads config/domains.yaml and exports matching secrets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
CONFIG_FILE="$ROOT_DIR/config/domains.yaml"
CERTS_DIR="$ROOT_DIR/certs"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

mkdir -p "$CERTS_DIR"

echo "Backing up TLS certificates..."
echo ""

SUBDOMAIN_COUNT=$(yq '.subdomains | length' "$CONFIG_FILE")
BACKED_UP=0
SKIPPED=0

for ((i=0; i<SUBDOMAIN_COUNT; i++)); do
    NAME=$(yq ".subdomains[$i].name" "$CONFIG_FILE")
    NAMESPACE=$(yq ".subdomains[$i].namespace // \"default\"" "$CONFIG_FILE")

    SECRET_NAME="${NAME}-tls"
    CERT_FILE="$CERTS_DIR/${SECRET_NAME}.enc.yaml"

    # Check if secret exists in cluster
    if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "  Backing up: $SECRET_NAME ($NAMESPACE)"

        # Export and encrypt with sops
        kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml | \
            sops --encrypt /dev/stdin > "$CERT_FILE"

        ((BACKED_UP++))
    else
        echo "  Skipping: $SECRET_NAME (not found in $NAMESPACE)"
        ((SKIPPED++))
    fi
done

echo ""
echo "Backup complete: $BACKED_UP backed up, $SKIPPED skipped"
