# Progress Tracker

**Current level:** 2 – Intermediate
**Level rule:** +1 after 2 consecutive ≥ 8/10 · −1 after 2 consecutive ≤ 4/10

## Skill matrix
| Area | Labs touching it | Reviewed | Avg score |
|---|---|---|---|
| Linux / systemd | 01 | 0 | — |
| Azure DevOps pipelines & variable groups | 01, 03, 04, 05 | 0 | — |
| Secret flow (ADO → Helm → K8s) | 01, 03 | 0 | — |
| K8s readiness / probes | 02 | 0 | — |
| K8s networking / DNS / Service / NetworkPolicy | 02 | 0 | — |
| Helm values precedence & release history | 03, 04, 05 | 0 | — |
| ConfigMap / rollout mechanics | 04 | 0 | — |
| Resources / OOMKilled / MLOps memory | 05 | 0 | — |
| Scheduling / GPU / rollout strategy | 06 | 0 | — |
| Infrastructure as Code (Terraform/Bicep/Ansible) | — | 0 | — |
| Observability (Prometheus/Grafana/logs) | — | 0 | — |
| Container images / registry / supply chain | — | 0 | — |
| Ingress / TLS / certificates | — | 0 | — |
| Rollback / release strategies (canary, blue-green) | 06 | 0 | — |

## Weak areas (recycle these)
_None recorded yet — no lab has been answered. Do not infer weak areas from unanswered labs._

## Notes from the original chat (imported 2026-10-13)
- Labs 01–06 were generated in a chat but **none was answered**, so difficulty never actually adapted (05 and 06 were both still "Intermediate").
- 01 and 03 share the same core lesson (secret in variable group never reaches the runtime). 03, 04, 05 all involve "repo values ≠ effective values". Avoid these as primary topics for the next new labs until reviewed.
- Uncovered so far: IaC, observability, Ingress/TLS, image supply chain, canary/blue-green, Linux performance (disk, inode, CPU, file descriptors).

## History
| Lab | Title | Level | Primary topic | Status | Score | Date |
|---|---|---|---|---|---|---|
| 01 | Pipeline green, production broken | 2 | systemd + ADO secret flow | OPEN | — | imported |
| 02 | New version never becomes ready | 2 | readiness / K8s networking | OPEN | — | imported |
| 03 | Works manually, fails after deployment | 2 | Helm secret flow | OPEN | — | imported |
| 04 | ConfigMap changed, app didn't | 2–3 | ConfigMap rollout | OPEN | — | imported |
| 05 | ML model deployment keeps crashing | 2 | OOMKilled / values precedence | OPEN | — | imported |
| 06 | Cannot schedule the new ML model | 2 | GPU scheduling / rollout strategy | OPEN | — | imported |
