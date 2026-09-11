#!/usr/bin/env bash
set -euo pipefail

# Show service dependency graph
# Usage: nix run .#cluster-deps [service]
#
# Without arguments: shows all services with their dependencies
# With service name: shows detailed dependency tree for that service

source "$(dirname "$0")/lib/services.sh"

require_cluster

TARGET="${1:-}"

# ============================================================
# Tree Drawing Functions
# ============================================================

# Print upstream dependencies (what this service depends on)
print_upstream() {
  local svc="$1"
  local prefix="${2:-}"
  local is_last="${3:-true}"

  local deps
  deps=$(get_deps "$svc")

  local dep_array=()
  while IFS= read -r dep; do
    [[ -n "$dep" ]] && dep_array+=("$dep")
  done <<< "$deps"

  local count=${#dep_array[@]}
  local i=0

  for dep in "${dep_array[@]}"; do
    i=$((i + 1))
    local connector="├─"
    local next_prefix="${prefix}│  "
    if [[ $i -eq $count ]]; then
      connector="└─"
      next_prefix="${prefix}   "
    fi

    # Check health status
    local ns
    ns=$(get_prop "$dep" "namespace")
    local status_indicator=""
    if namespace_exists "$ns"; then
      # Try to find deployment
      local deploy_name
      deploy_name=$(kubectl get deployments -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [[ -n "$deploy_name" ]] && service_healthy "$ns" "$deploy_name"; then
        status_indicator=" $(green "●")"
      else
        status_indicator=" $(red "●")"
      fi
    else
      status_indicator=" $(yellow "○")"
    fi

    echo "${prefix}${connector} ${dep}${status_indicator}"
    print_upstream "$dep" "$next_prefix" "$([ $i -eq $count ] && echo true || echo false)"
  done
}

# Print downstream dependents (what depends on this service)
print_downstream() {
  local svc="$1"
  local prefix="${2:-}"
  local is_last="${3:-true}"

  local dependents
  dependents=$(get_dependents "$svc")

  local dep_array=()
  while IFS= read -r dep; do
    [[ -n "$dep" ]] && dep_array+=("$dep")
  done <<< "$dependents"

  local count=${#dep_array[@]}
  local i=0

  for dep in "${dep_array[@]}"; do
    i=$((i + 1))
    local connector="├─"
    local next_prefix="${prefix}│  "
    if [[ $i -eq $count ]]; then
      connector="└─"
      next_prefix="${prefix}   "
    fi

    # Check if enabled
    local enabled
    enabled=$(jq -r ".services[\"$dep\"] // empty" "$SERVICES_JSON")
    local status=""
    if [[ -z "$enabled" ]]; then
      status=" $(yellow "(disabled)")"
    fi

    echo "${prefix}${connector} ${dep}${status}"
    print_downstream "$dep" "$next_prefix" "$([ $i -eq $count ] && echo true || echo false)"
  done
}

# ============================================================
# Main
# ============================================================

echo ""

if [[ -z "$TARGET" ]]; then
  # Show all services with their direct dependencies
  echo "Service Dependencies"
  echo "===================="
  echo ""
  echo "Legend: $(green "●") healthy  $(red "●") unhealthy  $(yellow "○") not deployed"
  echo ""

  for svc in $(list_all_services); do
    deps=$(get_deps "$svc")
    dep_list=""
    if [[ -n "$deps" ]]; then
      dep_list=$(echo "$deps" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    fi

    # Check if enabled
    enabled=$(jq -r ".services[\"$svc\"] // empty" "$SERVICES_JSON")
    if [[ -z "$enabled" ]]; then
      printf "  $(yellow "%-20s") → %s\n" "$svc" "${dep_list:-(none)}"
    else
      printf "  %-20s → %s\n" "$svc" "${dep_list:-(none)}"
    fi
  done

  echo ""
  echo "Use '$(blue "nix run .#cluster-deps <service>")' for detailed tree view"
else
  # Show detailed tree for specific service
  if [[ -z "$(get_service_all "$TARGET")" ]]; then
    echo "$(red "Error: Unknown service: $TARGET")"
    echo ""
    echo "Available services: $(list_all_services | tr '\n' ' ')"
    exit 1
  fi

  echo "Dependency Graph: $(blue "$TARGET")"
  echo "=========================="
  echo ""
  echo "Legend: $(green "●") healthy  $(red "●") unhealthy  $(yellow "○") not deployed"
  echo ""

  # Upstream dependencies
  echo "$TARGET depends on:"
  deps=$(get_deps "$TARGET")
  if [[ -z "$deps" ]]; then
    echo "  (none)"
  else
    print_upstream "$TARGET" "  "
  fi

  echo ""

  # Downstream dependents
  echo "Services that depend on $TARGET:"
  dependents=$(get_dependents "$TARGET")
  if [[ -z "$dependents" ]]; then
    echo "  (none)"
  else
    print_downstream "$TARGET" "  "
  fi
fi

echo ""
