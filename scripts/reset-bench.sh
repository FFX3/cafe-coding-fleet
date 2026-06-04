#!/usr/bin/env bash
set -euo pipefail

# Reset Frappe bench - clears all data and allows fresh provisioning

echo "WARNING: This will delete all Frappe bench data!"
echo "Press Ctrl+C within 5 seconds to cancel..."
sleep 5

# Get the node name
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

echo "Scaling down Frappe deployment..."
kubectl scale deployment frappe -n frappe --replicas=0 2>/dev/null || true

echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app=frappe -n frappe --timeout=60s 2>/dev/null || true

echo "Clearing bench data on node..."
# SSH to node and clear the directory (adjust for your setup)
# For local development:
if [ -d "/var/mnt/data/frappe" ]; then
    sudo rm -rf /var/mnt/data/frappe/*
    echo "Cleared /var/mnt/data/frappe"
else
    echo "Note: /var/mnt/data/frappe not found locally."
    echo "If running on a remote cluster, SSH to the node and run:"
    echo "  sudo rm -rf /var/mnt/data/frappe/*"
fi

echo ""
echo "To complete reset:"
echo "  1. Drop the site databases in PostgreSQL if needed:"
echo "     ./scripts/db-connect.sh"
echo "     DROP DATABASE crm_db;"
echo "     DROP USER crm_db_user;"
echo ""
echo "  2. Scale deployment back up:"
echo "     kubectl scale deployment frappe -n frappe --replicas=1"
echo ""
echo "The init container will re-provision everything on next startup."
