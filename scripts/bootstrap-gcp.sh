#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TALOS_DIR="$ROOT_DIR/talos"
CLUSTER_NAME="my-cluster"

# Global flag to track if certs were restored (used by monitoring loop)
CERTS_RESTORED=false

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

echo ""
echo "Deploying PostgreSQL..."
kubectl apply -f "$ROOT_DIR/apps/postgres/namespace.yaml"
sops --decrypt "$ROOT_DIR/apps/postgres/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/postgres/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/postgres/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/postgres/statefulset.yaml"
kubectl apply -f "$ROOT_DIR/apps/postgres/service.yaml"
kubectl rollout status statefulset/postgres -n postgres --timeout=120s

echo ""
echo "Creating Twenty database and user..."
# Extract twenty password from PG_DATABASE_URL (format: postgres://user:pass@host:port/db)
TWENTY_PASSWORD=$(sops --decrypt "$ROOT_DIR/apps/twenty/secret.enc.yaml" | grep PG_DATABASE_URL | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/' | tr -d '"')
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_roles WHERE rolname='twenty'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE USER twenty WITH ENCRYPTED PASSWORD '$TWENTY_PASSWORD'"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='twenty'" | grep -q 1 || \
    kubectl exec -n postgres statefulset/postgres -- psql -U postgres -c "CREATE DATABASE twenty OWNER twenty"
kubectl exec -n postgres statefulset/postgres -- psql -U postgres -d twenty -c "GRANT ALL ON SCHEMA public TO twenty"

echo ""
echo "Deploying Twenty CRM..."
kubectl apply -f "$ROOT_DIR/apps/twenty/namespace.yaml"
sops --decrypt "$ROOT_DIR/apps/twenty/secret.enc.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/statefulset.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/redis/service.yaml"
kubectl rollout status statefulset/redis -n twenty --timeout=120s
kubectl apply -f "$ROOT_DIR/apps/twenty/server/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/server/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/server/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/server/service.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/worker/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/twenty/ingress.yaml"
echo "Waiting for Twenty server to be ready (migrations may take a while)..."
kubectl rollout status deployment/twenty-server -n twenty --timeout=300s
kubectl rollout status deployment/twenty-worker -n twenty --timeout=120s

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

# Start monitoring (pass CERTS_RESTORED to the monitoring script)
export CERTS_RESTORED
exec "$SCRIPT_DIR/monitor-status.sh"