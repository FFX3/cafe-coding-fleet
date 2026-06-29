#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

echo "Deploying PostgreSQL..."
kubectl apply -f "$ROOT_DIR/apps/postgres/namespace.yaml"
sops --decrypt "$ROOT_DIR/apps/postgres/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/postgres/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/postgres/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/postgres/statefulset.yaml"
kubectl apply -f "$ROOT_DIR/apps/postgres/service.yaml"
kubectl rollout status statefulset/postgres -n postgres --timeout=120s

echo "PostgreSQL ready."
