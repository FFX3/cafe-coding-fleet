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

# Create namespaces that may have certificates to restore
echo ""
echo "Creating namespaces for certificate restoration..."
kubectl apply -f "$ROOT_DIR/apps/frappe/namespace.yaml"

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
echo "Deploying test apps..."
kubectl apply -f "$ROOT_DIR/apps/test-app/"
kubectl apply -f "$ROOT_DIR/apps/test-app-2/"

echo "Waiting for test apps to be ready..."
kubectl rollout status deployment/test-app --timeout=60s
kubectl rollout status deployment/test-app-2 --timeout=60s

echo ""
echo "Deploying Frappe..."
# Namespace already created earlier for cert restoration
sops --decrypt "$ROOT_DIR/apps/frappe/secret.enc.yaml" | kubectl apply -f -

# Create GCS credentials secret from encrypted JSON
echo "Creating GCS credentials secret..."
kubectl create secret generic frappe-gcs-credentials \
    --namespace frappe \
    --from-file=gcs-service-account.json=<(sops --decrypt "$ROOT_DIR/apps/frappe/gcs-key.enc.json") \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/apps/frappe/pv.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/pvc.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/redis.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/sites-config.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/provision-script.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/deployment.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/service.yaml"
kubectl apply -f "$ROOT_DIR/apps/frappe/ingress.yaml"

echo "Waiting for Frappe Redis to be ready..."
kubectl rollout status deployment/redis -n frappe --timeout=120s

echo "Waiting for Frappe to be ready (streaming init logs)..."

wait_for_frappe() {
    local timeout=1200
    local start_time=$(date +%s)

    # Wait for pod to exist
    echo "Waiting for Frappe pod..."
    while true; do
        local pod_name=$(kubectl get pod -n frappe -l app=frappe -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        [[ -n "$pod_name" ]] && break
        sleep 2
    done
    echo "Pod: $pod_name"

    # Wait for provision-sites container to start, then follow its logs
    echo "Waiting for provisioning container..."
    while ! kubectl logs -n frappe "$pod_name" -c provision-sites 2>&1 | grep -q "Starting"; do
        sleep 2
    done

    # Stream logs until container exits
    echo ""
    echo "=== Frappe Provisioning Logs ==="
    kubectl logs -n frappe "$pod_name" -c provision-sites -f 2>/dev/null || true
    echo "=== End Provisioning Logs ==="
    echo ""

    # Wait for deployment to be ready
    echo "Waiting for Frappe deployment to be ready..."
    kubectl rollout status deployment/frappe -n frappe --timeout="${timeout}s"
}

wait_for_frappe

echo "Waiting for ingress routes to propagate..."
sleep 3

echo ""
echo "Cluster is ready!"
echo ""
echo "Test the ingress:"
echo "  curl http://test.justinmcintyre.com"
echo "  curl http://test2.justinmcintyre.com"
echo "  curl http://frappe.justinmcintyre.com"
echo ""
echo "Test HTTPS (after certificates are issued):"
echo "  curl https://test.justinmcintyre.com"
echo "  curl https://test2.justinmcintyre.com"
echo "  curl https://frappe.justinmcintyre.com"
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