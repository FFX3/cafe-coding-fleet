#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo "Local Cluster Tests"
echo "==================="
echo ""

# Check nodes
kubectl get nodes &>/dev/null || fail "Cannot connect to cluster"
pass "Cluster reachable"

# Check ingress controller pod
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller | grep -q Running || fail "Ingress controller not running"
pass "Ingress controller running"

# Check test app pods
kubectl get pods -l app=test-app | grep -q Running || fail "Test app not running"
pass "Test app 1 running"

kubectl get pods -l app=test-app-2 | grep -q Running || fail "Test app 2 not running"
pass "Test app 2 running"

# Test HTTP via localhost (mapped via --exposed-ports and hostNetwork)
ENDPOINT="http://localhost"

# Test app 1 (test.justinmcintyre.com)
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: test.justinmcintyre.com" "$ENDPOINT") || fail "curl failed"
[[ "$RESPONSE" == "200" ]] || fail "test.justinmcintyre.com: expected 200, got $RESPONSE"
pass "test.justinmcintyre.com returns 200"

curl -s -H "Host: test.justinmcintyre.com" "$ENDPOINT" | grep -q "It works!" || fail "test.justinmcintyre.com: wrong content"
pass "test.justinmcintyre.com content verified"

# Test app 2 (test2.justinmcintyre.com)
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: test2.justinmcintyre.com" "$ENDPOINT") || fail "curl failed"
[[ "$RESPONSE" == "200" ]] || fail "test2.justinmcintyre.com: expected 200, got $RESPONSE"
pass "test2.justinmcintyre.com returns 200"

curl -s -H "Host: test2.justinmcintyre.com" "$ENDPOINT" | grep -q "App Two!" || fail "test2.justinmcintyre.com: wrong content"
pass "test2.justinmcintyre.com content verified"

echo ""
echo -e "${GREEN}All tests passed! Host-based routing works.${NC}"
