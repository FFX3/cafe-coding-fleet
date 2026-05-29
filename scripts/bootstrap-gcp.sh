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
echo "Deploying nginx ingress controller..."
kubectl apply -f "$ROOT_DIR/apps/nginx-ingress/deploy.yaml"

# Allow hostNetwork in ingress-nginx namespace. Required for the controller
# to bind directly to ports 80/443. This is the standard pattern for
# bare-metal/single-node ingress - only affects this namespace.
echo "Configuring ingress-nginx namespace for hostNetwork..."
kubectl label namespace ingress-nginx \
    pod-security.kubernetes.io/enforce=privileged \
    --overwrite

echo "Patching ingress controller for hostNetwork..."
kubectl patch deployment -n ingress-nginx ingress-nginx-controller \
    --patch-file "$ROOT_DIR/apps/nginx-ingress/hostnetwork-patch.yaml"

echo ""
echo "Waiting for ingress controller rollout..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=120s

echo "Waiting for admission webhook to be ready..."
until kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q .; do
  sleep 1
done
# Webhook endpoint exists but server needs a moment to start accepting connections
sleep 5

echo ""
echo "Deploying cert-manager..."
kubectl apply -f "$ROOT_DIR/apps/cert-manager/deploy.yaml"

echo "Waiting for cert-manager to be ready..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "Creating ClusterIssuer..."
kubectl apply -f "$ROOT_DIR/apps/cert-manager/clusterissuer.yaml"

echo ""
echo "Deploying test apps..."
kubectl apply -f "$ROOT_DIR/apps/test-app/"
kubectl apply -f "$ROOT_DIR/apps/test-app-2/"

echo "Waiting for test apps to be ready..."
kubectl rollout status deployment/test-app --timeout=60s
kubectl rollout status deployment/test-app-2 --timeout=60s

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
