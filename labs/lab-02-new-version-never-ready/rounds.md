# Lab 02 — Investigation log

Guided mode: multiple-choice decision at each step, following [docs/incident-method.md](../../docs/incident-method.md).
Recycled weak area from Lab 01: timeboxing the investigation vs mitigating first.

## Step 1 — Impact and mitigation decision
Choice: measure capacity, then decide (pause + 10-min timebox, rollback if SLO breaks) ✅
```
kubectl top pods (old)  → ~1300m of 1500m CPU limit each; new pods idle
kubectl get hpa         → none
Grafana                 → 410 req/s, p95 240 ms (SLO 300 ms), 5xx 0.2%
kubectl rollout pause deploy/recommendation-api -n production   ⏱ 10:02 → 10:12
```
Rejected: blind rollback (destroys evidence when capacity is still OK), deleting new pods (recreated identical), scaling to 8 (proportional scaling adds broken pods; Helm reverts it).

## Step 2 — Request path
`pod v2.8.0 → DNS feature-store.ml-platform.svc.cluster.local → Service ClusterIP:9000 → Endpoints → feature-store pod:9000` (NetworkPolicy/CNI can drop packets anywhere along the way)

## Step 3 — DNS or TCP?
Choice: ephemeral debug container sharing the pod's network namespace ✅
```
kubectl debug -it recommendation-api-6f9db77f85-8kp2m -n production --image=nicolaka/netshoot --target=recommendation-api -- sh
nslookup feature-store.ml-platform.svc.cluster.local   → 10.96.142.18
nc -zv -w3 feature-store.ml-platform.svc.cluster.local 9000 → timed out
```
Finding: DNS fine; TCP times out (not refused).
Rejected: relaxing the probe (hides it, sends traffic to a broken pod), rebuilding the image with tools (slow, larger attack surface), jumping to feature-store logs before narrowing the layer.

## Step 4 — Timeout vs refused; is the server healthy?
Choice: prove the server side first (svc, endpoints, pods, test from inside ml-platform) ✅
```
service/feature-store ClusterIP 10.96.142.18 9000/TCP; endpointslice → 3 endpoints
pods feature-store 3/3 Running Ready
kubectl run nettest -n ml-platform ... curl -fsS --max-time 3 http://feature-store:9000/health → {"status":"ok"}
(from production pod) nc -zv -w3 10.244.3.27 9000 → timed out
```
Finding: server healthy; path blocked only from production → ml-platform, even to the pod IP (not Service/kube-proxy). ⏱ 10:07, p95 255 ms.
Rule learned: refused = reached host, nothing listening; timed out = dropped/filtered; NXDOMAIN = name.

## Step 5 — NetworkPolicy on both sides
Choice: list policies cluster-wide, describe both directions, show namespace labels ✅
```
ml-platform  default-deny-ingress          <none>             9d
ml-platform  allow-feature-store-clients   app=feature-store  9d   (ingress 9000/TCP from NamespaceSelector feature-store-access=true)
production   allow-egress-all              <none>             212d
ns production:     env=prod                               ← no feature-store-access label
ns recsys-staging: env=staging,feature-store-access=true  ← labelled by hand, so staging worked
```
Root cause: ml-platform introduced default-deny ingress 9 days ago; production namespace lacks the label; v2.8.0 is the first version calling the feature store. Staging/prod label drift hid it. ⏱ 10:09, p95 262 ms.
Rejected: restarting CNI/kube-proxy (cluster-wide, no evidence), pod IP in URL (ephemeral, still blocked), checking only production egress (misses the ingress side).

## Step 6 — Mitigate, then fix through the owner
Choice: timebox expired → helm rollback; least-privilege PR to the policy owner; redeploy after merge ✅
```
helm rollback recommendation-api -n production --wait   → success, but rollout did not progress
kubectl rollout resume deploy/recommendation-api          ← deployment was still paused from step 1
kubectl rollout status ...                                → successfully rolled out; old RS 4/4, new RS 0
Grafana: p95 142 ms, 5xx 0.1%                             ⏱ 10:13 mitigated
```
PR to ml-platform (`allow-recommendation-api`): namespaceSelector production AND podSelector app=recommendation-api in the same `from` item, TCP 9000 only.
11:05 merged + synced → nc succeeded → 11:12 pipeline re-run: 4/4 Ready, old RS 0, p95 138 ms.
Rejected: labelling the namespace (opens all of production, manual drift), deleting default-deny (opens cluster-wide), applying our own policy (bypasses owner/IaC, GitOps would revert it).
Gotcha: a paused Deployment ignores template changes — always resume what you paused.

## Step 7 — Prevention
Chosen (3/3, trap avoided): rollout strategy maxSurge 1 / maxUnavailable 0; staging/prod parity for labels and policies in IaC; pipeline connectivity gate + atomic upgrade / auto rollback.
Rejected: removing the readiness probe — it did its job and kept traffic off broken pods.
