# GoTrue (Supabase Auth)

OIDC provider for authentication across cluster services.

## Endpoint

https://auth.justinmcintyre.com

## Asymmetric Key Configuration (JWKS)

GoTrue requires a structured JSON Web Key Set (JWKS) list to dynamically populate its public key infrastructure for OpenID Connect validations. Passing raw PEM strings or simple Base64 strings directly into the secret layer will cause runtime validation crashes or result in empty key arrays (`{"keys":[]}`).

### 1. Generate a New Cryptographic Keypair
Run these native shell commands to establish an uncompromised RSA key block inside your local workspace context:

```bash
# Generate a new 2048-bit RSA private key
openssl genrsa -out tmp/rsa-private.pem 2048

# Extract the corresponding public key
openssl rsa -in tmp/rsa-private.pem -pubout -out tmp/rsa-public.pem
```

### 2. Compile the Structured JWK Array Payload
GoTrue's configuration compiler strictly mandates that public keys require `"key_ops": ["verify"]` and private elements require `"key_ops": ["sign", "verify"]` to actively authorize client handshakes. 

Execute this Node script to mathematically extract your parameters into a continuous, single-line valid JSON string:

```bash
node -e "
const crypto = require('crypto');
const fs = require('fs');
const privateKeyPem = fs.readFileSync('tmp/rsa-private.pem', 'utf8');
const key = crypto.createPrivateKey(privateKeyPem);
const jwk = key.export({ format: 'jwk' });
jwk.kid = 'auth-signing-key';
jwk.use = 'sig';
jwk.alg = 'RS256';
jwk.key_ops = ['sign', 'verify'];
console.log(JSON.stringify([jwk]));
"
```

### 3. Add to Secret Configuration
Open your GitOps configuration block file (`apps/gotrue/secret.enc.yaml`) and append the raw string output directly. **Wrap the complete string in single quotes** to avoid character-escaping issues through the YAML parsing runtime layer:

```yaml
GOTRUE_JWT_KEYS: '[{"key_ops":["sign","verify"],"kty":"RSA","kid":"auth-signing-key","use":"sig","alg":"RS256","n":"...","e":"...","d":"...","p":"...","q":"...","dp":"...","dq":"...","qi":"..."}]'
```

*Note: Keep your legacy `GOTRUE_JWT_SECRET` string variable active to support standard baseline symmetric session verification logic.*

## Secrets Layer Matrix

The `secret.enc.yaml` contains these environment mapping parameters:

| Variable | Type | Description |
|----------|------|-------------|
| `DATABASE_URL` | String | PostgreSQL connection uri string mapped directly to the `auth` cluster namespace schema. |
| `GOTRUE_JWT_KEYS` | JSON String | Strict RFC-compliant JWK dictionary configuration containing structural key operation properties for OIDC token minting. |
| `GOTRUE_JWT_SECRET` | Base64 String | Fallback symmetric validation secret context maintaining internal dashboard routes and backend database lookups. |

## Users Management

Users are defined in `users.enc.yaml` and created via the deploy script (direct DB insert with bcrypt hashing). Public open signup interfaces are completely disabled.

```yaml
users:
  - email: "user@example.com"
    password: "securepassword"
```

## Deploy Commands

Deploy the updated manifest definitions and cycle the active node pods using your Nix pipeline wrapper setup:

```bash
nix run .#deploy-gotrue
```

## Verification

### OIDC Discovery Validation
Ensure all endpoints map successfully by verifying the configuration endpoints:

```bash
curl https://auth.justinmcintyre.com/.well-known/openid-configuration
```

### Cryptographic Public Keys Array
Ensure the array returns your active key details instead of empty brackets (`{"keys":[]}`):

```bash
curl https://justinmcintyre.com
```

### Pod Health Evaluation
Verify container readiness:

```bash
curl https://auth.justinmcintyre.com/health
```

