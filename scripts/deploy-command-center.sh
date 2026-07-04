#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

echo "Deploying command-center..."

kubectl apply -f "$ROOT_DIR/command-center/namespace.yaml"
kubectl label namespace command-center \
    pod-security.kubernetes.io/enforce=privileged \
    --overwrite
kubectl apply -f "$ROOT_DIR/command-center/priority-class.yaml"
sops --decrypt "$ROOT_DIR/command-center/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/command-center/pv.yaml"
kubectl apply -f "$ROOT_DIR/command-center/pvc.yaml"
kubectl apply -f "$ROOT_DIR/command-center/deployment.yaml"
kubectl apply -f "$ROOT_DIR/command-center/service.yaml"

echo ""
echo "Command center deployed (replicas: 0)"
echo "Connect with: ./scripts/shell-connect.sh"
