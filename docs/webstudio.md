# Webstudio

Visual website builder (Webflow alternative).

## PostgREST API Key

Webstudio uses PostgREST for database access. It requires a service JWT (`POSTGREST_API_KEY`) signed with the same secret as GoTrue.

### Generate the key

```bash
# Get the JWT secret from GoTrue config
JWT_SECRET=$(sops --decrypt config/platform-services/secret.enc.yaml | grep GOTRUE_JWT_SECRET | sed 's/.*: *//' | tr -d '"')

# Generate a service JWT with 10-year expiry
node -e "
const crypto = require('crypto');
const secret = process.argv[1];
const header = Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
const payload = Buffer.from(JSON.stringify({role:'authenticated',aud:'authenticated',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+315360000})).toString('base64url');
const sig = crypto.createHmac('sha256',secret).update(header+'.'+payload).digest('base64url');
console.log(header+'.'+payload+'.'+sig);
" "$JWT_SECRET"
```

### Add to secrets

Add the generated JWT to `config/webstudio/secret.enc.yaml`:

```yaml
POSTGREST_API_KEY: "eyJhbGc..."
```

Then redeploy:

```bash
./scripts/deploy-webstudio.sh
```
