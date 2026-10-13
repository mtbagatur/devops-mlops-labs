# Mini Lab #04 — Helm + Kubernetes: "The ConfigMap changed. The application didn't."
> Status: OPEN · Created: imported from chat · Level: 2→3 – Intermediate → Intermediate+ · Recycles: —

**Timebox:** 30–45 min · **Focus:** Kubernetes · Helm · ConfigMap · rollout mechanics · Azure DevOps CI/CD

## Scenario
You maintain `order-api` in production. Yesterday it ran `order-api:v4.6.2` with `PAYMENT_TIMEOUT=5`. Today the application team asks to increase it to `15`. No application code changed.

```yaml
# values-prod.yaml
config:
  paymentTimeout: "15"
```

The Deployment uses `envFrom` with `order-api-config`; the ConfigMap renders `PAYMENT_TIMEOUT` from Helm values. The pipeline runs `helm upgrade` with the **same image tag**.

## Evidence
- Pipeline: Helm upgrade ✅, deployment ready ✅, smoke test ✅.
- Live ConfigMap says `15`.
- `printenv PAYMENT_TIMEOUT` inside a pod still says `5`.
- All pods are three days old.

## Your task
Prove why Kubernetes behaved this way, then fix the deployment safely. Give roughly 8–15 commands. Investigate **Helm values → ConfigMap → Deployment PodTemplate → ReplicaSet → running Pod environment**. Determine:
1. whether Helm received `15`,
2. whether it rendered the expected ConfigMap,
3. why changing a ConfigMap didn't create new pods,
4. what part of a Deployment determines ReplicaSet creation,
5. why `envFrom` differs from mounted ConfigMap files,
6. how to roll out the corrected configuration now.

**IaC challenge:** modify the Helm Deployment template so that whenever the rendered ConfigMap changes, Helm automatically changes the PodTemplate and triggers a normal rolling deployment.

**Finish by verifying:** ConfigMap = 15, pod environment = 15, new ReplicaSet exists, 4/4 replicas Ready, old ReplicaSet scaled to 0, service still responds correctly.

## How to answer
Write in `answer.md`, then run `/check-lab 04`.
