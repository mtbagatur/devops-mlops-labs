#!/usr/bin/env bash
# Creates the lab-04 kind cluster and reproduces yesterday's and today's releases.
# Re-running it resets the scenario.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

for t in docker kind kubectl helm; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker Desktop and retry."; exit 1; }

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== Creating kind cluster $CLUSTER (first run downloads the node image, ~2 min)"
  kind create cluster --name "$CLUSTER" --kubeconfig "$KUBECONFIG" --wait 180s
else
  kind export kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG" >/dev/null
fi

echo "== Resetting namespace $NS"
helm uninstall "$RELEASE" -n "$NS" --wait >/dev/null 2>&1 || true

echo "== Yesterday: order-api 4.6.2 released with chart defaults"
helm upgrade --install "$RELEASE" "$CHART" -n "$NS" --create-namespace --wait --timeout 3m >/dev/null

echo "== Today: pipeline applies values-prod.yaml (same image tag)"
helm upgrade "$RELEASE" "$CHART" -n "$NS" -f "$CHART/values-prod.yaml" --wait --timeout 3m >/dev/null

echo
echo "Pipeline result: Helm upgrade ✅  Deployment ready ✅  Smoke test ✅"
echo "Ticket: the payments team says the new timeout is not in effect."
echo
echo "Point kubectl/helm at this lab in your shell with:"
echo "  source env/use.sh"
