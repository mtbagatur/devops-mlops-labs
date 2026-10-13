# Mini Lab #05 — Production Incident: ML Model Deployment Keeps Crashing
> Status: OPEN · Created: imported from chat · Level: 2 – Intermediate · Recycles: — · **Interactive**

**Timebox:** 30–45 min · **Focus:** Kubernetes · Helm · Azure DevOps · Linux · MLOps · resource management · CI/CD configuration

## Scenario
You are responsible for a production ML inference service, `prediction-api`. Version `v2.4.0` includes a newly trained model. Build and push succeed, Helm upgrade succeeds, but deployment verification fails. Old `v2.3.0` pods are still serving production traffic. The new pod is `CrashLoopBackOff`.

## Evidence
```
$ kubectl describe pod ...
Last State:
  Terminated
  Reason:    OOMKilled
  Exit Code: 137

Limits:
  cpu:     1000m
  memory:  512Mi
Requests:
  cpu:     250m
  memory:  256Mi
```
Application logs stop while loading the ML model into memory.

Repository `values-prod.yaml`:
```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```
But the running container has a **512Mi** limit (and a 256Mi request).

Azure DevOps deploy stage:
```yaml
arguments: >
  --install
  --set image.tag=$(IMAGE_TAG)
  --set-string resources.limits.memory=$(MEMORY_LIMIT)
  --wait
  --timeout 5m
```
`IMAGE_TAG` and `MEMORY_LIMIT` come from a variable group.

## Your assignment
Establish why the pod was killed, determine why the effective Kubernetes config differs from repository config, and implement a safe correction.

**Do not** delete healthy pods, blindly increase limits, or assume OOMKilled alone explains why memory usage increased.

### Round 1
1. What is your initial hypothesis?
2. What are the first three commands you would run next, and what does each establish?

## How to answer
This lab is interactive. Write Round 1 in `answer.md` and run `/check-lab 05` — the simulated environment returns realistic terminal outputs (saved in `rounds.md`) and continues the incident until you resolve it.
