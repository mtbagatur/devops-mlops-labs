# Mini Lab #06 — Production Incident: Kubernetes Cannot Schedule the New ML Model
> Status: OPEN · Created: imported from chat · Level: 2 – Intermediate · Recycles: — · **Interactive**

**Timebox:** 30–45 min · **Focus:** Kubernetes scheduling · GPU resources · deployment strategies · zero-downtime releases · Helm · Azure DevOps · MLOps

## Scenario
You are responsible for `vision-inference-api`, which uses NVIDIA GPUs. A new model `v3.2.0` is released through Azure DevOps. Helm upgrade fails with `context deadline exceeded`. Two old pods remain healthy. One new pod is `Pending`.

## Evidence
```
0/3 nodes are available:
  2 Insufficient nvidia.com/gpu,
  1 node(s) didn't match Pod's node affinity/selector.
```
New pod: requests 1 GPU, 2 CPU, 4Gi memory; limits 1 GPU, 4 CPU, 8Gi memory.

Helm values:
```yaml
nodeSelector:
  workload: gpu-inference

strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```
The pipeline runs Helm upgrade with `--wait --timeout 5m`.

## Your mission
Deploy `v3.2.0` successfully without unnecessarily interrupting production traffic. Establish:
- why scheduling fails,
- whether the cluster has sufficient GPU capacity,
- how `maxSurge` and `maxUnavailable` affect this rollout,
- whether changing the deployment strategy is safe,
- what infrastructure changes might be necessary,
- how to prevent this in future pipelines.

### Round 1
1. What is your initial diagnosis?
2. What are the first three commands to investigate GPU capacity, node configuration and allocation?
3. Before changing anything, what would you establish about the existing production workload?

## How to answer
This lab is interactive. Write Round 1 in `answer.md` and run `/check-lab 06` — the simulated environment returns realistic terminal outputs (saved in `rounds.md`) and continues the incident.
