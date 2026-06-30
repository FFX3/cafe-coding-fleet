# Hermes AI Agent

Hermes is a local AI agent deployed on the cluster with persistent storage and database access.

## Quick Access

```bash
nix run .#hermes
```

Or with arguments:

```bash
nix run .#hermes -- --help
```

## Architecture

- **Container**: `nousresearch/hermes-agent:latest`
- **Storage**: 5Gi PVC at `/data` (HERMES_HOME)
- **Database**: PostgreSQL (shared instance, dedicated `hermes` database)
- **Namespace**: `hermes`

## Configuration

### Secret Setup

Create or edit the credentials:

```bash
sops apps/hermes/secret.enc.yaml
```

Required content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hermes-credentials
  namespace: hermes
type: Opaque
stringData:
  ANTHROPIC_API_KEY: "sk-ant-..."
  PG_DATABASE_URL: "postgresql://hermes:YOUR_PASSWORD@postgres.postgres.svc.cluster.local:5432/hermes"
```

### Adding More Providers

Edit the secret to add additional API keys:

```yaml
stringData:
  ANTHROPIC_API_KEY: "sk-ant-..."
  OPENAI_API_KEY: "sk-..."
  PG_DATABASE_URL: "postgresql://hermes:password@postgres.postgres.svc.cluster.local:5432/hermes"
```

Redeploy to apply:

```bash
nix run .#deploy-hermes
```

## Deployment

Hermes is deployed automatically during `cluster-up`:

```bash
nix run .#cluster-up
```

Or deploy individually:

```bash
nix run .#deploy-hermes
```

The deploy script:
1. Creates the PostgreSQL database and user (if not exists)
2. Deploys the namespace, secret, PV, PVC, and deployment
3. Waits for the pod to be ready

## Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| Memory | 256Mi | 1Gi |
| CPU | 50m | 500m |

## Files

| File | Purpose |
|------|---------|
| `apps/hermes/namespace.yaml` | Kubernetes namespace |
| `apps/hermes/pv.yaml` | Persistent volume (hostPath) |
| `apps/hermes/pvc.yaml` | Persistent volume claim |
| `apps/hermes/deployment.yaml` | Main deployment |
| `apps/hermes/secret.enc.yaml` | SOPS-encrypted credentials |
| `scripts/deploy-hermes.sh` | Deployment script |
| `scripts/hermes.sh` | TUI access script |

## Troubleshooting

### Permission Denied on /data

The init container fixes permissions. If you see this error, wipe the PVC:

```bash
# See docs/wipe-pvc.md for full instructions
kubectl scale deployment/hermes -n hermes --replicas=0
# ... run wipe pod ...
kubectl scale deployment/hermes -n hermes --replicas=1
```

### No Provider Configured

Check that your secret has the API keys:

```bash
kubectl get secret -n hermes hermes-credentials -o yaml
```

Keys should be base64 encoded. Verify with:

```bash
kubectl get secret -n hermes hermes-credentials -o jsonpath='{.data.ANTHROPIC_API_KEY}' | base64 -d
```

### Pod Not Starting

Check pod status and logs:

```bash
kubectl get pods -n hermes
kubectl describe pod -n hermes -l app=hermes
kubectl logs -n hermes deployment/hermes
```

### Database Connection Issues

Verify PostgreSQL is running and the hermes database exists:

```bash
nix run .#db-connect -- hermes
```

If the database doesn't exist, redeploy Hermes:

```bash
nix run .#deploy-hermes
```

## Future Plans

- Matrix integration for chat interface
- Additional model providers
