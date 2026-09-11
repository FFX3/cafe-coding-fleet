#!/usr/bin/env bash
set -euo pipefail

# Show cluster service status
# Usage: nix run .#cluster-status

source "$(dirname "$0")/lib/services.sh"

require_cluster

echo ""
echo "Cluster Service Status"
echo "======================"
echo ""

# Header
printf "%-20s %-12s %-15s %s\n" "SERVICE" "STATUS" "IMAGE" "NAMESPACE"
printf "%-20s %-12s %-15s %s\n" "-------" "------" "-----" "---------"

for svc in $(list_services); do
  ns=$(get_prop "$svc" "namespace")

  # Check if namespace exists
  if ! namespace_exists "$ns"; then
    printf "%-20s %-12s %-15s %s\n" "$svc" "$(yellow "not deployed")" "-" "$ns"
    continue
  fi

  # Try to find deployment (service name or common patterns)
  deploy_name=""
  for try in "$svc" "${svc}-deployment" "${svc}-server" "deployment"; do
    if kubectl get deployment -n "$ns" "$try" &>/dev/null; then
      deploy_name="$try"
      break
    fi
  done

  # Also try to find any deployment in namespace
  if [[ -z "$deploy_name" ]]; then
    deploy_name=$(kubectl get deployments -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  fi

  if [[ -z "$deploy_name" ]]; then
    # Check for statefulsets (postgres, etc)
    if kubectl get statefulset -n "$ns" &>/dev/null 2>&1; then
      sts_name=$(kubectl get statefulsets -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [[ -n "$sts_name" ]]; then
        replicas=$(kubectl get statefulset -n "$ns" "$sts_name" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [[ "${replicas:-0}" -gt 0 ]]; then
          printf "%-20s %-12s %-15s %s\n" "$svc" "$(green "healthy")" "(statefulset)" "$ns"
        else
          printf "%-20s %-12s %-15s %s\n" "$svc" "$(red "unhealthy")" "(statefulset)" "$ns"
        fi
        continue
      fi
    fi
    printf "%-20s %-12s %-15s %s\n" "$svc" "$(yellow "no deployment")" "-" "$ns"
    continue
  fi

  # Check deployment health
  if service_healthy "$ns" "$deploy_name"; then
    status="$(green "healthy")"
  else
    status="$(red "unhealthy")"
  fi

  # Get image tag
  tag=$(current_image_tag "$ns" "$deploy_name")

  printf "%-20s %-12s %-15s %s\n" "$svc" "$status" "$tag" "$ns"
done

echo ""

# Show disabled services
disabled=$(jq -r '.all | to_entries | .[] | select(.value.enable == false) | .key' "$SERVICES_JSON" | tr '\n' ' ')
if [[ -n "$disabled" ]]; then
  echo "Disabled services: $(yellow "$disabled")"
  echo ""
fi
