# Deployment Framework

This directory contains a production-oriented, shell-based deployment framework for the MXA Transcription stack.

## Architecture this deploy framework targets

MXA Transcription is a **three-host deployment**:

1. **Frontend host**: Apache + PHP application + PostgreSQL
2. **Backend host**: FastAPI API + Celery worker + Redis + MinIO
3. **Identity host**: Keycloak

The framework keeps those concerns separated while still allowing a single orchestrator to deploy one role at a time.

## Directory layout

```text
deploy/
├── README.md
├── apache/
│   └── mxa-transcription.conf.template
├── env/
│   └── deploy.env.example
├── scripts/
│   ├── deploy-master.sh
│   ├── post-deploy-validate.sh
│   ├── pre-deploy-check.sh
│   ├── rollback.sh
│   ├── setup-app.sh
│   ├── setup-backend.sh
│   ├── setup-database.sh
│   ├── setup-keycloak.sh
│   ├── setup-storage.sh
│   ├── setup-web.sh
│   ├── setup-worker.sh
│   └── lib/
│       └── common.sh
└── systemd/
    ├── keycloak.service.template
    ├── minio.service.template
    ├── mxa-api.service.template
    └── mxa-celery.service.template
```

Legacy compatibility wrappers still exist under `deploy/php-server/`, `deploy/python-server/`, and `deploy/keycloak-server/` and now call into the new framework.

## Prerequisites

- Ubuntu or Debian-based target hosts with `systemd`
- `sudo` or root access on the target host
- Network connectivity between:
  - frontend → backend API
  - frontend → Keycloak
  - backend → PostgreSQL
- A checked out copy of this repository available on the deployment host **or** a reachable `REPO_URL`
- Deployment variables copied from `deploy/env/deploy.env.example`

## Configuration files used during deployment

1. **Deployment variables**: `deploy/env/deploy.env`
2. **Runtime application envs**:
   - `php-app/.env`
   - `python-backend/.env`

The deployment scripts will create the application runtime `.env` files from the repository examples if they do not already exist.

## Script flow

### 1. Pre-flight checks

```bash
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/pre-deploy-check.sh frontend
```

Validates:
- root privileges
- required binaries
- role argument
- required deployment variables
- repository structure

### 2. Main orchestration

```bash
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/deploy-master.sh frontend
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/deploy-master.sh backend
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/deploy-master.sh keycloak
```

The orchestrator calls the layered component scripts in the correct order.

### 3. Post-deploy validation

```bash
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/post-deploy-validate.sh frontend
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/post-deploy-validate.sh backend
sudo DEPLOY_ENV_FILE=/path/to/deploy.env ./deploy/scripts/post-deploy-validate.sh keycloak
```

## Recommended deployment order

1. `keycloak`
2. `backend`
3. `frontend`

## Manual deployment instructions

### Prepare deployment variables

```bash
cp deploy/env/deploy.env.example deploy/env/deploy.env
nano deploy/env/deploy.env
```

Set at minimum:
- `REPO_URL`
- `DEPLOY_BRANCH`
- frontend/backend/keycloak hostnames
- `DB_PASSWORD`
- `API_SECRET_KEY`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`
- `KEYCLOAK_ADMIN_PASSWORD`

### Deploy Keycloak host

```bash
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh keycloak
```

After Keycloak starts, complete the realm/client setup manually in the admin UI and copy the generated client secret into `php-app/.env`.

### Deploy backend host

```bash
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh backend
```

This installs:
- Python
- FastAPI dependencies
- Redis
- MinIO
- systemd units for API and Celery worker

### Deploy frontend host

```bash
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh frontend
```

This installs:
- Apache
- PHP extensions
- PostgreSQL
- Apache virtual host config
- database schema

## Update / redeploy

To update an existing deployment to the latest configured branch revision:

```bash
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh backend
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh frontend
```

The scripts are designed to be **idempotent where practical**:
- users are only created if missing
- packages are safe to reinstall
- git checkout resets to the configured branch
- env files are only bootstrapped if absent
- database creation only happens when missing
- schema import is skipped if core tables already exist

## Rollback

A lightweight rollback mechanism is provided for repository-based frontend/backend deployments.

```bash
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/rollback.sh frontend
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/rollback.sh backend
```

Rollback restores the previous recorded git revision and restarts the related services. It does **not** roll back database schema changes or MinIO object contents.

## Validation commands

### Frontend

```bash
systemctl status apache2 postgresql --no-pager
apache2ctl -t
curl -I http://127.0.0.1/
```

### Backend

```bash
systemctl status redis-server minio mxa-api mxa-celery --no-pager
curl http://127.0.0.1:8000/health
journalctl -u mxa-api -n 100 --no-pager
```

### Keycloak

```bash
systemctl status keycloak --no-pager
curl -I http://127.0.0.1:8080/
```

### Existing repository validator

If Python is available on the machine with a checked out repo:

```bash
python3 validate-deployment.py --role all
```

## Troubleshooting

### API service will not start
- Check `python-backend/.env`
- Confirm `API_SECRET_KEY`, `DATABASE_URL`, and MinIO credentials are set
- Review `journalctl -u mxa-api -f`

### Celery worker is unhealthy
- Confirm Redis is running
- Confirm FastAPI dependencies were installed into the virtualenv
- Review `journalctl -u mxa-celery -f`

### Frontend shows database or API errors
- Confirm `php-app/.env` values match backend and database settings
- Confirm PostgreSQL user/password exists
- Confirm backend is reachable on `${BACKEND_API_HOST:-192.168.1.90}:${BACKEND_API_PORT:-8000}`

### Keycloak login/redirect issues
- Verify the client redirect URI matches the frontend URL
- Verify the `KEYCLOAK_CLIENT_SECRET` in `php-app/.env`
- Confirm the Keycloak service is listening on the configured port

## Security notes

- Replace all placeholder secrets before production use
- Prefer HTTPS on the frontend and update app envs to use `https://` URLs
- Restrict backend, Redis, and MinIO ports to trusted networks
- Store deployment env files securely; they contain secrets
- Change MinIO and Keycloak bootstrap credentials immediately after install
- Review PostgreSQL authentication and TLS requirements for your environment
