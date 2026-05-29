#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="talos-local"

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
        --workers 0

    echo ""
    echo "Removing control-plane taint (single-node cluster needs to run workloads)..."
    kubectl taint nodes "${CLUSTER_NAME}-controlplane-1" node-role.kubernetes.io/control-plane:NoSchedule-

    echo ""
    echo "Cluster created successfully!"
    echo "Run 'talosctl --nodes 10.5.0.2 health' to check health"
    echo "Run 'kubectl get nodes' to verify Kubernetes is running"
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
