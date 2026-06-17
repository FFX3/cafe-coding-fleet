#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="talos-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

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

check_cluster_exists() {
    # Check for actual Docker containers, not just talosctl metadata
    if docker ps -a --format '{{.Names}}' | grep -q "^${CLUSTER_NAME}-"; then
        echo "Error: Cluster '$CLUSTER_NAME' already exists (Docker containers found)."
        echo ""
        echo "To destroy and recreate:"
        echo "  $0 down && $0 up"
        echo ""
        echo "To check status:"
        echo "  $0 status"
        exit 1
    fi
}

cluster_up() {
    check_docker
    check_cluster_exists

    echo "═══════════════════════════════════════════════════════════════"
    echo "  Creating Local Talos Cluster"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    echo "Creating Talos cluster..."
    talosctl cluster create docker \
        --name "$CLUSTER_NAME" \
        --workers 0 \
        --exposed-ports 80:80/tcp,443:443/tcp

    echo ""
    echo "Removing control-plane taint (single-node cluster needs to run workloads)..."
    kubectl taint nodes "${CLUSTER_NAME}-controlplane-1" node-role.kubernetes.io/control-plane:NoSchedule-

    echo ""
    echo "Installing local-path-provisioner for storage..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
    kubectl label namespace local-path-storage pod-security.kubernetes.io/enforce=privileged --overwrite
    # Configure to use Talos-writable path
    kubectl patch configmap local-path-config -n local-path-storage --type=json \
        -p='[{"op": "replace", "path": "/data/config.json", "value": "{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/var/local-path-provisioner\"]}]}"}]'
    kubectl rollout restart deployment/local-path-provisioner -n local-path-storage
    kubectl rollout status deployment/local-path-provisioner -n local-path-storage --timeout=60s

    echo ""
    echo "Deploying nginx ingress controller..."
    kubectl apply -f "$ROOT_DIR/apps/nginx-ingress/deploy.yaml"

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

    echo ""
    echo "Deploying PostgreSQL..."
    kubectl apply -f "$ROOT_DIR/apps/postgres/namespace.yaml"
    kubectl label namespace postgres pod-security.kubernetes.io/enforce=privileged --overwrite
    # Create test secrets for local environment
    kubectl create secret generic postgres-credentials \
        --namespace postgres \
        --from-literal=POSTGRES_PASSWORD=localtest123 \
        --dry-run=client -o yaml | kubectl apply -f -
    # Use local-path storage instead of hostPath
    kubectl apply -f "$ROOT_DIR/apps/postgres/local/pvc.yaml"
    kubectl apply -f "$ROOT_DIR/apps/postgres/statefulset.yaml"
    kubectl apply -f "$ROOT_DIR/apps/postgres/service.yaml"
    kubectl rollout status statefulset/postgres -n postgres --timeout=120s

    echo ""
    echo "Creating Twenty database and user..."
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='twenty'" | grep -q 1 || \
        kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER twenty WITH ENCRYPTED PASSWORD 'localtest123'"
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='twenty'" | grep -q 1 || \
        kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE twenty OWNER twenty"
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d twenty -c "GRANT ALL ON SCHEMA public TO twenty"

    echo ""
    echo "Deploying Twenty CRM..."
    kubectl apply -f "$ROOT_DIR/apps/twenty/namespace.yaml"
    # Create test secrets for local environment
    kubectl create secret generic twenty-credentials \
        --namespace twenty \
        --from-literal=PG_DATABASE_URL=postgres://twenty:localtest123@postgres.postgres.svc.cluster.local:5432/twenty \
        --from-literal=APP_SECRET=local-test-app-secret-32chars-ok \
        --from-literal=ACCESS_TOKEN_SECRET=local-access-token-secret-32chars \
        --from-literal=LOGIN_TOKEN_SECRET=local-login-token-secret-32chars! \
        --from-literal=REFRESH_TOKEN_SECRET=local-refresh-token-secret-32ch \
        --from-literal=FILE_TOKEN_SECRET=local-file-token-secret-32chars!! \
        --dry-run=client -o yaml | kubectl apply -f -
    # Use local-path storage instead of hostPath
    kubectl apply -f "$ROOT_DIR/apps/twenty/redis/local/pvc.yaml"
    kubectl apply -f "$ROOT_DIR/apps/twenty/redis/statefulset.yaml"
    kubectl apply -f "$ROOT_DIR/apps/twenty/redis/service.yaml"
    kubectl rollout status statefulset/redis -n twenty --timeout=120s
    kubectl apply -f "$ROOT_DIR/apps/twenty/server/local/pvc.yaml"
    kubectl apply -f "$ROOT_DIR/apps/twenty/server/deployment.yaml"
    kubectl apply -f "$ROOT_DIR/apps/twenty/server/service.yaml"
    kubectl apply -f "$ROOT_DIR/apps/twenty/worker/deployment.yaml"
    kubectl apply -f "$ROOT_DIR/apps/twenty/ingress.yaml"
    echo "Waiting for Twenty server to be ready (migrations may take a while)..."
    kubectl rollout status deployment/twenty-server -n twenty --timeout=300s
    kubectl rollout status deployment/twenty-worker -n twenty --timeout=120s

    echo ""
    echo "Waiting for ingress routes to propagate..."
    sleep 3

    echo ""
    echo "Running tests..."
    "$SCRIPT_DIR/test-local.sh"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Local Cluster Ready"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Test apps available at:"
    echo "    https://localhost (with Host: test.justinmcintyre.com)"
    echo "    https://localhost (with Host: test2.justinmcintyre.com)"
    echo ""
    echo "  Twenty CRM available at:"
    echo "    https://localhost (with Host: crm.justinmcintyre.com)"
    echo ""
    echo "  PostgreSQL available at:"
    echo "    postgres.postgres.svc.cluster.local:5432"
    echo ""
}

cluster_down() {
    check_docker
    echo "Destroying local Talos cluster..."
    talosctl cluster destroy --name "$CLUSTER_NAME" || true

    echo "Cleaning up kubeconfig entries..."
    # Remove all talos-local contexts/clusters/users from kubeconfig
    for ctx in $(kubectl config get-contexts -o name 2>/dev/null | grep "talos-local" || true); do
        kubectl config delete-context "$ctx" 2>/dev/null || true
    done
    for cluster in $(kubectl config get-clusters 2>/dev/null | grep "talos-local" || true); do
        kubectl config delete-cluster "$cluster" 2>/dev/null || true
    done
    for user in $(kubectl config view -o jsonpath='{.users[*].name}' 2>/dev/null | tr ' ' '\n' | grep "talos-local" || true); do
        kubectl config delete-user "$user" 2>/dev/null || true
    done

    echo "Cleaning up talosconfig..."
    rm -f ~/.talos/config
    rm -rf ~/.talos/clusters/talos-local*

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
