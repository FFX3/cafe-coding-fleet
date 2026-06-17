#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"
TALOS_DIR="$ROOT_DIR/talos"
CLUSTER_NAME="my-cluster"

# Global flag to track if certs were restored (used by monitoring loop)
CERTS_RESTORED=false

# Get IP from terraform
cd "$TERRAFORM_DIR"
IP=$(terraform output -raw controlplane_external_ip)

if [[ -z "$IP" ]]; then
    echo "Error: Could not get IP from terraform output"
    echo "Make sure you've run: cd terraform/compute && terraform apply"
    exit 1
fi

echo "Talos GCP Bootstrap"
echo "==================="
echo "Node IP: $IP"
echo ""

# Check if cluster is already running with existing config
CLUSTER_RUNNING=false
if [[ -f "$TALOS_DIR/talosconfig" ]]; then
    echo "Checking if cluster is already running..."
    if talosctl health --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" --wait-timeout 10s &>/dev/null; then
        echo "Cluster is already running, skipping bootstrap."
        CLUSTER_RUNNING=true
        # Ensure kubeconfig is up to date
        talosctl kubeconfig --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" --force
    fi
fi

if [[ "$CLUSTER_RUNNING" == "false" ]]; then
    # Generate config (IP changes on each deploy)
    echo "Generating Talos config..."
    rm -f "$TALOS_DIR"/*.yaml "$TALOS_DIR"/talosconfig
    talosctl gen config "$CLUSTER_NAME" "https://$IP:6443" \
        --output-dir "$TALOS_DIR" \
        --config-patch @"$TALOS_DIR/patches/disk-mount.yaml"

    echo ""
    echo "Applying config to node..."
    talosctl apply-config --insecure --nodes "$IP" --file "$TALOS_DIR/controlplane.yaml"

    echo ""
    echo "Bootstrapping etcd..."
    for i in {1..30}; do
        if talosctl bootstrap --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" 2>&1; then
            break
        fi
        if [[ $i -eq 30 ]]; then
            echo "Bootstrap failed after 30 attempts"
            exit 1
        fi
        echo "Bootstrap not ready yet, retrying in 5s... ($i/30)"
        sleep 5
    done

    echo ""
    echo "Waiting for cluster to be ready..."
    talosctl health --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" --wait-timeout 5m

    echo ""
    echo "Getting kubeconfig..."
    talosctl kubeconfig --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" --force

    echo ""
    echo "Removing control-plane taint (single-node cluster needs to run workloads)..."
    kubectl taint nodes talos-controlplane node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true

    echo ""
    echo "Verifying cluster..."
    kubectl get nodes
fi

# Deploy infrastructure components
echo ""
"$ROOT_DIR/scripts/deploy-ingress.sh"

echo ""
"$ROOT_DIR/scripts/deploy-cert-manager.sh"

# Create namespaces that will hold TLS certificates (before restoring certs)
echo ""
echo "Creating application namespaces..."
kubectl apply -f "$ROOT_DIR/apps/postgres/namespace.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/namespace.yaml"

# Restore certificates if available (before deploying apps that create ingresses)
restore_certificates() {
    local CERTS_DIR="$ROOT_DIR/certs"

    if ! ls "$CERTS_DIR"/*.enc.yaml >/dev/null 2>&1; then
        echo ""
        echo "No stored certificates found, new ones will be requested from Let's Encrypt"
        echo ""
        return 0
    fi

    echo ""
    echo "Restoring stored certificates..."
    for cert_file in "$CERTS_DIR"/*.enc.yaml; do
        local secret_name=$(basename "$cert_file" .enc.yaml)
        echo "  Restoring $secret_name..."
        sops --decrypt "$cert_file" | kubectl apply -f -
    done
    CERTS_RESTORED=true
    echo "Certificates restored"
    echo ""
}

restore_certificates

# Deploy applications
echo ""
"$ROOT_DIR/scripts/deploy-postgres.sh"

echo ""
"$ROOT_DIR/scripts/deploy-twenty.sh"

echo ""
"$ROOT_DIR/scripts/deploy-test-apps.sh"

echo "Waiting for ingress routes to propagate..."
sleep 3

echo ""
echo "Cluster is ready!"
echo ""
echo "Test the ingress:"
echo "  curl http://test.justinmcintyre.com"
echo "  curl http://test2.justinmcintyre.com"
echo ""
echo "Test HTTPS (after certificates are issued):"
echo "  curl https://test.justinmcintyre.com"
echo "  curl https://test2.justinmcintyre.com"
echo ""
echo "Check certificate status:"
echo "  kubectl get certificate -A"
echo ""
echo "Useful commands:"
echo "  talosctl --nodes $IP --talosconfig $TALOS_DIR/talosconfig health"
echo "  talosctl --nodes $IP --talosconfig $TALOS_DIR/talosconfig dashboard"
echo "  kubectl get pods -A"

# Start monitoring (pass CERTS_RESTORED to the monitoring script)
export CERTS_RESTORED
exec "$ROOT_DIR/scripts/monitor-status.sh"
