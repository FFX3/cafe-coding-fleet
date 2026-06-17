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
