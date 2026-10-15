# Answer — Lab 03

> Mode: guided (multiple-choice decision at each step). Full command log with outputs: [rounds.md](rounds.md).

## 1. Impact
- New `v1.15.0` pod in `CrashLoopBackOff`; three `v1.14.2` pods healthy and serving.
- Hidden risk: the old pods read `ML_MODEL_API_KEY` from the same Secret at container start. If any of them restarts (OOM, drain, liveness, autoscaler) it reads today's empty value and crashes → **production is one restart away from a full outage.**
- Protective actions: no `rollout restart`, no node maintenance; timebox 15 minutes.
- `helm rollback` was **not** safe: revision 40 did not manage the Secret, so a rollback would delete it, and the original value was already overwritten.

## 2. Request path / data path
`Azure Key Vault (source of truth) → ? → Azure DevOps variable group → HelmDeploy → values → Secret template → fraud-api-secrets → secretKeyRef → container env at start`

## 3. Observation
| Command | What it proved |
|---|---|
| `kubectl logs <new-pod> --previous` | `ML_MODEL_API_KEY is empty → FATAL` |
| `kubectl get deploy ... -o jsonpath` on the env entry | Value comes from `secretKeyRef fraud-api-secrets / ml-model-api-key` |
| `kubectl describe secret fraud-api-secrets` | Key exists, **0 bytes**; labels show `managed-by=Helm` |
| `helm history`, `helm get manifest --revision 40/41 \| grep -c fraud-api-secrets` | Secret entered the chart in revision 41 (0 → 1) |
| `helm get values` (user-supplied only) | Only `image.tag` is passed by the pipeline |
| Secret `creationTimestamp` + `managedFields` | Created by hand in March (`kubectl-create`), adopted by `helm` today |

Mistakes I made and corrected: I first chose `jsonpath | base64 -d`, then `-o yaml`. Both expose the value — base64 is encoding, not encryption. The safe pattern is `kubectl describe secret` (keys and sizes) or `jq '.data | keys'` / `jq '.data["key"] | length'`.

## 4. Root cause
- Commit `9c41e2a` made the chart own `fraud-api-secrets` and dropped the manual runbook step that used to create it.
- `values.yaml` has `secrets.mlModelApiKey: ""`, and the pipeline never passes a value, so Helm adopted the hand-made Secret and overwrote the valid key with an empty string.
- Azure DevOps secret variables are available to the pipeline but are not exported to tasks automatically; nothing maps `$(ML_MODEL_API_KEY)` into HelmDeploy, and Helm does not read environment variables.

## 5. Mitigation
```bash
az keyvault secret show --vault-name kv-fraud-prod -n ml-model-api-key --query value -o tsv \
  | kubectl create secret generic fraud-api-secrets -n fraud-prod \
      --from-file=ml-model-api-key=/dev/stdin --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl describe secret fraud-api-secrets -n fraud-prod     # ml-model-api-key: 40 bytes
```
- The crashlooping pod picked up the value on its next restart; the rollout completed without touching the old ReplicaSet.
- Pipeline disabled until the chart is fixed — the next `helm upgrade` would blank the Secret again.
- My first choice was to add `--set secrets.mlModelApiKey=$(ML_MODEL_API_KEY)` and re-run the pipeline. It works, but stores the key in the Helm release Secret and `helm get values`, exposes it as a process argument, and takes minutes while the old pods are at risk.

Temporary changes, all reverted at closure: Secret applied by hand → replaced by ExternalSecret; pipeline disabled → re-enabled after the chart fix; node maintenance hold → released.

## 6. Verification
- `kubectl describe secret` → 40 bytes (value never displayed).
- `kubectl rollout status deploy/fraud-api` → complete, all pods `v1.15.0`, old ReplicaSet at 0, no restarts.

## 7. Prevention
1. **The chart carries no secret values.** External Secrets Operator (or the Secrets Store CSI driver) syncs `fraud-api-secrets` from Azure Key Vault with workload identity; the chart only references `existingSecret`.
2. **Fail loudly:** `{{ required "mlModelApiKey is required" .Values.secrets.mlModelApiKey }}` for any value that must exist, and `helm.sh/resource-policy: keep` on Secrets Helm must never delete.
3. **Pipeline gate:** `helm diff upgrade` in PRs shows Secret changes; deployment validation with automatic rollback — designed knowing that a rollback deletes resources absent from the target revision.
4. Rejected: permanent `--set` for secrets.
