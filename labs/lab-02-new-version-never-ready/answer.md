# Answer — Lab 02

> Mode: guided (multiple-choice decision at each step). Full command log with outputs: [rounds.md](rounds.md).

## 1. Impact
- `recommendation-api` v2.8.0 rollout stalled (`ProgressDeadlineExceeded`): 2 new pods `0/1 Ready`, only 2 of 4 old v2.7 pods left serving.
- Measured before acting: old pods at ~1300m of a 1500m CPU limit, no HPA, p95 240 ms against a 300 ms SLO, 5xx 0.2%. Capacity was tight but holding.
- Decision: `kubectl rollout pause`, **10-minute timebox** (10:02 → 10:12); rollback immediately if p95 breaks the SLO or the timebox ends.

## 2. Request path
`pod v2.8.0 → DNS feature-store.ml-platform.svc.cluster.local → Service ClusterIP:9000 → Endpoints → feature-store pod:9000`, with NetworkPolicy/CNI able to drop packets on the way.

## 3. Observation
| Command | What it proved |
|---|---|
| `kubectl debug -it <new-pod> --image=nicolaka/netshoot --target=recommendation-api` | Tools in the pod's own network namespace without rebuilding the minimal image |
| `nslookup feature-store.ml-platform.svc.cluster.local` | DNS fine → 10.96.142.18 |
| `nc -zv -w3 feature-store.ml-platform.svc.cluster.local 9000` | **Timed out** (not refused) → packets dropped, not "nothing listening" |
| `kubectl get svc,endpointslices -n ml-platform -l app=feature-store` + pods | Service, 3 endpoints, 3/3 Ready |
| `kubectl run nettest -n ml-platform ... curl -fsS --max-time 3 http://feature-store:9000/health` | Server healthy from its own namespace |
| `nc -zv -w3 10.244.3.27 9000` from the production pod | Pod IP also times out → not Service/kube-proxy |
| `kubectl get networkpolicy -A`, `describe` both sides, `kubectl get ns --show-labels` | Ingress allowed only from namespaces labelled `feature-store-access=true`; production has no such label |

## 4. Root cause
- Nine days earlier `ml-platform` added `default-deny-ingress` plus `allow-feature-store-clients`, which admits only namespaces labelled `feature-store-access=true`.
- `recsys-staging` had been labelled by hand, so v2.8.0 passed staging; `production` was never labelled.
- v2.8.0 is the first version that calls the feature store, so v2.7 never hit the policy.
- Aggravating factor: `maxSurge: 0, maxUnavailable: 50%` removed half of production capacity before the new version proved it could become Ready.

## 5. Mitigation and fix
```bash
helm rollback recommendation-api -n production --wait --timeout 5m
kubectl rollout resume deploy/recommendation-api -n production   # it was still paused — rollback alone did nothing
kubectl rollout status deploy/recommendation-api -n production --timeout=5m
```
The policy belongs to ml-platform, so the fix went through their IaC repo as a least-privilege rule:
```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels: { kubernetes.io/metadata.name: production }
        podSelector:
          matchLabels: { app: recommendation-api }   # same item → AND, not OR
    ports:
      - { protocol: TCP, port: 9000 }
```
Rejected: labelling the whole `production` namespace, deleting `default-deny-ingress`, or applying our own policy with `kubectl` (all bypass the owner; the last would be reverted by GitOps).

## 6. Verification
- After rollback: old RS 4/4, new RS 0, p95 142 ms, 5xx 0.1% (mitigated 10:13).
- After the PR merged: `nc` from a production pod succeeded; pipeline re-run → 4/4 Ready on v2.8.0, old RS 0, p95 138 ms.

## 7. Prevention
1. **Rollout strategy:** `maxSurge: 1, maxUnavailable: 0` so an unready version never costs serving capacity.
2. **Staging/prod parity in IaC:** namespace labels and NetworkPolicies come from code, never by hand; the chart documents its egress dependencies.
3. **Pipeline gate:** pre-deploy connectivity check to declared dependencies, then `helm upgrade --atomic` (or `rollout status` + automatic rollback).
4. Kept on purpose: the readiness probe. It worked — it kept traffic away from broken pods. Whether the app should become Ready in a degraded mode without the feature store is a product decision, not a reason to remove the probe.
