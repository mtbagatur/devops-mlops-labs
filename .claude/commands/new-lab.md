---
description: Design and create the next runnable DevOps/MLOps break-fix lab
---

Create the next 30–45 minute hands-on DevOps/MLOps mini lab (Azure DevOps, Kubernetes, Helm, Linux, CI/CD, infrastructure automation, MLOps). Use a realistic production scenario with one concrete troubleshooting problem. Do not reveal the solution. Use the learner's recent performance to set difficulty and recycle weak areas.

## Procedure
1. Read `CLAUDE.md` and `progress/tracker.md`. List `labs/`; the new lab number is the highest number + 1 (two digits).
2. Pick the topic: current level; recycle at least one weak area if any exist; do not repeat the primary topic of the last 2 labs; prefer skill-matrix areas with the fewest labs. If 3+ labs are OPEN, keep the level and make it a shorter lab.
3. Decide the hidden root cause first (at higher levels, a primary cause plus a misleading symptom), then build the environment so the evidence follows from it.
4. Create `labs/lab-NN-<short-slug>/`:
   - `README.md`:
     ```
     # Lab NN — <title>
     > Status: OPEN · Created: <YYYY-MM-DD> · Level: <n – name> · Recycles: <area or —> · Time: 30–45 min
     **Focus:** <tags>
     ## Scenario            (production story, who reported what)
     ## Run it              (bash env/setup.sh … bash verify.sh … bash env/teardown.sh)
     ## Evidence            (what the on-call engineer sees first; pipeline output, alerts)
     ## Your task           (numbered questions; one concrete problem; include one "prevent it next time" item: pipeline gate, IaC change, or policy)
     ## Constraints         (secrets, preserve capacity, no deleting healthy pods, …)
     ## Deliverable         (write commands + reasoning + fix in answer.md, then /check-lab NN)
     ```
   - `env/setup.sh`, `env/teardown.sh`, `env/kind.yaml` (cluster `lab-NN`), plus the manifests/chart/pipeline files in their broken state. `set -euo pipefail`. Setup must be idempotent and finish in under 3 minutes on a laptop.
   - `verify.sh`: exits 0 only when the behaviour is fixed; prints a short PASS/FAIL per check.
   - `answer.md`: `# Answer — Lab NN` and an empty line.
   - `.solution.md`: root cause, why the symptoms look the way they do, reference command sequence, the fix, prevention, and a 10-point rubric.
5. Validate what you can in this environment: `bash -n` on every script; `helm lint`/`helm template` and `kubectl apply --dry-run=client` if the tools are available (try installing helm/kubectl if missing; skip gracefully if you cannot). Fix anything that fails.
6. Append a History row to `progress/tracker.md` (status `OPEN`, score `—`) and increment the skill-matrix "Labs" column for the areas touched.
7. If other labs are OPEN, add `Pending labs: #.., #..` at the end of the README.
8. Stage only the new lab directory and `progress/tracker.md`, commit with message `lab NN: <title>`, and push. If push fails, say so.
9. Final output: lab title, level, path, and how to start (`bash env/setup.sh`). Never print the solution.
