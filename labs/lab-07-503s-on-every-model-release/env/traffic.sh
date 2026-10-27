#!/usr/bin/env bash
# Replays a release under live traffic: a client pod calls /v1/completions through the Service
# about 4 times a second while the Deployment rolls. Prints how many calls failed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DURATION="${DURATION:-120}"
kubectl delete pod traffic-client -n "$NS" --ignore-not-found --wait=true >/dev/null
kubectl run traffic-client -n "$NS" --image=busybox:1.36 --restart=Never --quiet -- sh -c "
  ok=0; bad=0; end=\$(( \$(date +%s) + $DURATION ))
  while [ \$(date +%s) -lt \$end ]; do
    if wget -q -T 2 -O /dev/null http://$APP:8000/v1/completions; then ok=\$((ok+1)); else bad=\$((bad+1)); fi
    sleep 0.25
  done
  echo \"ok=\$ok failed=\$bad\"" >/dev/null
kubectl wait --for=condition=Ready pod/traffic-client -n "$NS" --timeout=90s >/dev/null

echo "== Traffic running; starting a release (rollout restart)"
sleep 5
kubectl rollout restart "deploy/$APP" -n "$NS" >/dev/null
kubectl rollout status "deploy/$APP" -n "$NS" --timeout=240s >/dev/null
echo "== Rollout finished; waiting for the client to finish its ${DURATION}s window"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/traffic-client -n "$NS" --timeout=$((DURATION + 60))s >/dev/null
result=$(kubectl logs traffic-client -n "$NS" | tail -1)
kubectl delete pod traffic-client -n "$NS" --wait=false >/dev/null
echo "$result"
