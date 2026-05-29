# SSL/TLS Certificates with cert-manager

This document covers how SSL certificates are automatically provisioned and managed using cert-manager with Let's Encrypt.

## How It Works

```
Ingress with TLS annotation → cert-manager detects it
    ↓
Creates ACME challenge → Let's Encrypt validates via HTTP-01
    ↓
Certificate issued → stored in Secret
    ↓
nginx-ingress uses Secret → HTTPS works
```

1. When an Ingress resource has the `cert-manager.io/cluster-issuer` annotation and a `tls` block, cert-manager automatically creates a Certificate resource
2. cert-manager performs the ACME HTTP-01 challenge by temporarily creating an Ingress route for `/.well-known/acme-challenge/`
3. Let's Encrypt verifies domain ownership by making an HTTP request to that path
4. Once verified, the certificate is issued and stored in the Kubernetes Secret specified in `secretName`
5. nginx-ingress automatically picks up the Secret and serves HTTPS traffic

## ClusterIssuer Configuration

The ClusterIssuer in `apps/cert-manager/clusterissuer.yaml` configures Let's Encrypt production:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: justinmcintyre42@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

- `server`: Let's Encrypt production endpoint (use `acme-staging-v02` for testing)
- `email`: Contact email for certificate expiration notices
- `privateKeySecretRef`: Where to store the ACME account private key
- `solvers`: HTTP-01 challenge using nginx ingress class

## Adding TLS to New Ingress Resources

To enable automatic TLS for a new Ingress:

1. Add the cert-manager annotation:
   ```yaml
   metadata:
     annotations:
       cert-manager.io/cluster-issuer: "letsencrypt-prod"
   ```

2. Add the TLS block:
   ```yaml
   spec:
     tls:
       - hosts:
           - your-domain.example.com
         secretName: your-app-tls
   ```

Example complete Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - my-app.example.com
      secretName: my-app-tls
  rules:
    - host: my-app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Certificate Renewal

Certificates are automatically renewed by cert-manager before expiration:

- Let's Encrypt certificates are valid for 90 days
- cert-manager renews certificates 30 days before expiration
- No manual intervention required

## Troubleshooting

### Check certificate status

```bash
# List all certificates
kubectl get certificate -A

# Detailed certificate info
kubectl describe certificate <name>

# Check certificate requests
kubectl get certificaterequest -A
```

### Check cert-manager logs

```bash
kubectl logs -n cert-manager -l app=cert-manager
```

### Common issues

**Certificate stuck in "Pending" state:**
- Check the CertificateRequest and Order resources
- Verify DNS points to your cluster
- Check that HTTP-01 challenge path is accessible

```bash
kubectl describe certificaterequest <name>
kubectl get order -A
kubectl describe order <name>
```

**ACME challenge failing:**
- Ensure port 80 is accessible from the internet
- Check ingress controller logs
- Verify domain DNS is correctly configured

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Verify certificate details

```bash
# Check certificate expiration
echo | openssl s_client -connect your-domain.com:443 2>/dev/null | openssl x509 -noout -dates

# View full certificate chain
echo | openssl s_client -connect your-domain.com:443 -showcerts 2>/dev/null
```

## Local Development

Let's Encrypt HTTP-01 challenge requires the domain to be publicly reachable. For local Docker clusters:

- Certificates won't be issued (expected behavior)
- HTTP traffic continues to work
- Test HTTPS only on GCP or other cloud deployments

For local SSL testing, consider:
- Self-signed certificates
- mkcert for local CA
- Skip TLS verification in tests

## Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per registered domain per week
- 5 duplicate certificates per week
- 300 new orders per account per 3 hours

Use the staging environment (`acme-staging-v02.api.letsencrypt.org`) for testing to avoid hitting production limits.
