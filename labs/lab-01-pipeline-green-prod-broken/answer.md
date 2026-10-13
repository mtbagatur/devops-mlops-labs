# Answer — Lab 01

> Mode: guided (multiple-choice decision at each step). Full command log with outputs: [rounds.md](rounds.md).

## 1. Impact
`pricing.internal/health` returned **502** for ~13.5 minutes (09:27:44 → 09:41:12 UTC). 502 means NGINX was up but its upstream (`127.0.0.1:8080`) was not answering. A release had just been deployed, so rollback was kept as an option, but only after understanding what it would roll back.

## 2. Request path
`client → NGINX :443 → 127.0.0.1:8080 → gunicorn → systemd unit pricing-api → app → PostgreSQL / Redis`

## 3. Observation (read-only first)
| Command | What it proved |
|---|---|
| `sudo ss -tlnp \| grep 8080` | Nothing listening on 8080 → explains the 502 |
| `systemctl status pricing-api --no-pager` | Unit `failed`, restart loop hit `start-limit-hit` |
| `sudo journalctl -u pricing-api -n 50 --no-pager` | `Required environment variable DATABASE_URL is not set` |
| `systemctl cat pricing-api` | Variables come from `EnvironmentFile=/etc/pricing-api/pricing.env` |
| `sudo cut -d= -f1 /etc/pricing-api/pricing.env` | Keys only: `REDIS_HOST`, `LOG_LEVEL` — `DATABASE_URL` missing, no values printed |
| `sudo stat -c '%y %U' /etc/pricing-api/pricing.env` | Changed **Sep 29 23:10 by root**, ten hours before the deploy |
| `sudo journalctl --since '2026-09-29 23:05' --until '23:15'` + `crontab -l` | Nightly `ansible-pull` (role `app_env`) re-templated the file |

Mistake I made and corrected: I first reached for `systemctl show -p Environment`. It prints values of `Environment=` lines (secret-exposure habit) and ignores `EnvironmentFile=`, so it proved nothing.

## 4. Root cause
- `DATABASE_URL` had been added to `pricing.env` **by hand**. The nightly `ansible-pull` run renders that file from a template that only contains non-secret keys, so on Sep 29 23:10 it silently removed the line (configuration drift).
- The running process kept its old environment, so nothing broke until the 09:27 deploy restarted the service. **The deploy exposed the bug; it did not cause it.**
- Azure DevOps secret variables are never exported to scripts automatically, and the pipeline never delivers them to the host, so the variable group value could not help.
- The pipeline stayed green because `systemctl restart` returns as soon as the start job is queued, and the healthcheck used `curl -s` without `--fail`, so a 502 still exited 0.
- A pipeline rollback would not have helped: `pricing.env` is not part of the release artefact.

## 5. Mitigation (no secret exposure)
```bash
sudo install -m 600 -o root -g root /dev/null /etc/pricing-api/secrets.env
az keyvault secret show --vault-name kv-pricing-prod -n database-url --query value -o tsv \
  | sed 's/^/DATABASE_URL=/' | sudo tee /etc/pricing-api/secrets.env >/dev/null
sudo cut -d= -f1 /etc/pricing-api/secrets.env          # verify key only
sudo systemctl edit pricing-api                        # [Service] EnvironmentFile=/etc/pricing-api/secrets.env
sudo systemctl daemon-reload
sudo systemctl reset-failed pricing-api                # clear start-limit-hit
sudo systemctl start pricing-api
```
- File is created 0600 **before** the secret is written; the value never touches the screen, shell history or process arguments.
- Ansible only manages `pricing.env`, so the separate file survives tonight's 23:10 run.
- systemd reads `EnvironmentFile` as root, so the service user does not need read access.

## 6. Verification
```bash
sudo ss -tlnp | grep 8080                     # gunicorn listening
curl -fsS http://127.0.0.1:8080/health        # {"status":"ok","db":"ok",...}
curl -fsS https://pricing.internal/health     # same, through NGINX
sudo journalctl -u pricing-api -f             # 5 minutes, only 200s
```
Alert resolved at 09:42:10 UTC.

## 7. Prevention
1. **Secrets as code.** The `app_env` Ansible role renders `secrets.env` (0600, root) from Azure Key Vault using the VM's managed identity. No hand-edited config on servers.
2. **Honest pipeline health gate** with automatic rollback:
   ```yaml
   - script: |
       set -euo pipefail
       ssh deploy@prod-api-01 'curl -fsS --retry 10 --retry-delay 3 --retry-all-errors http://127.0.0.1:8080/health'
       curl -fsS --retry 10 --retry-delay 3 --retry-all-errors https://pricing.internal/health
     displayName: Healthcheck
   - script: ssh deploy@prod-api-01 'sudo ln -sfn "$(readlink /opt/pricing-api/previous)" /opt/pricing-api/current && sudo systemctl restart pricing-api'
     displayName: Roll back
     condition: failed()
   ```
3. **Safe release layout.** Copy each build to `/opt/pricing-api/releases/<build-id>` and switch the `current` symlink atomically. The current step points `current` at the agent's `$(Build.ArtifactStagingDirectory)`, which is wiped on the next build — production code would disappear from disk. `stop → swap → restart` also causes downtime on every deploy.
4. Not done on purpose: raising `StartLimitBurst`. A missing secret never fixes itself; the start limit is a useful signal.
