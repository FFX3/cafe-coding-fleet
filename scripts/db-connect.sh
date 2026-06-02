#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="postgres"
SERVICE="postgres"
LOCAL_PORT="${LOCAL_PORT:-5433}"
DATABASE="${1:-postgres}"

cleanup() {
    if [[ -n "${PF_PID:-}" ]] && kill -0 "$PF_PID" 2>/dev/null; then
        echo "Closing port-forward..."
        kill "$PF_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Check postgres pod is running
POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$POD_STATUS" != "Running" ]]; then
    echo "Error: PostgreSQL pod not running (status: $POD_STATUS)"
    exit 1
fi

# Get credentials from secret
POSTGRES_PASSWORD=$(kubectl get secret -n "$NAMESPACE" postgres-credentials -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
POSTGRES_USER=$(kubectl get secret -n "$NAMESPACE" postgres-credentials -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)

# Start port-forward
echo "Starting port-forward (localhost:$LOCAL_PORT -> postgres:5432)..."
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" "$LOCAL_PORT:5432" &
PF_PID=$!
sleep 2

echo "Connecting to database: $DATABASE"
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p "$LOCAL_PORT" -U "$POSTGRES_USER" -d "$DATABASE"
