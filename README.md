# DevOps / MLOps Labs

Hands-on break-fix labs for production troubleshooting across **Kubernetes, Helm, Azure DevOps, Linux, CI/CD, infrastructure as code and MLOps**.

Each lab is a realistic incident: a broken environment that runs locally on `kind`, a task, my investigation and fix (`answer.md`), and a graded review (`review.md`). New labs arrive three times a week and adapt to my weak areas; progress is tracked in [progress/tracker.md](progress/tracker.md).

## Labs
See [labs/](labs/). Labs 01–06 are scenario-only (simulated environment); later labs are fully runnable.

## Running a lab
Requirements: Docker Desktop, `kind`, `kubectl`, `helm`, and Git Bash or WSL.

```bash
cd labs/lab-07-<name>
bash env/setup.sh      # creates kind cluster "lab-07" in a broken state
# ...investigate and fix...
bash verify.sh         # exits 0 when the system is really fixed
bash env/teardown.sh
```

Spoiler warning: `.solution.md` in each lab contains the root cause.

## How the program works
- Three sessions a week (Mon · Wed · Fri). Each new lab is designed from the weak areas in my tracker.
- I solve it locally, then `/check-lab NN` grades the answer, writes `review.md` and updates the tracker.
- Difficulty rises after two strong results in a row; weak areas are recycled into upcoming labs.
