#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Read domain from config
DOMAIN=$(yq '.domain' "$ROOT_DIR/config/domain.yaml")

# Get credentials from encrypted users file
USERS=$(sops --decrypt "$ROOT_DIR/config/platform-services/users.enc.yaml")
EMAIL=$(echo "$USERS" | grep email | head -1 | sed 's/.*email: *//' | tr -d '"')
PASSWORD=$(echo "$USERS" | grep password | head -1 | sed 's/.*password: *//' | tr -d '"')

echo "Logging in as: $EMAIL"
RESPONSE=$(curl -s -X POST "https://auth.$DOMAIN/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

# Extract access token
ACCESS_TOKEN=$(echo "$RESPONSE" | node -e "const d=require('fs').readFileSync(0,'utf8');try{const j=JSON.parse(d);console.log(j.access_token||'')}catch{console.log('')}")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Login failed:"
  echo "$RESPONSE"
  exit 1
fi

echo "Access Token (JWT):"
echo "$ACCESS_TOKEN"
echo ""
echo "Testing /user endpoint..."
curl -s "https://auth.$DOMAIN/user" -H "Authorization: Bearer $ACCESS_TOKEN" | yq -P

echo ""
echo "Testing /oauth/userinfo endpoint (OIDC standard)..."
curl -s "https://auth.$DOMAIN/oauth/userinfo" -H "Authorization: Bearer $ACCESS_TOKEN" | yq -P

# Export token for other scripts
export ACCESS_TOKEN
