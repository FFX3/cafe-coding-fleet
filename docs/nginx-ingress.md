# Nginx Ingress Controller

This cluster uses the [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/) for routing HTTP traffic to services based on hostname.

## How It Works

```
Internet → Node IP:80 → nginx-ingress pod → Service → App Pod
                ↑
        Host header determines routing
```

1. DNS points `test.justinmcintyre.com` to the node's IP
2. Traffic hits port 80 on the node
3. nginx-ingress reads the `Host` header
4. Routes to the correct backend service based on Ingress rules

## Host Network Mode

We use `hostNetwork: true` on the ingress controller, which is the [recommended approach for bare-metal/single-node clusters](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#via-the-host-network).

### Why hostNetwork?

Without hostNetwork, nginx-ingress uses a NodePort service (high port like 31311). Options to get port 80:

| Method | Description | Trade-off |
|--------|-------------|-----------|
| **hostNetwork** | Pod binds directly to node's port 80/443 | Requires privileged namespace |
| **NodePort** | Use high port (30000-32767) | Ugly URLs like `site.com:31311` |
| **LoadBalancer** | Cloud provider creates external LB | Costs ~$18/mo on GCP |
| **MetalLB** | Software LB for bare metal | Additional complexity |

For a single-node setup, hostNetwork is simplest and free.

**Note:** With hostNetwork, only one ingress pod can run per node (they'd compete for port 80). For multi-node HA, you'd convert the Deployment to a DaemonSet, which runs one pod per node. Not relevant for single-node, but worth knowing.*

### Namespace Security Label

The `ingress-nginx` namespace is labeled to allow hostNetwork:

```bash
kubectl label namespace ingress-nginx pod-security.kubernetes.io/enforce=privileged
```

This only affects the `ingress-nginx` namespace. Other namespaces (like `default`) still enforce stricter policies. The ingress controller legitimately needs host network access to receive external traffic.

## Files

| File | Purpose |
|------|---------|
| `apps/nginx-ingress/deploy.yaml` | Upstream manifest (v1.10.0) |
| `apps/nginx-ingress/hostnetwork-patch.yaml` | Enables hostNetwork mode |

## Adding a New Ingress

To route a new hostname to a service, create an Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.justinmcintyre.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

Then add a DNS record pointing `myapp.justinmcintyre.com` to your node's IP (in `terraform/cloudflare.tf`).

## Viewing nginx Configuration

The controller generates nginx.conf from your Ingress resources. To inspect:

```bash
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf
```

## Troubleshooting

### 404 Not Found

- Check the Ingress exists: `kubectl get ingress`
- Verify the Host header matches exactly
- Check the backend service exists and has endpoints

### 503 Service Unavailable

- Backend pods aren't ready: `kubectl get pods`
- Service selector doesn't match pod labels

### Connection refused on port 80

- Ingress controller not running: `kubectl get pods -n ingress-nginx`
- hostNetwork patch not applied
- Firewall blocking port 80

## References

- [Ingress-nginx bare metal considerations](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)
- [Via the host network](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#via-the-host-network)
