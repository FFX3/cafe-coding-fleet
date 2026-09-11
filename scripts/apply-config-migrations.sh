#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

ROOT_DIR="${INFRA_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "Applying config migrations..."
echo "=============================="

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
    export CONFIG_DATABASE_URL=$(sops --decrypt "$SECRET_FILE" | yq '.stringData.CONFIG_DATABASE_URL')

    if [[ -z "$CONFIG_DATABASE_URL" || "$CONFIG_DATABASE_URL" == "null" ]]; then
        echo "Warning: CONFIG_DATABASE_URL not found in $SECRET_FILE, skipping"
        continue
    fi

    FOUND=1
    echo ""
    echo "→ $migrations_dir/run.sh"
    bash "$migrations_dir/run.sh"
done

if [[ "$FOUND" -eq 0 ]]; then
    echo "No config migrations found"
    exit 0
fi

echo ""
echo "=============================="
echo "All config migrations applied."
