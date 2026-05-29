#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TALOS_DIR="$ROOT_DIR/talos"
CLUSTER_NAME="my-cluster"

# Get IP from terraform
cd "$TERRAFORM_DIR"
IP=$(terraform output -raw controlplane_external_ip)

if [[ -z "$IP" ]]; then
    echo "Error: Could not get IP from terraform output"
    echo "Make sure you've run: cd terraform && terraform apply"
    exit 1
fi

echo "Talos GCP Bootstrap"
echo "==================="
echo "Node IP: $IP"
echo ""

# Always regenerate config (IP changes on each deploy)
echo "Generating Talos config..."
rm -f "$TALOS_DIR"/*.yaml "$TALOS_DIR"/talosconfig
talosctl gen config "$CLUSTER_NAME" "https://$IP:6443" --output-dir "$TALOS_DIR"

echo ""
echo "Applying config to node..."
talosctl apply-config --insecure --nodes "$IP" --file "$TALOS_DIR/controlplane.yaml"

echo ""
echo "Waiting for Talos API to be ready..."
sleep 10

echo ""
echo "Bootstrapping etcd..."
talosctl bootstrap --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig"

echo ""
echo "Waiting for cluster to be ready..."
talosctl health --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" --wait-timeout 5m

echo ""
echo "Getting kubeconfig..."
talosctl kubeconfig --nodes "$IP" --endpoints "$IP" --talosconfig "$TALOS_DIR/talosconfig" --force

echo ""
echo "Removing control-plane taint (single-node cluster needs to run workloads)..."
kubectl taint nodes talos-controlplane node-role.kubernetes.io/control-plane:NoSchedule-

echo ""
echo "Done! Verifying cluster..."
kubectl get nodes

echo ""
echo "Cluster is ready!"
echo ""
echo "Useful commands:"
echo "  talosctl --nodes $IP --talosconfig $TALOS_DIR/talosconfig health"
echo "  talosctl --nodes $IP --talosconfig $TALOS_DIR/talosconfig dashboard"
echo "  kubectl get pods -A"
