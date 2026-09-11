#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Expects these from apply-config-migrations.sh:
# PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE (admin connection)
# APP_DB_USER (app user to grant permissions to)

if [[ -z "${PGDATABASE:-}" ]]; then
  echo "Error: PGDATABASE not set"
  exit 1
fi

if [[ -z "${APP_DB_USER:-}" ]]; then
  echo "Error: APP_DB_USER not set"
  exit 1
fi

for sql in "$DIR"/*.sql; do
  [[ -f "$sql" ]] || continue
  echo "  Applying: $(basename "$sql")"
  psql -v ON_ERROR_STOP=1 -f "$sql"
done

# Grant SELECT on deployment_targets to app user
echo "  Granting SELECT on deployment_targets to $APP_DB_USER"
psql -v ON_ERROR_STOP=1 -c "GRANT SELECT ON deployment_targets TO \"$APP_DB_USER\";"

echo "Webstudio migrations complete."
