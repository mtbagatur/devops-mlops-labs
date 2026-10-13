# Mini Lab #03 — Kubernetes / Helm: "Works manually, fails after deployment"
> Status: OPEN · Created: imported from chat · Level: 2 – Intermediate · Recycles: —

**Timebox:** 30–45 min · **Focus:** Kubernetes · Helm · Azure DevOps · Secrets · CI/CD

## Scenario
Your team deploys `fraud-detection-api` to production through Azure DevOps using Helm. Yesterday's `v1.14.2` works; today's `v1.15.0` pods enter `CrashLoopBackOff`.

```
Build image            ✅
Push image             ✅
Helm upgrade           ✅
Deployment validation  ❌
```
Old pods are healthy; new pods crash.

## Evidence
```
$ kubectl logs fraud-api-65f9f67bdb-bx7vn -n fraud-prod --previous
INFO  Starting fraud-detection-api v1.15.0
INFO  Loading configuration
ERROR Configuration validation failed
ERROR ML_MODEL_API_KEY is empty
FATAL Application terminated
```

Deployment env:
```yaml
env:
  - name: REDIS_HOST
    valueFrom:
      configMapKeyRef:
        name: fraud-api-config
        key: redis-host
  - name: ML_MODEL_API_KEY
    valueFrom:
      secretKeyRef:
        name: fraud-api-secrets
        key: ml-model-api-key
```
The Secret exists and has one data item.

Helm values:
```yaml
secrets:
  mlModelApiKey: ""
```

Secret template:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: fraud-api-secrets
type: Opaque
stringData:
  ml-model-api-key: {{ .Values.secrets.mlModelApiKey | quote }}
```

Azure DevOps deployment:
```yaml
variables:
- group: fraud-api-production

steps:
- task: HelmDeploy@0
  inputs:
    command: upgrade
    chartType: FilePath
    chartPath: charts/fraud-api
    releaseName: fraud-api
    namespace: fraud-prod
    arguments: >
      --install
      --set image.tag=$(Build.BuildNumber)

- script: kubectl rollout status deployment/fraud-api -n fraud-prod --timeout=5m
  displayName: Deployment validation
```
The variable group contains `ML_MODEL_API_KEY` as a secret.

Recent chart history:
```
$ git log --oneline -3 -- charts/fraud-api
9c41e2a chart: manage fraud-api-secrets in Helm, drop manual runbook step
4b7d019 chart: bump appVersion to 1.15.0
e22f8c3 chart: add REDIS_HOST from ConfigMap
```

## Your task
Find the fault and propose the safe fix. Work **Pod → Deployment → Secret → Helm release → Azure DevOps**. Give roughly 8–15 commands and prove:
1. why the container crashes,
2. whether the Secret key exists,
3. whether its value is empty — **without revealing it**,
4. whether Helm believes the value exists,
5. why the Azure DevOps variable isn't automatically reaching Helm,
6. how to repair production without unnecessarily touching the healthy old ReplicaSet — and what happens to the "healthy" old pods if one of them restarts right now,
7. how to redesign the secret flow so a future deployment cannot silently overwrite a valid Secret with an empty value.

Also consider where Helm values may be persisted or exposed — do not assume putting a secret in `--set` is automatically a good long-term design.

## Constraints
- You must not print or decode the production secret.

## How to answer
This lab is simulated: send your commands one stage at a time and the simulated cluster returns its output. Put the final answer in `answer.md` and run `/check-lab 03`.
