#!/usr/bin/env bash
# Exits 0 only when a release under live traffic causes zero failed requests,
# capacity stays at 3 replicas, and the live Deployment matches env/manifests.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env/common.sh"

failures=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

# 1. The live objects were applied from the repo, not patched by hand
if kubectl diff -n "$NS" -f "$MANIFESTS" >/dev/null 2>&1; then
  pass "Live objects match env/manifests"
else
  fail "Live objects differ from env/manifests (change the files, then kubectl apply -f env/manifests)"
fi

# 2. Capacity: 3 replicas, rollout complete
if kubectl rollout status "deploy/$APP" -n "$NS" --timeout=180s >/dev/null 2>&1; then
  ready=$(kubectl get deploy "$APP" -n "$NS" -o jsonpath='{.status.readyReplicas}')
  [[ "$ready" == "3" ]] && pass "Deployment 3/3 Ready" || fail "Deployment has ${ready:-0}/3 Ready (keep 3 replicas)"
else
  fail "Rollout did not complete within 180s"
fi

# 3. A pod reported Ready can actually serve completions
pod=$(kubectl get pods -n "$NS" -l app="$APP" --field-selector=status.phase=Running \
  -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | head -1)
code=$(kubectl exec -n "$NS" "$pod" -- python -c "import urllib.request as u; print(u.urlopen('http://localhost:8000/v1/models').status)" 2>/dev/null)
[[ "$code" == "200" ]] && pass "Ready pod serves /v1/models" || fail "Ready pod $pod does not serve /v1/models yet"

# 4. A release under live traffic causes zero failed requests
echo "....  Replaying a release under traffic (about 2 minutes)"
result=$(bash "$(dirname "${BASH_SOURCE[0]}")/env/traffic.sh" 2>/dev/null | tail -1)
okc=$(sed -n 's/.*ok=\([0-9]*\).*/\1/p' <<<"$result")
bad=$(sed -n 's/.*failed=\([0-9]*\).*/\1/p' <<<"$result")
if [[ -n "$okc" && "$okc" -gt 100 && "$bad" == "0" ]]; then
  pass "Release under traffic: $okc ok, 0 failed"
else
  fail "Release under traffic: ${result:-no result}"
fi

# 5. No container restarts during the release (liveness must not fight the model load)
restarts=$(kubectl get pods -n "$NS" -l app="$APP" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '{s+=$1} END {print s+0}')
[[ "$restarts" == "0" ]] && pass "No container restarts" || fail "$restarts container restart(s) during the release"

echo
if [[ $failures -eq 0 ]]; then echo "ALL CHECKS PASSED"; exit 0; else echo "$failures check(s) failed"; exit 1; fi
