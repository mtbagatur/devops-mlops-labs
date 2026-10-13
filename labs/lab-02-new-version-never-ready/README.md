# Mini Lab #02 — Kubernetes + Helm: "Deployment succeeded, but the new version never becomes ready"
> Status: REVIEWED · Score 9/10 · Created: imported from chat · Level: 2 – Intermediate · Recycles: —

**Timebox:** 30–45 min · **Focus:** Kubernetes · Helm · Azure DevOps · CI/CD · Linux/container troubleshooting

## Scenario
Today you are deploying `recommendation-api:v2.8.0` to production. Azure DevOps reports:

```
Build image        ✅
Push image         ✅
Helm upgrade       ✅
Deployment verify  ❌

Error: deployment "recommendation-api" exceeded its progress deadline
```

Pipeline steps:
```bash
# Helm upgrade
helm upgrade --install recommendation-api ./charts/recommendation-api \
  --namespace production \
  --set image.tag=v2.8.0

# Deployment verify
kubectl rollout status deployment/recommendation-api -n production --timeout=12m
```

## Evidence
```
$ kubectl get pods -n production
NAME                                  READY  STATUS   RESTARTS  AGE
recommendation-api-6f9db77f85-8kp2m   0/1    Running  0         11m
recommendation-api-6f9db77f85-h7x9q   0/1    Running  0         11m
recommendation-api-748bc5c477-r2md9   1/1    Running  0         3d
recommendation-api-748bc5c477-vj5zx   1/1    Running  0         3d
```
The new containers are running, but Kubernetes never marks them Ready.

```
$ kubectl describe deployment recommendation-api -n production
Replicas: 4 desired | 2 updated | 4 total | 2 available | 2 unavailable
Conditions:
  Available     True
  Progressing   False
Reason:
  ProgressDeadlineExceeded
```

Helm template (excerpt):
```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 50%
  template:
    spec:
      containers:
        - name: recommendation-api
          image: "registry.internal/recommendation-api:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
```

`kubectl describe pod` shows readiness probe **HTTP 503**. Application logs: Redis connected → model loads → **feature-store connection times out**.

```
$ kubectl exec -n production recommendation-api-6f9db77f85-8kp2m -- printenv FEATURE_STORE_URL
http://feature-store.ml-platform.svc.cluster.local:9000
```

## Your task
Starting from the information above, show exactly what you would investigate next and in what order. Cover:
- application vs networking vs DNS vs Service vs configuration,
- commands from inside the pod,
- Kubernetes resources around `feature-store`,
- likely config mistakes if the feature-store service itself is healthy,
- end-to-end verification,
- one thing in the Deployment spec that made this incident worse than it needed to be.

## Constraints
- Production traffic is still served by two old `v2.7.x` pods. Preserve healthy capacity while troubleshooting.

## How to answer
This lab is simulated: tell Claude your commands one stage at a time and it returns the cluster's output. Put the final answer in `answer.md` and run `/check-lab 02`.
