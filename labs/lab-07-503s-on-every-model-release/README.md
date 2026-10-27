# Lab 07 — "Every model release causes a minute of 503s"
> Status: OPEN · Created: 2026-10-27 · Level: 2 – Intermediate · Recycles: mitigating first and reverting temporary changes · Time: 30–40 min · **Runnable**

**Focus:** MLOps · LLM serving · Kubernetes probes · rolling updates · release safety

## Scenario
`llm-gateway` serves the customer-support assistant. It runs an OpenAI-compatible inference server (the same endpoints as vLLM: `/health`, `/v1/models`, `/v1/completions`) with 3 replicas behind a Service. Loading the model weights takes about 20 seconds after the process starts.

Today the ML team shipped `support-llm-v2`. The release pipeline ran `kubectl apply -f env/manifests` and `kubectl rollout status`, and reported success. Five minutes later the on-call engineer got this alert:

```
[FIRING] llm-gateway 5xx ratio > 5%   value=16%   for=2m
         window matches the deploy window; resolved by itself after the rollout finished
```

The ML team says it happens on every model release, "but it fixes itself, so we never looked into it". The support team is now asking for a release process that customers don't notice.

## Run it
Requirements: Linux or Ubuntu on WSL2 with Docker Engine, `kind`, `kubectl` (see [scripts/setup-wsl-ubuntu.sh](../../scripts/setup-wsl-ubuntu.sh)). First run takes ~2 minutes.

```bash
cd labs/lab-07-503s-on-every-model-release
bash env/setup.sh        # creates kind cluster "lab-07" and deploys today's release
source env/use.sh        # points kubectl at this lab only
bash env/traffic.sh      # replays a release under live traffic and prints ok/failed counts
# ... investigate and fix ...
bash verify.sh           # all checks must PASS (it replays a release under traffic, ~2 min)
bash env/teardown.sh     # when you are done
```

If another kind cluster is running, `kube-proxy` in `lab-07` can crash with `too many open files` (kind's known inotify limit) and every Service call times out. Stop the other cluster, or raise `fs.inotify.max_user_instances` (e.g. 512) on the host.

The manifests in [env/manifests](env/manifests) are the production repo. Change them and `kubectl apply -f env/manifests -n support-ai`; don't patch live objects by hand.

## Evidence
```
$ kubectl get pods -n support-ai
NAME                           READY   STATUS    RESTARTS   AGE
llm-gateway-7d9c6b8f4-2xkqp    1/1     Running   0          6m
llm-gateway-7d9c6b8f4-9hm7w    1/1     Running   0          6m
llm-gateway-7d9c6b8f4-tq4rz    1/1     Running   0          6m

$ bash env/traffic.sh
== Traffic running; starting a release (rollout restart)
== Rollout finished; waiting for the client to finish its 120s window
ok=395 failed=73
```
Pipeline logs show `deployment "llm-gateway" successfully rolled out` every time.

## Your task
1. **Explain the 503s.** During a rollout, which pods receive traffic, and why are some of them unable to answer? Show the commands and output that prove it (pod events, probe config, what each endpoint returns on a fresh pod).
2. **Mitigate first.** If this happened during a business-critical release and you had 2 minutes, what would you do right now, and what temporary change would you have to undo later?
3. **Fix it in the repo** so that a release under live traffic causes zero failed requests, with 3 replicas kept. Apply from `env/manifests`.
4. **Liveness vs readiness.** Should the liveness probe use the same endpoint as your new readiness probe? What happens if the model takes 3 minutes to load (a bigger model)? Name the probe type built for that case.
5. **Prevent it next time.** Propose one pipeline gate or policy that would have caught this before customers did.

## Constraints
- Keep 3 replicas and keep serving during the fix; don't delete healthy pods.
- Don't patch live objects with `kubectl edit`/`patch` as the final fix; the repo is the source of truth.
- Production habit: say what you change and how you would roll it back.

## Deliverable
Write your commands, reasoning and fix in [answer.md](answer.md), then run `/check-lab 07`.

Pending labs: #04, #05, #06
