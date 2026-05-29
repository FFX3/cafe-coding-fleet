#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="talos-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 {up|down|status}"
    echo ""
    echo "Commands:"
    echo "  up      Create a local Talos cluster using Docker"
    echo "  down    Destroy the local Talos cluster"
    echo "  status  Show cluster status"
    echo ""
    echo "Requires: Docker running, user in 'docker' group"
    exit 1
}

check_docker() {
    if ! docker info &>/dev/null; then
        echo "Error: Docker is not running or you don't have permission"
        echo "Make sure Docker is running and you're in the 'docker' group:"
        echo "  sudo usermod -aG docker \$USER"
        echo "Then log out and back in."
        exit 1
    fi
}

cluster_up() {
    check_docker
    echo "Creating local Talos cluster..."
    talosctl cluster create docker \
        --name "$CLUSTER_NAME" \
        --workers 0 \
        --exposed-ports 80:80/tcp,443:443/tcp

    echo ""
    echo "Removing control-plane taint (single-node cluster needs to run workloads)..."
    kubectl taint nodes "${CLUSTER_NAME}-controlplane-1" node-role.kubernetes.io/control-plane:NoSchedule-

    echo ""
    echo "Deploying nginx ingress controller..."
    kubectl apply -f "$SCRIPT_DIR/../apps/nginx-ingress/deploy.yaml"

    # Allow hostNetwork in ingress-nginx namespace. Required for the controller
    # to bind directly to ports 80/443. This is the standard pattern for
    # bare-metal/single-node ingress - only affects this namespace.
    echo "Configuring ingress-nginx namespace for hostNetwork..."
    kubectl label namespace ingress-nginx \
        pod-security.kubernetes.io/enforce=privileged \
        --overwrite

    echo "Patching ingress controller for hostNetwork..."
    kubectl patch deployment -n ingress-nginx ingress-nginx-controller \
        --patch-file "$SCRIPT_DIR/../apps/nginx-ingress/hostnetwork-patch.yaml"

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
    kubectl apply -f "$SCRIPT_DIR/../apps/cert-manager/deploy.yaml"

    echo "Waiting for cert-manager to be ready..."
    kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
    kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

    echo "Creating ClusterIssuer..."
    kubectl apply -f "$SCRIPT_DIR/../apps/cert-manager/clusterissuer.yaml"

    echo ""
    echo "Deploying test apps..."
    kubectl apply -f "$SCRIPT_DIR/../apps/test-app/"
    kubectl apply -f "$SCRIPT_DIR/../apps/test-app-2/"

    echo "Waiting for test apps to be ready..."
    kubectl rollout status deployment/test-app --timeout=60s
    kubectl rollout status deployment/test-app-2 --timeout=60s

    echo "Waiting for ingress routes to propagate..."
    sleep 3

    echo ""
    echo "Running tests..."
    "$SCRIPT_DIR/test-local.sh"
}

cluster_down() {
    check_docker
    echo "Destroying local Talos cluster..."
    talosctl cluster destroy --name "$CLUSTER_NAME"
    echo "Cluster destroyed."
}

cluster_status() {
    echo "Checking cluster status..."
    talosctl cluster show --name "$CLUSTER_NAME" 2>/dev/null || {
        echo "Cluster '$CLUSTER_NAME' not found or not running."
        exit 1
    }
}

case "${1:-}" in
    up)
        cluster_up
        ;;
    down)
        cluster_down
        ;;
    status)
        cluster_status
        ;;
    *)
        usage
        ;;
esac
