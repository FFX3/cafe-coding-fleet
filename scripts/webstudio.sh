#!/usr/bin/env bash
set -euo pipefail

# Webstudio CLI wrapper - runs CLI from fork
# INFRA_ROOT is set by the nix flake app wrapper
ROOT_DIR="${INFRA_ROOT:-$PWD}"
WEBSTUDIO_DIR="$ROOT_DIR/forks/webstudio"
CLI_DIR="$WEBSTUDIO_DIR/packages/cli"

# Check if CLI is built
if [[ ! -f "$CLI_DIR/lib/main.js" ]]; then
    echo "Building Webstudio CLI from fork..."
    cd "$WEBSTUDIO_DIR"
    pnpm install
    pnpm --filter='@webstudio-is/cli...' build
fi

# Run the CLI
exec node "$CLI_DIR/bin.js" "$@"
