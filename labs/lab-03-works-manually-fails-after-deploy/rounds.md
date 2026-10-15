# Lab 03 — Investigation log

Guided mode: multiple-choice decision at each step, following [docs/incident-method.md](../../docs/incident-method.md).
Recycled weak areas: secret hygiene (keys, never values), Azure DevOps secret variable mapping, tracking temporary mitigation changes, timeboxing.

## Step 1 — Impact
Choice: old pods are also at risk ✅
- `secretKeyRef` env is resolved at container start. Old pods read the value yesterday; any restart (OOM, drain, liveness, autoscaler) re-reads today's Secret and crashes → production is one restart away from a full outage.
- Protect: no `rollout restart`, no node maintenance/drain; ask platform to hold node upgrades. Timebox 15 min (14:02 → 14:17).
- Rejected: "not urgent" (misses the hidden risk); `helm rollback` (rev 40 did not manage the Secret, so rollback **deletes** it; the old value was overwritten and Helm never knew it); deleting the crashing pod (same empty value).
```
kubectl logs fraud-api-65f9f67bdb-bx7vn -n fraud-prod --previous → ML_MODEL_API_KEY is empty → FATAL
deploy env: ML_MODEL_API_KEY ← secretKeyRef fraud-api-secrets / ml-model-api-key
```

## Step 2 — Does the key exist, is it empty? (without revealing it)
Choice: `kubectl get secret ... -o jsonpath='{.data.ml-model-api-key}' | base64 -d` ❌ (recycled weak area: secret hygiene)
Output was empty, so nothing leaked — by luck. Decoding prints the value; base64 in `-o yaml` is also exposure; `printenv` in an old pod would have printed the real, valid key. Rule: keys and lengths only. Retried.

Retry: `kubectl get secret ... -o yaml` ❌ — base64 is encoding, not encryption; the value is exposed.
Correct (shown by instructor): `kubectl describe secret fraud-api-secrets -n fraud-prod`
```
Labels:       app.kubernetes.io/managed-by=Helm
Annotations:  meta.helm.sh/release-name: fraud-api
Data
====
ml-model-api-key:  0 bytes
```
Finding: key exists, value is empty (0 bytes), Secret is now managed by Helm.
Safe patterns: `describe secret` (keys + sizes), `jq '.data | keys'`, `jq '.data["k"] | length'`. Never: `-o yaml`, unfiltered `-o json`, `base64 -d`, `printenv` in a pod.

## Step 3 — Where did Helm get the value, what changed?
Choice: `helm history` + compare manifests of rev 40/41 + `helm get values` (user-supplied only) ✅
```
rev 40  fraud-api-1.14.2  superseded
rev 41  fraud-api-1.15.0  deployed
fraud-api-secrets in manifest: rev 40 → 0, rev 41 → 1
USER-SUPPLIED VALUES: image.tag only
Secret creationTimestamp 2026-03-02, managers: kubectl-create, helm
```
Finding: Secret created by hand in March; rev 41 started managing it; Helm adopted it and wrote `""` from values.yaml over the valid key. ⏱ 14:09.
Note: `helm get values --all` would print secret values passed via `--set` in plain text — same trap as step 2.

## Step 4 — Why didn't the Azure DevOps secret reach Helm?
Choice: nobody passes it ✅ (recycled weak area: ADO secret mapping — 1 good answer)
Linking a variable group makes variables available, but secret variables are never exported to scripts automatically; they must be mapped (`env:` in script tasks, `$(VAR)` in task inputs). HelmDeploy arguments never reference `$(ML_MODEL_API_KEY)`, and Helm does not read environment variables. Masking only affects logs. ⏱ 14:12.

## Step 5 — Repair production now
Choice: add `--set secrets.mlModelApiKey=$(ML_MODEL_API_KEY)` to HelmDeploy and re-run ⚠️
Works, but: the key lands in the Helm release Secret (`sh.helm.release.v1.fraud-api.v42`, base64+gzip) and `helm get values`; it becomes a process argument on the agent; a full pipeline run takes minutes while old pods stay one restart from an outage.
Better (shown by instructor):
```
az keyvault secret show --vault-name kv-fraud-prod -n ml-model-api-key --query value -o tsv \
  | kubectl create secret generic fraud-api-secrets -n fraud-prod --from-file=ml-model-api-key=/dev/stdin --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl describe secret ... → ml-model-api-key: 40 bytes
crashlooping pod → Running on its next restart; rollout completed; old RS untouched   ⏱ 14:16 mitigated
```
Then disable the pipeline: the Secret is Helm-owned, so the next upgrade would blank it again.
Temporary changes to revert at closure: (1) Secret applied by hand, (2) fraud-api pipeline disabled, (3) node maintenance held.

## Step 6 — Prevention
Chosen (3/3, trap avoided): no secret values in the chart (ESO/CSI from Key Vault, `existingSecret`); `required` + `helm.sh/resource-policy: keep`; `helm diff` in PRs + rollback designed with its delete behaviour in mind.
Rejected: permanent `--set` for secrets.

## Closure — revert temporary changes
1. Hand-applied Secret → replaced by ExternalSecret after the chart change merged.
2. Pipeline re-enabled, deployed with the new chart; `describe secret` → 40 bytes; rollout complete.
3. Node maintenance hold released.
