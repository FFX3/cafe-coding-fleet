#!/usr/bin/env bash
# Shared functions for service management
# This file should be sourced, not executed directly

# SERVICES_JSON is set by nix flake apps, or can be passed as env var
if [[ -z "${SERVICES_JSON:-}" ]]; then
  echo "Error: SERVICES_JSON not set. Run via 'nix run .#<command>'" >&2
  exit 1
fi

# Check cluster is reachable
require_cluster() {
  if ! kubectl cluster-info &>/dev/null; then
    echo "$(red "Error: Cannot reach Kubernetes cluster")" >&2
    echo "" >&2
    echo "Make sure the cluster is running:" >&2
    echo "  nix run .#cluster-up" >&2
    echo "" >&2
    exit 1
  fi
}

# ============================================================
# Service Config Queries
# ============================================================

# Get a service's config as JSON
get_service() {
  local name="$1"
  jq -r ".services[\"$name\"] // empty" "$SERVICES_JSON"
}

# Get a service from the 'all' list (includes disabled)
get_service_all() {
  local name="$1"
  jq -r ".all[\"$name\"] // empty" "$SERVICES_JSON"
}

# List enabled services in deploy order
list_services() {
  jq -r '.order[]' "$SERVICES_JSON"
}

# List all services (including disabled)
list_all_services() {
  jq -r '.all | keys[]' "$SERVICES_JSON"
}

# Get service property
get_prop() {
  local name="$1"
  local prop="$2"
  jq -r ".services[\"$name\"].$prop // empty" "$SERVICES_JSON"
}

# Check if service has a build config
has_build() {
  local name="$1"
  [[ -n "$(jq -r ".services[\"$name\"].build // empty" "$SERVICES_JSON")" ]]
}

# ============================================================
# Cluster State Queries
# ============================================================

# Check if a deployment is healthy (has available replicas)
service_healthy() {
  local ns="$1"
  local name="$2"
  local replicas
  replicas=$(kubectl get deployment -n "$ns" "$name" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  [[ "${replicas:-0}" -gt 0 ]]
}

# Get currently deployed image tag
current_image_tag() {
  local ns="$1"
  local deploy="$2"
  kubectl get deployment -n "$ns" "$deploy" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | \
    grep -oE '[^:]+$' || echo "none"
}

# Check if namespace exists
namespace_exists() {
  local ns="$1"
  kubectl get namespace "$ns" &>/dev/null
}

# ============================================================
# Image Management
# ============================================================

# Check if image exists in GCP Artifact Registry
image_exists() {
  local image="$1"
  gcloud artifacts docker images describe "$image" &>/dev/null
}

# Get expected image tag from git commit
get_image_tag() {
  local context="$1"
  git -C "$context" rev-parse --short=9 HEAD
}

# Get registry URL from terraform
get_registry_url() {
  local tf_dir="${INFRA_ROOT}/terraform/compute"
  terraform -chdir="$tf_dir" output -raw registry_url 2>/dev/null
}

# Build full image name
get_full_image() {
  local svc="$1"
  local registry
  registry=$(get_registry_url)

  local build_config
  build_config=$(jq -r ".services[\"$svc\"].build // empty" "$SERVICES_JSON")

  if [[ -z "$build_config" ]]; then
    echo ""
    return
  fi

  local image_name context tag
  image_name=$(echo "$build_config" | jq -r '.image')
  context=$(echo "$build_config" | jq -r '.context')
  tag=$(get_image_tag "${INFRA_ROOT}/$context")

  echo "${registry}/${image_name}:${tag}"
}

# ============================================================
# Dependency Graph
# ============================================================

# Get services that this service depends on
get_deps() {
  local name="$1"
  jq -r ".all[\"$name\"].dependsOn // [] | .[]" "$SERVICES_JSON"
}

# Get services that depend on this service
get_dependents() {
  local name="$1"
  jq -r ".all | to_entries | .[] | select(.value.dependsOn | contains([\"$name\"])) | .key" "$SERVICES_JSON"
}

# ============================================================
# Output Helpers
# ============================================================

# Colored output
red() { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
yellow() { echo -e "\033[0;33m$*\033[0m"; }
blue() { echo -e "\033[0;34m$*\033[0m"; }

# Status indicators
ok() { green "✓"; }
fail() { red "✗"; }
skip() { yellow "○"; }
