#!/usr/bin/env bash
# Source this file to require the nix develop shell

if [[ -z "${INFRA_SHELL:-}" ]]; then
    echo "Error: Must run inside nix develop shell"
    echo "Run: nix develop"
    exit 1
fi
