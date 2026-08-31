#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIG_DIR="$ROOT_DIR/config/postgres"
APPS_DIR="$ROOT_DIR/apps/postgres"

echo "Deploying PostgreSQL..."
kubectl apply -f "$APPS_DIR/namespace.yaml"
sops --decrypt "$CONFIG_DIR/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$APPS_DIR/pv.yaml"
kubectl apply -f "$APPS_DIR/pvc.yaml"
kubectl apply -f "$APPS_DIR/statefulset.yaml"
kubectl apply -f "$APPS_DIR/service.yaml"
kubectl rollout status statefulset/postgres -n postgres --timeout=120s

echo "PostgreSQL ready."
