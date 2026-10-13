# Lab 01 — Investigation log

Guided mode: each step is a multiple-choice decision following the incident method (impact → request path → observe → hypothesis → fix → verify → prevent).

## Step 1–2 — Impact and request path
- 502 from NGINX = NGINX is up, its upstream is not answering. A new release was just deployed, so rollback stays on the table.
- Path: `client → NGINX :443 → 127.0.0.1:8080 → gunicorn → systemd unit pricing-api → app → DB / Redis`

## Step 3 — Is anything listening on 8080?
Choice: `sudo ss -tlnp | grep 8080` ✅ (read-only, shows listener and owning process)

```
$ sudo ss -tlnp | grep 8080
$ echo $?
1
```
Finding: nothing listens on 8080 → explains the 502. Next layer: the systemd unit.

## Step 4 — systemd unit state and logs
Choice: `systemctl status pricing-api --no-pager` + `sudo journalctl -u pricing-api -n 50 --no-pager` ✅

```
× pricing-api.service - Pricing API
     Active: failed (Result: exit-code) since Tue 2026-09-30 09:27:44 UTC; 4min ago
   Main PID: 18422 (code=exited, status=1/FAILURE)
Sep 30 09:27:43 systemd[1]: pricing-api.service: Scheduled restart job, restart counter is at 5.
Sep 30 09:27:44 systemd[1]: pricing-api.service: Start request repeated too quickly.

Sep 30 09:27:39 pricing-api[18390]: ERROR: Required environment variable DATABASE_URL is not set
Sep 30 09:27:39 systemd[1]: pricing-api.service: Main process exited, code=exited, status=1/FAILURE
```
Findings: app exits immediately on missing DATABASE_URL; Restart=always looped 5× then hit the start limit.
Hypothesis: DATABASE_URL is not reaching the unit's environment.

## Step 5 — Why is DATABASE_URL missing?
Choice: `sudo systemctl show pricing-api -p Environment` ⚠️
```
Environment=
```
Why weak: prints values of `Environment=` (secret exposure habit), and ignores `EnvironmentFile=`, so it proves nothing here and says nothing about when the file changed. Retried.

Retry: `systemctl cat pricing-api` + `sudo cut -d= -f1 /etc/pricing-api/pricing.env` + `sudo stat -c '%y %U' /etc/pricing-api/pricing.env` ✅
```
EnvironmentFile=/etc/pricing-api/pricing.env
---
REDIS_HOST
LOG_LEVEL
---
2026-09-29 23:10:07.412883911 +0000 root
```
Timeline: file changed Sep 29 23:10 (root) → running process kept old env → Sep 30 09:27 deploy restart re-read the file → crash.
The deploy did not cause the bug; it exposed it.

## Step 6 — Who changed the file?
Choice: journal around 23:10 + `ls -lt` ✅ (timeboxed: prod is down, 2–3 min max before mitigating)
```
Sep 29 23:10:01 CRON[90211]: (root) CMD (/usr/local/bin/ansible-pull -U https://git.example.internal/platform/baseline.git ... site.yml)
Sep 29 23:10:07 ansible-ansible.legacy.copy[90379]: Invoked with dest=/etc/pricing-api/pricing.env mode=0644 owner=root
TASK [app_env : Render pricing-api environment file]  changed: [localhost]
crontab: 10 23 * * * /usr/local/bin/ansible-pull ...
```
Finding: nightly ansible-pull (role `app_env`) re-templates pricing.env without DATABASE_URL, which had been added by hand. A manual fix will be wiped again tonight at 23:10.
Rejected options: pipeline rollback (env file is not part of the release), `chattr +i` (hides the symptom, breaks automation), restore from backup (unknown contents, source still active).

## Step 7 — Smallest safe fix (no secret exposure)
Choice: separate root-owned 0600 secrets file + drop-in `EnvironmentFile=` ✅
```
sudo install -m 600 -o root -g root /dev/null /etc/pricing-api/secrets.env
az keyvault secret show --vault-name kv-pricing-prod -n database-url --query value -o tsv \
  | sed 's/^/DATABASE_URL=/' | sudo tee /etc/pricing-api/secrets.env >/dev/null
sudo cut -d= -f1 /etc/pricing-api/secrets.env      # → DATABASE_URL (key only)
sudo systemctl edit pricing-api                    # [Service] EnvironmentFile=/etc/pricing-api/secrets.env
sudo systemctl daemon-reload && sudo systemctl reset-failed pricing-api && sudo systemctl start pricing-api
→ Active: active (running), Drop-In: override.conf
```
Why: file created with correct mode before the secret lands; value never hits screen, history or argv; Ansible only owns pricing.env so the fix survives tonight; systemd reads EnvironmentFile as root; reset-failed clears start-limit-hit.
Rejected: echo (history + 0644 file), drop-in `Environment=` (world-readable unit, visible in `systemctl show`), re-running the pipeline (file still missing).

## Step 8 — End-to-end verification
Choice: layer by layer ✅
```
ss -tlnp | grep 8080           → gunicorn listening on 127.0.0.1:8080
curl -fsS 127.0.0.1:8080/health → {"status":"ok","db":"ok","redis":"ok","version":"2026.09.30.3"}
curl -fsS https://pricing.internal/health → same
journalctl -u pricing-api -f (5 min) → only 200s
[RESOLVED] 09:42:10 UTC — outage 09:27:44 → 09:41:12 (~13.5 min)
```
Key habit: `curl -fsS` — without `-f` a 502 is a "successful" request, which is exactly why the pipeline healthcheck stayed green.

## Step 9 — Prevention
Chosen (3/3 correct, trap avoided): secrets rendered by Ansible from Key Vault; honest healthcheck (`curl -fsS --retry`) with automatic rollback; versioned release directories with atomic symlink switch.
Rejected: raising `StartLimitBurst` — hides a crash loop that cannot heal itself.
