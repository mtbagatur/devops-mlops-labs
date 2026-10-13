#!/usr/bin/env bash
# Exits 0 only when production runs PAYMENT_TIMEOUT=15 and the chart rolls pods on config changes.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env/common.sh"

failures=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

deployment_doc() { awk 'BEGIN { RS = "\n---" } /\nkind: Deployment/ { print }'; }

# 1. Live ConfigMap
cm=$(kubectl get cm "$RELEASE-config" -n "$NS" -o jsonpath='{.data.PAYMENT_TIMEOUT}' 2>/dev/null)
[[ "$cm" == "15" ]] && pass "ConfigMap PAYMENT_TIMEOUT=15" || fail "ConfigMap PAYMENT_TIMEOUT is '$cm', expected 15"

# 2. Rollout complete, 4/4 ready
if kubectl rollout status "deploy/$RELEASE" -n "$NS" --timeout=90s >/dev/null 2>&1; then
  ready=$(kubectl get deploy "$RELEASE" -n "$NS" -o jsonpath='{.status.readyReplicas}')
  [[ "$ready" == "4" ]] && pass "Deployment 4/4 Ready" || fail "Deployment has ${ready:-0}/4 Ready"
else
  fail "Rollout did not complete within 90s"
fi

# 3. Every running pod sees the new value
pods=$(kubectl get pods -n "$NS" -l app="$RELEASE" --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')
stale=0
for p in $pods; do
  v=$(kubectl exec -n "$NS" "$p" -- printenv PAYMENT_TIMEOUT 2>/dev/null)
  [[ "$v" == "15" ]] || stale=$((stale + 1))
done
[[ -n "$pods" && $stale -eq 0 ]] && pass "All pods have PAYMENT_TIMEOUT=15" || fail "$stale pod(s) still run an old PAYMENT_TIMEOUT"

# 4. A new ReplicaSet took over and the old one is scaled to 0
rs_total=$(kubectl get rs -n "$NS" -l app="$RELEASE" -o name | wc -l)
rs_active=$(kubectl get rs -n "$NS" -l app="$RELEASE" -o jsonpath='{range .items[*]}{.spec.replicas}{"\n"}{end}' | grep -vc '^0$')
[[ $rs_total -ge 2 && $rs_active -eq 1 ]] && pass "New ReplicaSet active, old ReplicaSet scaled to 0" \
  || fail "ReplicaSets: $rs_total total, $rs_active with replicas > 0"

# 5. Service answers with the new value
first=$(echo "$pods" | awk '{print $1}')
body=$(kubectl exec -n "$NS" "$first" -- wget -qO- "http://$RELEASE:8080/" 2>/dev/null)
[[ "$body" == *"PAYMENT_TIMEOUT=15"* ]] && pass "Service responds with PAYMENT_TIMEOUT=15" || fail "Service response: '${body:-none}'"

# 6. IaC: a config-only change must change the PodTemplate
a=$(helm template "$RELEASE" "$CHART" -n "$NS" -f "$CHART/values-prod.yaml" --set config.paymentTimeout=15 | deployment_doc)
b=$(helm template "$RELEASE" "$CHART" -n "$NS" -f "$CHART/values-prod.yaml" --set config.paymentTimeout=16 | deployment_doc)
[[ -n "$a" && "$a" != "$b" ]] && pass "Chart: config change alters the Deployment PodTemplate" \
  || fail "Chart: changing only config leaves the Deployment unchanged (no automatic rollout)"

# 7. The live release was deployed from the fixed chart, not patched by hand
live=$(helm get manifest "$RELEASE" -n "$NS" 2>/dev/null | deployment_doc)
[[ -n "$live" && "$live" == "$a" ]] && pass "Live Helm release matches the chart in the repo" \
  || fail "Live Helm release differs from the chart in the repo (redeploy with helm and values-prod.yaml)"

echo
if [[ $failures -eq 0 ]]; then echo "ALL CHECKS PASSED"; exit 0; else echo "$failures check(s) failed"; exit 1; fi
