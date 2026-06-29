#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(dirname "$SCRIPT_DIR")}"
TERRAFORM_DIR="$ROOT_DIR/terraform/compute"

# Benchmarking: track when monitoring started
START_TIME=$(date +%s)
START_TIME_DISPLAY=$(date +%H:%M:%S)

# Associative array to track when each check first passed
declare -A FIRST_PASS_TIME

# Helper to record first pass time
record_pass() {
    local key="$1"
    if [[ -z "${FIRST_PASS_TIME[$key]:-}" ]]; then
        FIRST_PASS_TIME[$key]=$(($(date +%s) - START_TIME))
    fi
}

# Helper to format elapsed time for display
format_elapsed() {
    local key="$1"
    local elapsed="${FIRST_PASS_TIME[$key]:-}"
    if [[ -n "$elapsed" ]]; then
        printf "+%ds" "$elapsed"
    else
        echo ""
    fi
}

# Helper to get max elapsed time for a stage
get_stage_time() {
    local max=0
    for key in "$@"; do
        local elapsed="${FIRST_PASS_TIME[$key]:-0}"
        if [[ "$elapsed" -gt "$max" ]]; then
            max="$elapsed"
        fi
    done
    echo "$max"
}

# Get IP from terraform
cd "$TERRAFORM_DIR"
IP=$(terraform output -raw controlplane_external_ip 2>/dev/null || echo "")

if [[ -z "$IP" ]]; then
    echo "Error: Could not get IP from terraform output"
    echo "Make sure you've run: cd terraform && terraform apply"
    exit 1
fi

# Check if certs were restored (if not passed from bootstrap, check if encrypted certs exist)
CERTS_RESTORED="${CERTS_RESTORED:-false}"
if [[ "$CERTS_RESTORED" == "false" ]] && ls "$ROOT_DIR/certs"/*.enc.yaml >/dev/null 2>&1; then
    # If encrypted certs exist, assume they were restored
    CERTS_RESTORED=true
fi

monitor_status() {
    local PASS="✓"
    local PENDING="⋯"

    # Track previous state to detect changes
    local prev_state=""

    # Function to render current status
    render_status() {
        echo "Monitoring cluster status (Ctrl+C to exit)"
        echo "Cluster IP: $IP"
        echo "Started: $START_TIME_DISPLAY"
        echo ""

        # Stage 1: Cluster Health
        local stage_time
        if $cluster_health_pass; then
            stage_time=$(get_stage_time certmanager ingress testapp testapp2 twentyserver twentyworker twentyredis conduit)
            printf "[%s] Cluster Health%*s+%ds\n" "$PASS" $((35 - 14)) "" "$stage_time"
        else
            echo "[$PENDING] Cluster Health"
        fi
        if $certmanager_ok; then printf "    %s cert-manager running%*s%s\n" "$PASS" $((35 - 20)) "" "$(format_elapsed certmanager)"; else echo "    $PENDING cert-manager running"; fi
        if $ingress_ok; then printf "    %s ingress-nginx running%*s%s\n" "$PASS" $((35 - 21)) "" "$(format_elapsed ingress)"; else echo "    $PENDING ingress-nginx running"; fi
        if $testapp_ok; then printf "    %s test-app running%*s%s\n" "$PASS" $((35 - 16)) "" "$(format_elapsed testapp)"; else echo "    $PENDING test-app running"; fi
        if $testapp2_ok; then printf "    %s test-app-2 running%*s%s\n" "$PASS" $((35 - 18)) "" "$(format_elapsed testapp2)"; else echo "    $PENDING test-app-2 running"; fi
        if $twentyserver_ok; then printf "    %s twenty-server running%*s%s\n" "$PASS" $((35 - 21)) "" "$(format_elapsed twentyserver)"; else echo "    $PENDING twenty-server running"; fi
        if $twentyworker_ok; then printf "    %s twenty-worker running%*s%s\n" "$PASS" $((35 - 21)) "" "$(format_elapsed twentyworker)"; else echo "    $PENDING twenty-worker running"; fi
        if $twentyredis_ok; then printf "    %s twenty-redis running%*s%s\n" "$PASS" $((35 - 20)) "" "$(format_elapsed twentyredis)"; else echo "    $PENDING twenty-redis running"; fi
        if $conduit_ok; then printf "    %s conduit running%*s%s\n" "$PASS" $((35 - 15)) "" "$(format_elapsed conduit)"; else echo "    $PENDING conduit running"; fi
        echo ""

        # Stage 2: Connectivity
        if $cluster_health_pass; then
            if $connectivity_pass; then
                stage_time=$(get_stage_time ip_reachable dns1 dns2 dns_crm dns_matrix)
                printf "[%s] Connectivity%*s+%ds\n" "$PASS" $((35 - 12)) "" "$stage_time"
            else
                echo "[$PENDING] Connectivity"
            fi
            if $ip_reachable; then printf "    %s Cluster IP reachable%*s%s\n" "$PASS" $((35 - 20)) "" "$(format_elapsed ip_reachable)"; else echo "    $PENDING Cluster IP reachable"; fi
            if $dns1_ok; then printf "    %s DNS: test.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 28)) "" "$(format_elapsed dns1)"; else echo "    $PENDING DNS: test.justinmcintyre.com"; fi
            if $dns2_ok; then printf "    %s DNS: test2.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 29)) "" "$(format_elapsed dns2)"; else echo "    $PENDING DNS: test2.justinmcintyre.com"; fi
            if $dns_crm_ok; then printf "    %s DNS: crm.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 27)) "" "$(format_elapsed dns_crm)"; else echo "    $PENDING DNS: crm.justinmcintyre.com"; fi
            if $dns_matrix_ok; then printf "    %s DNS: matrix.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 30)) "" "$(format_elapsed dns_matrix)"; else echo "    $PENDING DNS: matrix.justinmcintyre.com"; fi
        else
            echo "[ ] Connectivity"
            echo "    (waiting for cluster health)"
        fi
        echo ""

        # Stage 3: Certificates
        if $cluster_health_pass && $connectivity_pass; then
            if $certs_pass; then
                stage_time=$(get_stage_time cert1 cert2 cert_crm cert_matrix)
                printf "[%s] Certificates%*s+%ds\n" "$PASS" $((35 - 12)) "" "$stage_time"
            else
                echo "[$PENDING] Certificates"
            fi
            if $cert1_ok; then printf "    %s test-app-tls: Ready%*s%s\n" "$PASS" $((35 - 19)) "" "$(format_elapsed cert1)"; else echo "    $PENDING test-app-tls: Pending"; fi
            if $cert2_ok; then printf "    %s test-app-2-tls: Ready%*s%s\n" "$PASS" $((35 - 21)) "" "$(format_elapsed cert2)"; else echo "    $PENDING test-app-2-tls: Pending"; fi
            if $cert_crm_ok; then printf "    %s twenty-tls: Ready%*s%s\n" "$PASS" $((35 - 17)) "" "$(format_elapsed cert_crm)"; else echo "    $PENDING twenty-tls: Pending"; fi
            if $cert_matrix_ok; then printf "    %s conduit-tls: Ready%*s%s\n" "$PASS" $((35 - 18)) "" "$(format_elapsed cert_matrix)"; else echo "    $PENDING conduit-tls: Pending"; fi
        else
            echo "[ ] Certificates"
            echo "    (waiting for connectivity)"
        fi
        echo ""

        # Stage 4: HTTPS Responses
        if $certs_pass && $cluster_health_pass && $connectivity_pass; then
            if $https_pass; then
                stage_time=$(get_stage_time https1 https2 https_crm https_matrix)
                printf "[%s] HTTPS Responses%*s+%ds\n" "$PASS" $((35 - 15)) "" "$stage_time"
            else
                echo "[$PENDING] HTTPS Responses"
            fi
            if $https1_ok; then
                printf "    %s test.justinmcintyre.com (%s)%*s%s\n" "$PASS" "$https1_code" $((35 - 29 - ${#https1_code})) "" "$(format_elapsed https1)"
            else
                echo "    $PENDING test.justinmcintyre.com ($https1_code)"
            fi
            if $https2_ok; then
                printf "    %s test2.justinmcintyre.com (%s)%*s%s\n" "$PASS" "$https2_code" $((35 - 30 - ${#https2_code})) "" "$(format_elapsed https2)"
            else
                echo "    $PENDING test2.justinmcintyre.com ($https2_code)"
            fi
            if $https_crm_ok; then
                printf "    %s crm.justinmcintyre.com (%s)%*s%s\n" "$PASS" "$https_crm_code" $((35 - 28 - ${#https_crm_code})) "" "$(format_elapsed https_crm)"
            else
                echo "    $PENDING crm.justinmcintyre.com ($https_crm_code)"
            fi
            if $https_matrix_ok; then
                printf "    %s matrix.justinmcintyre.com (%s)%*s%s\n" "$PASS" "$https_matrix_code" $((35 - 31 - ${#https_matrix_code})) "" "$(format_elapsed https_matrix)"
            else
                echo "    $PENDING matrix.justinmcintyre.com ($https_matrix_code)"
            fi
        else
            echo "[ ] HTTPS Responses"
            echo "    (waiting for certificates)"
        fi
        echo ""

        # Stage 5: Content Check
        if $https_pass && $certs_pass && $cluster_health_pass && $connectivity_pass; then
            if $content1_ok && $content2_ok && $content_crm_ok && $content_matrix_ok; then
                stage_time=$(get_stage_time content1 content2 content_crm content_matrix)
                printf "[%s] Content Check%*s+%ds\n" "$PASS" $((35 - 13)) "" "$stage_time"
            else
                echo "[$PENDING] Content Check"
            fi
            if $content1_ok; then printf "    %s test.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 23)) "" "$(format_elapsed content1)"; else echo "    $PENDING test.justinmcintyre.com"; fi
            if $content2_ok; then printf "    %s test2.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 24)) "" "$(format_elapsed content2)"; else echo "    $PENDING test2.justinmcintyre.com"; fi
            if $content_crm_ok; then printf "    %s crm.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 22)) "" "$(format_elapsed content_crm)"; else echo "    $PENDING crm.justinmcintyre.com"; fi
            if $content_matrix_ok; then printf "    %s matrix.justinmcintyre.com%*s%s\n" "$PASS" $((35 - 25)) "" "$(format_elapsed content_matrix)"; else echo "    $PENDING matrix.justinmcintyre.com"; fi

            # Note about cert export if they weren't restored from storage
            if $content1_ok && $content2_ok && $content_crm_ok && $content_matrix_ok && [[ "$CERTS_RESTORED" != "true" ]]; then
                echo ""
                echo "---"
                echo "New certificates issued. They will be exported automatically on cluster-down."
            fi
        else
            echo "[ ] Content Check"
            echo "    (waiting for HTTPS)"
        fi
    }

    while true; do
        # Collect all state
        local certmanager_ok=false
        local ingress_ok=false
        local testapp_ok=false
        local testapp2_ok=false
        local twentyserver_ok=false
        local twentyworker_ok=false
        local twentyredis_ok=false
        local conduit_ok=false
        local cluster_health_pass=true

        if kubectl get pods -n cert-manager -l app=cert-manager --no-headers 2>/dev/null | grep -q Running; then
            certmanager_ok=true
            record_pass "certmanager"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -q Running; then
            ingress_ok=true
            record_pass "ingress"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -l app=test-app --no-headers 2>/dev/null | grep -q Running; then
            testapp_ok=true
            record_pass "testapp"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -l app=test-app-2 --no-headers 2>/dev/null | grep -q Running; then
            testapp2_ok=true
            record_pass "testapp2"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -n twenty -l app=twenty-server --no-headers 2>/dev/null | grep -q Running; then
            twentyserver_ok=true
            record_pass "twentyserver"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -n twenty -l app=twenty-worker --no-headers 2>/dev/null | grep -q Running; then
            twentyworker_ok=true
            record_pass "twentyworker"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -n twenty -l app=redis --no-headers 2>/dev/null | grep -q Running; then
            twentyredis_ok=true
            record_pass "twentyredis"
        else
            cluster_health_pass=false
        fi

        if kubectl get pods -n conduit -l app=conduit --no-headers 2>/dev/null | grep -q Running; then
            conduit_ok=true
            record_pass "conduit"
        else
            cluster_health_pass=false
        fi

        # Connectivity checks
        local ip_reachable=false
        local dns1_ok=false
        local dns2_ok=false
        local dns_crm_ok=false
        local dns_matrix_ok=false
        local connectivity_pass=true

        if $cluster_health_pass; then
            local http_code
            http_code=$(curl -sk --connect-timeout 2 -o /dev/null -w "%{http_code}" "https://$IP" 2>/dev/null || echo "000")
            if [[ "$http_code" == "404" || "$http_code" == "308" || "$http_code" == "200" ]]; then
                ip_reachable=true
                record_pass "ip_reachable"
            else
                connectivity_pass=false
            fi

            if getent hosts test.justinmcintyre.com >/dev/null 2>&1; then
                dns1_ok=true
                record_pass "dns1"
            else
                connectivity_pass=false
            fi

            if getent hosts test2.justinmcintyre.com >/dev/null 2>&1; then
                dns2_ok=true
                record_pass "dns2"
            else
                connectivity_pass=false
            fi

            if getent hosts crm.justinmcintyre.com >/dev/null 2>&1; then
                dns_crm_ok=true
                record_pass "dns_crm"
            else
                connectivity_pass=false
            fi

            if getent hosts matrix.justinmcintyre.com >/dev/null 2>&1; then
                dns_matrix_ok=true
                record_pass "dns_matrix"
            else
                connectivity_pass=false
            fi
        else
            connectivity_pass=false
        fi

        # Certificate checks
        local cert1_ok=false
        local cert2_ok=false
        local cert_crm_ok=false
        local cert_matrix_ok=false
        local certs_pass=true

        if $cluster_health_pass && $connectivity_pass; then
            local cert1_status cert2_status cert_crm_status cert_matrix_status
            cert1_status=$(kubectl get certificate test-app-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
            cert2_status=$(kubectl get certificate test-app-2-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
            cert_crm_status=$(kubectl get certificate twenty-tls -n twenty -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
            cert_matrix_status=$(kubectl get certificate conduit-tls -n conduit -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

            if [[ "$cert1_status" == "True" ]]; then
                cert1_ok=true
                record_pass "cert1"
            fi
            if [[ "$cert2_status" == "True" ]]; then
                cert2_ok=true
                record_pass "cert2"
            fi
            if [[ "$cert_crm_status" == "True" ]]; then
                cert_crm_ok=true
                record_pass "cert_crm"
            fi
            if [[ "$cert_matrix_status" == "True" ]]; then
                cert_matrix_ok=true
                record_pass "cert_matrix"
            fi
            if ! $cert1_ok || ! $cert2_ok || ! $cert_crm_ok || ! $cert_matrix_ok; then
                certs_pass=false
            fi
        else
            certs_pass=false
        fi

        # HTTPS response checks
        local https1_ok=false
        local https2_ok=false
        local https_crm_ok=false
        local https_matrix_ok=false
        local https1_code="..."
        local https2_code="..."
        local https_crm_code="..."
        local https_matrix_code="..."
        local https_pass=true

        if $certs_pass && $cluster_health_pass && $connectivity_pass; then
            https1_code=$(curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://test.justinmcintyre.com" 2>/dev/null || echo "000")
            https2_code=$(curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://test2.justinmcintyre.com" 2>/dev/null || echo "000")
            https_crm_code=$(curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://crm.justinmcintyre.com/healthz" 2>/dev/null || echo "000")
            https_matrix_code=$(curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://matrix.justinmcintyre.com/_matrix/client/versions" 2>/dev/null || echo "000")

            # 000 means connection failed, anything else means TLS worked
            if [[ "$https1_code" != "000" ]]; then
                https1_ok=true
                record_pass "https1"
            else
                https_pass=false
            fi

            if [[ "$https2_code" != "000" ]]; then
                https2_ok=true
                record_pass "https2"
            else
                https_pass=false
            fi

            if [[ "$https_crm_code" != "000" ]]; then
                https_crm_ok=true
                record_pass "https_crm"
            else
                https_pass=false
            fi

            if [[ "$https_matrix_code" != "000" ]]; then
                https_matrix_ok=true
                record_pass "https_matrix"
            else
                https_pass=false
            fi
        else
            https_pass=false
        fi

        # Content checks
        local content1_ok=false
        local content2_ok=false
        local content_crm_ok=false
        local content_matrix_ok=false

        if $https_pass && $certs_pass && $cluster_health_pass && $connectivity_pass; then
            if curl -sk https://test.justinmcintyre.com 2>/dev/null | grep -q "It works!"; then
                content1_ok=true
                record_pass "content1"
            fi
            if curl -sk https://test2.justinmcintyre.com 2>/dev/null | grep -q "App Two!"; then
                content2_ok=true
                record_pass "content2"
            fi
            # Twenty CRM health check returns 200 when healthy
            if [[ "$https_crm_code" == "200" ]]; then
                content_crm_ok=true
                record_pass "content_crm"
            fi
            # Matrix/Conduit returns 200 on versions endpoint when healthy
            if [[ "$https_matrix_code" == "200" ]]; then
                content_matrix_ok=true
                record_pass "content_matrix"
            fi
        fi

        # Build state string
        local current_state="${certmanager_ok}${ingress_ok}${testapp_ok}${testapp2_ok}"
        current_state+="${twentyserver_ok}${twentyworker_ok}${twentyredis_ok}${conduit_ok}"
        current_state+="${ip_reachable}${dns1_ok}${dns2_ok}${dns_crm_ok}${dns_matrix_ok}"
        current_state+="${cert1_ok}${cert2_ok}${cert_crm_ok}${cert_matrix_ok}"
        current_state+="${https1_ok}${https2_ok}${https_crm_ok}${https_matrix_ok}${https1_code}${https2_code}${https_crm_code}${https_matrix_code}"
        current_state+="${content1_ok}${content2_ok}${content_crm_ok}${content_matrix_ok}"

        # Only redraw if state changed
        if [[ "$current_state" != "$prev_state" ]]; then
            clear
            render_status
            prev_state="$current_state"
        fi

        # Exit when all checks pass
        if $content1_ok && $content2_ok && $content_crm_ok && $content_matrix_ok; then
            local total_time=$(($(date +%s) - START_TIME))
            echo ""
            echo "Total: ${total_time}s"
            echo ""
            echo "---"

            # Find slowest and fastest
            local slowest_key="" slowest_time=0
            local fastest_key="" fastest_time=999999
            local check_names=(
                "certmanager:cert-manager"
                "ingress:ingress-nginx"
                "testapp:test-app"
                "testapp2:test-app-2"
                "twentyserver:twenty-server"
                "twentyworker:twenty-worker"
                "twentyredis:twenty-redis"
                "ip_reachable:Cluster IP"
                "dns1:DNS test.justinmcintyre.com"
                "dns2:DNS test2.justinmcintyre.com"
                "dns_crm:DNS crm.justinmcintyre.com"
                "cert1:test-app-tls"
                "cert2:test-app-2-tls"
                "cert_crm:twenty-tls"
                "https1:test.justinmcintyre.com HTTPS"
                "https2:test2.justinmcintyre.com HTTPS"
                "https_crm:crm.justinmcintyre.com HTTPS"
                "content1:test.justinmcintyre.com content"
                "content2:test2.justinmcintyre.com content"
                "content_crm:crm.justinmcintyre.com content"
            )

            for entry in "${check_names[@]}"; do
                local key="${entry%%:*}"
                local name="${entry#*:}"
                local elapsed="${FIRST_PASS_TIME[$key]:-}"
                if [[ -n "$elapsed" ]]; then
                    if [[ "$elapsed" -gt "$slowest_time" ]]; then
                        slowest_time="$elapsed"
                        slowest_key="$name"
                    fi
                    if [[ "$elapsed" -lt "$fastest_time" ]]; then
                        fastest_time="$elapsed"
                        fastest_key="$name"
                    fi
                fi
            done

            echo "Startup complete in ${total_time}s"
            if [[ -n "$slowest_key" ]]; then
                echo "  Slowest: $slowest_key (+${slowest_time}s)"
            fi
            if [[ -n "$fastest_key" ]]; then
                echo "  Fastest: $fastest_key (+${fastest_time}s)"
            fi
            exit 0
        fi

        sleep 2
    done
}

monitor_status
