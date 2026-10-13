# Lab 04 — "The ConfigMap changed. The application didn't."
> Status: OPEN · Created: imported from chat, made runnable 2026-10-13 · Level: 3 – Intermediate+ · Recycles: — · Time: 30–45 min · **Runnable**

**Focus:** Kubernetes · Helm · ConfigMap · rollout mechanics · CI/CD

## Scenario
You maintain `order-api` in production. Yesterday it ran version `4.6.2` with `PAYMENT_TIMEOUT=5`. Today the payments team asked to increase it to `15`. No application code changed. Someone updated `values-prod.yaml`:

```yaml
config:
  paymentTimeout: "15"
```

The release pipeline ran `helm upgrade` with the same image tag and reported:

```
Helm upgrade      ✅
Deployment ready  ✅
Smoke test        ✅
```

An hour later the payments team says checkouts still time out after 5 seconds.

## Run it
Requirements: Docker Desktop running, `kind`, `kubectl`, `helm`, Git Bash or WSL.

```bash
cd labs/lab-04-configmap-changed-app-didnt
bash env/setup.sh        # creates kind cluster "lab-04" and replays yesterday's and today's releases
source env/use.sh        # points kubectl and helm at this lab only (your other clusters are untouched)
kubectl get pods -n shop
# ... investigate and fix ...
bash verify.sh           # all checks must PASS
bash env/teardown.sh     # when you are done
```

The chart you are responsible for is in [chart/order-api](chart/order-api). Treat it as the production repo.

## Your task
Prove why Kubernetes behaved this way, then fix it safely. Follow the chain **Helm values → ConfigMap → Deployment PodTemplate → ReplicaSet → running Pod**, and answer:

1. Did Helm receive `15`? Show the command that proves it.
2. Did Helm render the expected ConfigMap? Is it live?
3. Why did changing the ConfigMap not create new pods?
4. Which part of a Deployment decides whether a new ReplicaSet is created?
5. How would the behaviour differ if the ConfigMap were mounted as a volume instead of `envFrom`? Would that have fixed this incident?
6. Roll out the corrected configuration now, without losing capacity.
7. **IaC fix:** change the chart so that any change to the rendered ConfigMap automatically changes the PodTemplate and triggers a normal rolling update. Deploy it through Helm.
8. **Pipeline:** the smoke test passed while production ran the old value. What should the pipeline check instead?

## Constraints
- Do not delete pods or the Deployment by hand.
- Production must keep 4 Ready replicas during the rollout.
- The final state must come from Helm and the chart in this repo, not from `kubectl edit`.

## Deliverable
Write your commands, what each one proved, and your chart change in [answer.md](answer.md). Run `bash verify.sh`, then `/check-lab 04`.
