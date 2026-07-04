#!/usr/bin/env bash
# Source this file to require the nix environment (via nix run or nix develop)

if [[ -z "${INFRA_SHELL:-}" ]]; then
    echo "Error: Missing required tools"
    echo ""
    echo "Run commands via nix:"
    echo "  nix run .#cluster-up"
    echo "  nix run .#local-cluster -- up"
    echo ""
    echo "Or enter the dev shell:"
    echo "  nix develop"
    exit 1
fi

# Set ROOT_DIR from INFRA_ROOT (set by nix run) or derive from script location
# This ensures scripts work when run from nix store or directly
if [[ -n "${INFRA_ROOT:-}" ]]; then
    ROOT_DIR="$INFRA_ROOT"
    export ROOT_DIR
fi

# Get external IP from terraform if available
if [[ -n "${ROOT_DIR:-}" ]] && [[ -d "$ROOT_DIR/terraform/compute" ]]; then
    NODE_IP=$(cd "$ROOT_DIR/terraform/compute" && terraform output -raw controlplane_external_ip 2>/dev/null) || true
    export NODE_IP
fi
