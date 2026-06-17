#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Deploying nginx ingress controller..."
kubectl apply -f "$ROOT_DIR/apps/nginx-ingress/deploy.yaml"

echo "Configuring ingress-nginx namespace for hostNetwork..."
kubectl label namespace ingress-nginx \
    pod-security.kubernetes.io/enforce=privileged \
    --overwrite

echo "Patching ingress controller for hostNetwork..."
kubectl patch deployment -n ingress-nginx ingress-nginx-controller \
    --patch-file "$ROOT_DIR/apps/nginx-ingress/hostnetwork-patch.yaml"

echo "Waiting for ingress controller rollout..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=120s

echo "Waiting for admission webhook to be ready..."
until kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q .; do
  sleep 1
done
sleep 5

echo "Ingress controller ready."
