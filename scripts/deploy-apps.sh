#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying applications..."
echo ""

"$SCRIPT_DIR/deploy-command-center.sh"
echo ""

"$SCRIPT_DIR/deploy-postgres.sh"
echo ""

"$SCRIPT_DIR/deploy-gotrue.sh"
echo ""

"$SCRIPT_DIR/deploy-studio.sh"
echo ""

"$SCRIPT_DIR/deploy-twenty.sh"
echo ""

"$SCRIPT_DIR/deploy-conduit.sh"
echo ""

"$SCRIPT_DIR/deploy-hermes.sh"
echo ""

"$SCRIPT_DIR/deploy-test-apps.sh"
echo ""

echo "All applications deployed."
