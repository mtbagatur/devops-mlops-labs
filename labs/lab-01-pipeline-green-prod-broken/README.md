# Mini Lab #01 — "Pipeline green, production broken"
> Status: OPEN · Created: imported from chat · Level: 2 – Intermediate · Recycles: —

**Timebox:** 30–45 min · **Focus:** Azure DevOps · Linux · systemd · CI/CD · production troubleshooting

## Scenario
You are on-call for a production Linux server. An internal Python API called `pricing-api` is deployed through Azure DevOps. The release pipeline finished green two minutes ago:

```
Build        ✅
Tests        ✅
Deploy       ✅
Healthcheck  ✅
```

Ninety seconds later the uptime monitor pages you:

```
[FIRING] pricing-api health  GET https://pricing.internal/health → 502 Bad Gateway
```

NGINX is running and proxies traffic to `127.0.0.1:8080`. The application runs as a `systemd` service.

## Evidence
```
$ sudo systemctl status pricing-api
● pricing-api.service - Pricing API
     Loaded: loaded (/etc/systemd/system/pricing-api.service; enabled)
     Active: failed (Result: exit-code)

Sep 30 09:27:42 prod-api-01 pricing-api[18422]:
ERROR: Required environment variable DATABASE_URL is not set
```

Unit file:
```ini
[Unit]
Description=Pricing API
After=network.target

[Service]
User=pricing
WorkingDirectory=/opt/pricing-api/current
EnvironmentFile=/etc/pricing-api/pricing.env
ExecStart=/opt/pricing-api/current/venv/bin/gunicorn \
          --bind 127.0.0.1:8080 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Environment file:
```
$ sudo cat /etc/pricing-api/pricing.env
REDIS_HOST=10.20.1.15
LOG_LEVEL=INFO
```
`DATABASE_URL` is missing.

Production variable group in Azure DevOps:
```
DATABASE_URL = ********   (secret)
REDIS_HOST   = 10.20.1.15
LOG_LEVEL    = INFO
```

Deployment step:
```yaml
- script: |
    echo "Deploying application..."
    sudo systemctl stop pricing-api

    sudo ln -sfn $(Build.ArtifactStagingDirectory)/release \
        /opt/pricing-api/current

    sudo systemctl daemon-reload
    sudo systemctl restart pricing-api

    echo "Deployment completed."
  displayName: Deploy pricing-api

- script: |
    curl -s https://pricing.internal/health
    echo "Healthcheck done."
  displayName: Healthcheck
```

## Your task
Do not just say "add `DATABASE_URL`". Diagnose the deployment design.

Give the commands/checks you would perform **in order**, from the moment you SSH into the server until the service is healthy. Then answer:

1. What is the immediate production fix?
2. What is the root cause in the CI/CD design?
3. How would you modify the pipeline so the required environment reaches `systemd` securely?
4. Why did both Deploy and Healthcheck report ✅ while the application was dead, and how would you change the pipeline so that cannot happen again?
5. Bonus: identify one additional production risk hidden in this deployment step.

## Constraints
- Treat it as a real incident. You have sudo.
- Do not print or expose the database secret in logs or terminal output.

## How to answer
This lab is simulated: tell Claude your first command and it returns the server's output. Work step by step, then put the final answer in `answer.md` and run `/check-lab 01`.
