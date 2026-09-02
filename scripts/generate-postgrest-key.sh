#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

echo "Fetching GoTrue private key from Kubernetes secret..."
# The secret value is base64-encoded, and the content itself is also base64-encoded PEM
PRIVATE_KEY_B64=$(kubectl get secret -n platform-services gotrue-credentials -o jsonpath='{.data.GOTRUE_JWT_SECRET}' | base64 -d)
PRIVATE_KEY=$(echo "$PRIVATE_KEY_B64" | base64 -d)

if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: Could not get GOTRUE_JWT_SECRET from secret"
  exit 1
fi

echo "Got private key (PEM format)"

echo "Generating RS256-signed JWT..."
JWT=$(node -e "
const crypto = require('crypto');

const privateKeyPem = \`$PRIVATE_KEY\`;

const header = {
  alg: 'RS256',
  typ: 'JWT',
  kid: 'auth-signing-key'
};

const now = Math.floor(Date.now() / 1000);
const payload = {
  role: 'authenticated',
  aud: 'authenticated',
  iat: now,
  exp: now + (10 * 365 * 24 * 60 * 60) // 10 years
};

const base64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const headerB64 = base64url(header);
const payloadB64 = base64url(payload);
const message = headerB64 + '.' + payloadB64;

const sign = crypto.createSign('RSA-SHA256');
sign.update(message);
const signature = sign.sign(privateKeyPem, 'base64url');

console.log(message + '.' + signature);
")

echo ""
echo "POSTGREST_API_KEY:"
echo "$JWT"
echo ""
echo "To update the secret, run:"
echo "  sops config/webstudio/secret.enc.yaml"
echo "  # Replace POSTGREST_API_KEY value with the JWT above"
