#!/usr/bin/env bash
# Creates the lab-07 kind cluster and deploys today's llm-gateway release (support-llm v2).
# Re-running it resets the scenario.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

for t in docker kind kubectl; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker Engine and retry."; exit 1; }

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== Creating kind cluster $CLUSTER (first run downloads the node image, ~2 min)"
  kind create cluster --name "$CLUSTER" --kubeconfig "$KUBECONFIG" --wait 180s
else
  kind export kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG" >/dev/null
fi

echo "== Resetting namespace $NS"
kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null
kubectl create namespace "$NS" >/dev/null

echo "== Release pipeline: kubectl apply -f env/manifests (support-llm v2)"
kubectl apply -n "$NS" -f "$MANIFESTS" >/dev/null
kubectl rollout status "deploy/$APP" -n "$NS" --timeout=180s >/dev/null

echo
echo "Pipeline result: apply ✅  rollout status ✅  pods 3/3 Ready ✅"
echo "Alert (5 min later): llm-gateway 5xx ratio 16% during the deploy window, then back to 0."
echo
echo "Point kubectl at this lab in your shell with:"
echo "  source env/use.sh"
echo "Replay a release under live traffic with:"
echo "  bash env/traffic.sh"
