# DevOps / MLOps Labs

Hands-on break-fix labs for production troubleshooting across **Kubernetes, Helm, Azure DevOps, Linux, CI/CD, infrastructure as code and MLOps**.

Each lab is a realistic incident: a broken environment that runs locally on `kind`, a task, my investigation and fix (`answer.md`), and a graded review (`review.md`). Labs adapt to my weak areas; progress and scores are tracked in [progress/tracker.md](progress/tracker.md).

## Labs
| # | Incident | Skills | Format |
|---|---|---|---|
| [01](labs/lab-01-pipeline-green-prod-broken) | Pipeline green, production broken | Linux, systemd, Azure DevOps secrets, health gates | Simulated |
| [02](labs/lab-02-new-version-never-ready) | New version never becomes Ready | Readiness probes, DNS, Services, NetworkPolicy, rollout strategy | Simulated |
| [03](labs/lab-03-works-manually-fails-after-deploy) | Works manually, fails after deployment | Helm-managed Secrets, Azure DevOps secret flow, Key Vault | Simulated |
| [04](labs/lab-04-configmap-changed-app-didnt) | The ConfigMap changed, the app didn't | ConfigMap rollout, PodTemplate hash, Helm checksum annotation | **Runnable** |
| [05](labs/lab-05-ml-model-oomkilled) | ML model deployment keeps crashing | OOMKilled, Helm values precedence, model memory budgeting | Simulated |
| [06](labs/lab-06-gpu-scheduling-new-model) | Cannot schedule the new ML model | GPU scheduling, maxSurge/maxUnavailable, AKS node pools | Simulated |

Simulated labs are worked through interactively with the environment's output played back step by step; runnable labs ship a broken `kind` cluster and a `verify.sh`.

## Running a lab
Requirements: Linux (or Ubuntu on WSL2) with Docker Engine, `kind`, `kubectl`, `helm` and `jq`. On a fresh Ubuntu, `bash scripts/setup-wsl-ubuntu.sh` installs all of them.

```bash
cd labs/lab-07-<name>
bash env/setup.sh      # creates kind cluster "lab-07" in a broken state
# ...investigate and fix...
bash verify.sh         # exits 0 when the system is really fixed
bash env/teardown.sh
```

Spoiler warning: `.solution.md` in each lab contains the root cause.

## How the program works
- Sessions are scheduled around work. Each new lab is designed from the weak areas in my tracker.
- I solve it locally, then `/check-lab NN` grades the answer, writes `review.md` and updates the tracker.
- Difficulty rises after two strong results in a row; weak areas are recycled into upcoming labs.
