# GoTrue (Supabase Auth)

OIDC provider for authentication across services.

## Endpoint

https://auth.justinmcintyre.com

## JWT Secret Generation

GoTrue requires an **RSA private key** (not a symmetric secret) for OIDC ID token signing. The key must be base64-encoded PEM format.

### Generate a new key:

```bash
# Generate RSA private key (2048-bit)
openssl genrsa 2048 > tmp/rsa-private.pem

# Base64 encode (single line, no wrapping)
base64 -w 0 tmp/rsa-private.pem
```

### Add to secret:

Edit `apps/gotrue/secret.enc.yaml` (use single quotes for the base64 string):

```yaml
GOTRUE_JWT_SECRET: '<base64-encoded-rsa-private-key>'
```

## Secrets

The `secret.enc.yaml` contains:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string (auth schema in main db) |
| `GOTRUE_JWT_SECRET` | Base64-encoded RSA private key PEM for signing JWTs |

## Users

Users are defined in `users.enc.yaml` and created via the deploy script (direct DB insert with bcrypt hashing). Public signup is disabled.

```yaml
users:
  - email: "user@example.com"
    password: "securepassword"
```

## Deploy

```bash
nix run .#deploy-gotrue
```

## OIDC Discovery

```bash
curl https://auth.justinmcintyre.com/.well-known/openid-configuration
```

## Health Check

```bash
curl https://auth.justinmcintyre.com/health
```
