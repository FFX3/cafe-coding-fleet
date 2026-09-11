#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

ROOT_DIR="${INFRA_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCAL_PORT="${LOCAL_PORT:-5433}"
NAMESPACE="postgres"
SERVICE="postgres"

cleanup() {
    if [[ -n "${PF_PID:-}" ]] && kill -0 "$PF_PID" 2>/dev/null; then
        echo "Closing port-forward..."
        kill "$PF_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

echo "Applying config migrations..."
echo "=============================="

# Check postgres pod is running
POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$POD_STATUS" != "Running" ]]; then
    echo "Error: PostgreSQL pod not running (status: $POD_STATUS)"
    exit 1
fi

# Get admin credentials
PGPASSWORD=$(kubectl get secret -n "$NAMESPACE" postgres-credentials -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
PGUSER=$(kubectl get secret -n "$NAMESPACE" postgres-credentials -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)
export PGPASSWORD PGUSER
export PGHOST="localhost"
export PGPORT="$LOCAL_PORT"

# Start port-forward
echo "Starting port-forward (localhost:$LOCAL_PORT -> postgres:5432)..."
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" "$LOCAL_PORT:5432" &>/dev/null &
PF_PID=$!
sleep 2

FOUND=0
for migrations_dir in "$ROOT_DIR"/config/*/migrations; do
    [[ -d "$migrations_dir" ]] || continue
    [[ -x "$migrations_dir/run.sh" ]] || continue

    CONFIG_DIR="$(dirname "$migrations_dir")"
    SECRET_FILE="$CONFIG_DIR/secret.enc.yaml"

    if [[ ! -f "$SECRET_FILE" ]]; then
        echo "Warning: No secret file at $SECRET_FILE, skipping"
        continue
    fi

    # Decrypt and extract CONFIG_DATABASE_URL
    CONFIG_DATABASE_URL=$(sops --decrypt "$SECRET_FILE" | yq '.stringData.CONFIG_DATABASE_URL')

    if [[ -z "$CONFIG_DATABASE_URL" || "$CONFIG_DATABASE_URL" == "null" ]]; then
        echo "Warning: CONFIG_DATABASE_URL not found in $SECRET_FILE, skipping"
        continue
    fi

    # Parse app user and database from URL
    export APP_DB_USER=$(echo "$CONFIG_DATABASE_URL" | sed -E 's|.*://([^:]+):.*|\1|')
    export PGDATABASE=$(echo "$CONFIG_DATABASE_URL" | sed -E 's|.*/([^/?]+).*|\1|')

    FOUND=1
    echo ""
    echo "→ $migrations_dir/run.sh (database: $PGDATABASE, app_user: $APP_DB_USER)"
    bash "$migrations_dir/run.sh"
done

if [[ "$FOUND" -eq 0 ]]; then
    echo "No config migrations found"
    exit 0
fi

echo ""
echo "=============================="
echo "All config migrations applied."
