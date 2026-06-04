#!/usr/bin/env bash
set -euo pipefail

# Update Frappe apps and run migrations
# Usage: ./scripts/bench-update.sh [app_name]

APP="${1:-}"

echo "=== Frappe Bench Update ==="

# Get the frappe pod
POD=$(kubectl get pods -n frappe -l app=frappe -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "Error: No Frappe pod found"
    exit 1
fi

echo "Using pod: $POD"

if [ -n "$APP" ]; then
    echo "Updating app: $APP"
    kubectl exec -n frappe "$POD" -c gunicorn -- bash -c "
        cd /home/frappe/frappe-bench
        bench update --apps $APP --pull --build --migrate
    "
else
    echo "Updating all apps..."
    kubectl exec -n frappe "$POD" -c gunicorn -- bash -c "
        cd /home/frappe/frappe-bench
        bench update --pull --build --migrate
    "
fi

echo ""
echo "Update complete!"
