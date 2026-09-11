#!/usr/bin/env bash
set -euo pipefail

# Smart cluster deployment
# Usage: nix run .#cluster-deploy [--plan] [service]
#
# Without arguments: deploys all enabled services in order
# With service name: deploys just that service (deps must be healthy)
# With --plan: shows what would be deployed without doing it

source "$(dirname "$0")/lib/services.sh"

PLAN_ONLY=false
TARGET="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN_ONLY=true
      shift
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

require_cluster

# ============================================================
# Plan Functions
# ============================================================

show_plan() {
  echo ""
  echo "Deployment Plan"
  echo "==============="
  echo ""
  printf "%-20s %-12s %-15s %s\n" "SERVICE" "ACTION" "REASON" "NAMESPACE"
  printf "%-20s %-12s %-15s %s\n" "-------" "------" "------" "---------"

  for svc in $(list_services); do
    local ns auto_enabled action reason
    ns=$(get_prop "$svc" "namespace")
    auto_enabled=$(jq -r ".services[\"$svc\"]._autoEnabled // false" "$SERVICES_JSON")

    # Determine action and reason
    if namespace_exists "$ns"; then
      action="update"
      if [[ "$auto_enabled" == "true" ]]; then
        reason="dependency"
      else
        reason="enabled"
      fi
    else
      action="deploy"
      if [[ "$auto_enabled" == "true" ]]; then
        reason="dependency"
      else
        reason="enabled"
      fi
    fi

    # Color the action
    if [[ "$action" == "deploy" ]]; then
      action="$(green "deploy")"
    else
      action="$(yellow "update")"
    fi

    printf "%-20s %-12s %-15s %s\n" "$svc" "$action" "$reason" "$ns"
  done

  echo ""

  # Show disabled services
  local disabled
  disabled=$(jq -r '.all | to_entries | .[] | select(.value.enable == false) | .key' "$SERVICES_JSON" | tr '\n' ' ')
  if [[ -n "$disabled" ]]; then
    echo "Disabled (will skip): $(yellow "$disabled")"
    echo ""
  fi
}

# ============================================================
# Build Functions
# ============================================================

ensure_image() {
  local svc="$1"

  if ! has_build "$svc"; then
    return 0
  fi

  local build_config
  build_config=$(jq -r ".services[\"$svc\"].build" "$SERVICES_JSON")

  local context dockerfile image_name
  context=$(echo "$build_config" | jq -r '.context')
  dockerfile=$(echo "$build_config" | jq -r '.dockerfile')
  image_name=$(echo "$build_config" | jq -r '.image')

  local full_context="${INFRA_ROOT}/${context}"
  local tag
  tag=$(get_image_tag "$full_context")

  local registry
  registry=$(get_registry_url)

  local full_image="${registry}/${image_name}:${tag}"

  echo "    Checking image: $full_image"

  if image_exists "$full_image"; then
    echo "    $(green "Image exists")"
    return 0
  fi

  echo "    $(yellow "Building image...")"

  # Authenticate docker
  gcloud auth configure-docker "${registry%%/*}" --quiet

  # Build
  docker build \
    -f "${full_context}/${dockerfile}" \
    -t "$full_image" \
    "$full_context"

  # Push
  echo "    Pushing image..."
  docker push "$full_image"

  echo "    $(green "Image built and pushed")"
}

# ============================================================
# Deploy Functions
# ============================================================

# Check if this is a first deploy or update
is_first_deploy() {
  local ns="$1"
  ! namespace_exists "$ns"
}

# Get all deployments in namespace
get_deployments() {
  local ns="$1"
  kubectl get deployments -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo ""
}

# Get all statefulsets in namespace
get_statefulsets() {
  local ns="$1"
  kubectl get statefulsets -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo ""
}

deploy_service() {
  local svc="$1"

  echo ""
  echo "==> Deploying: $(blue "$svc")"

  local ns manifests
  ns=$(get_prop "$svc" "namespace")
  manifests=$(get_prop "$svc" "manifests")

  # Ensure image exists (if service has build config)
  ensure_image "$svc"

  # Check for existing deploy script (backwards compat)
  local deploy_script="${INFRA_ROOT}/scripts/deploy-${svc}.sh"
  if [[ -f "$deploy_script" ]]; then
    echo "    Using existing deploy script"
    bash "$deploy_script"
    return $?
  fi

  # Otherwise, apply manifests directly
  local manifests_dir="${INFRA_ROOT}/${manifests}"
  if [[ ! -d "$manifests_dir" ]]; then
    echo "    $(red "Error: manifests directory not found: $manifests_dir")"
    return 1
  fi

  # Check if this is first deploy (before creating namespace)
  local first_deploy=false
  if is_first_deploy "$ns"; then
    first_deploy=true
    echo "    First deployment"
  else
    echo "    Updating existing deployment"
  fi

  # Create namespace if needed
  if [[ "$first_deploy" == "true" ]]; then
    echo "    Creating namespace: $ns"
    kubectl create namespace "$ns" || true
  fi

  # Capture existing deployments/statefulsets before apply
  local existing_deploys existing_sts
  existing_deploys=$(get_deployments "$ns")
  existing_sts=$(get_statefulsets "$ns")

  # Apply manifests (namespace.yaml first if exists)
  if [[ -f "${manifests_dir}/namespace.yaml" ]]; then
    kubectl apply -f "${manifests_dir}/namespace.yaml"
  fi

  # Apply all other yaml files
  for f in "${manifests_dir}"/*.yaml; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == "namespace.yaml" ]] && continue
    echo "    Applying: $(basename "$f")"
    kubectl apply -f "$f"
  done

  # On update: restart deployments to pick up ConfigMap/Secret changes
  if [[ "$first_deploy" == "false" ]]; then
    for deploy in $existing_deploys; do
      echo "    Restarting deployment: $deploy"
      kubectl rollout restart deployment/"$deploy" -n "$ns"
    done
  fi

  # Wait for rollouts
  local all_deploys
  all_deploys=$(get_deployments "$ns")
  for deploy in $all_deploys; do
    echo "    Waiting for rollout: $deploy"
    kubectl rollout status deployment/"$deploy" -n "$ns" --timeout=120s || true
  done

  # Wait for statefulsets
  local all_sts
  all_sts=$(get_statefulsets "$ns")
  for sts in $all_sts; do
    echo "    Waiting for statefulset: $sts"
    kubectl rollout status statefulset/"$sts" -n "$ns" --timeout=120s || true
  done

  echo "    $(green "Done")"
}

# ============================================================
# Main
# ============================================================

if [[ "$PLAN_ONLY" == "true" ]]; then
  show_plan
  exit 0
fi

echo ""
echo "Cluster Deploy"
echo "=============="

if [[ "$TARGET" == "all" ]]; then
  echo "Deploying all enabled services..."

  for svc in $(list_services); do
    deploy_service "$svc"
  done

  echo ""
  echo "$(green "All services deployed")"
else
  # Single service deployment
  if [[ -z "$(get_service "$TARGET")" ]]; then
    echo "$(red "Error: Unknown or disabled service: $TARGET")"
    echo ""
    echo "Enabled services: $(list_services | tr '\n' ' ')"
    exit 1
  fi

  deploy_service "$TARGET"
fi

echo ""
