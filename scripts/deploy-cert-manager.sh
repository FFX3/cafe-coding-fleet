#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CERTS_DIR="$ROOT_DIR/certs"
CONFIG_FILE="$ROOT_DIR/config/domains.yaml"

echo "Deploying cert-manager..."
kubectl apply -f "$ROOT_DIR/apps/cert-manager/deploy.yaml"

echo "Waiting for cert-manager to be ready..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "Creating ClusterIssuers..."
kubectl apply -f "$ROOT_DIR/apps/cert-manager/clusterissuer.yaml"

# Create Cloudflare API token secret for DNS-01 validation (reuse terraform token)
echo "Creating Cloudflare API token secret for DNS-01..."
CF_TOKEN=$(sops -d "$ROOT_DIR/terraform/compute/secrets.enc.yaml" | yq '.cloudflare_api_token')
kubectl create secret generic cloudflare-api-token \
    --namespace=cert-manager \
    --from-literal=api-token="$CF_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

# DNS-01 issuer for wildcard certs
kubectl apply -f "$ROOT_DIR/apps/cert-manager/clusterissuer-dns.yaml"

# Restore backed-up certificates (avoids Let's Encrypt rate limits)
if [[ -f "$CONFIG_FILE" ]]; then
    echo ""
    echo "Restoring stored certificates..."

    SUBDOMAIN_COUNT=$(yq '.subdomains | length' "$CONFIG_FILE")
    RESTORED=0
    SKIPPED=0

    for ((i=0; i<SUBDOMAIN_COUNT; i++)); do
        NAME=$(yq ".subdomains[$i].name" "$CONFIG_FILE")
        NAMESPACE=$(yq ".subdomains[$i].namespace // \"default\"" "$CONFIG_FILE")

        SECRET_NAME="${NAME}-tls"
        CERT_FILE="$CERTS_DIR/${SECRET_NAME}.enc.yaml"

        if [[ -f "$CERT_FILE" ]]; then
            # Create namespace if needed
            kubectl create namespace "$NAMESPACE" 2>/dev/null || true

            echo "  Restoring $SECRET_NAME -> $NAMESPACE"
            if sops --decrypt "$CERT_FILE" | \
                yq ".metadata.name = \"$SECRET_NAME\" | .metadata.namespace = \"$NAMESPACE\"" | \
                kubectl apply -f - 2>/dev/null; then
                ((RESTORED++)) || true
            else
                echo "    Warning: Failed to restore $SECRET_NAME"
                ((SKIPPED++)) || true
            fi
        else
            ((SKIPPED++)) || true
        fi
    done

    if [[ $RESTORED -gt 0 ]]; then
        echo "Certificates restored: $RESTORED restored, $SKIPPED missing (will be requested)"
    fi
fi

echo ""
echo "cert-manager ready."
