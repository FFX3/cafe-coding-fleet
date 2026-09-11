#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${CONFIG_DATABASE_URL:-}" ]]; then
  echo "Error: CONFIG_DATABASE_URL not set"
  exit 1
fi

for sql in "$DIR"/*.sql; do
  [[ -f "$sql" ]] || continue
  echo "Applying: $(basename "$sql")"
  psql "$CONFIG_DATABASE_URL" -f "$sql"
done

echo "Webstudio migrations complete."
