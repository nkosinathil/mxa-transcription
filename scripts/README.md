# Deployment Scripts

This folder contains server-focused deployment scripts for the three-server web
architecture.

## Structure

- `deploy/setup-app-server.sh` - App server setup (PHP/Apache/PostgreSQL)
- `deploy/setup-python-server.sh` - Python server setup (FastAPI/Celery/Redis/MinIO)
- `deploy/setup-sso-server.sh` - SSO server setup (Keycloak)
- `deploy/setup-all.sh` - wrapper entrypoint
- `deploy/deploy.sh` - one-command deploy entrypoint using a shared env file
- `deploy/rollback.sh` - one-command rollback entrypoint by role
- `deploy/env.example` - shared configuration template for `deploy.sh`
- `lib/common.sh` - shared shell helpers

## Interactive usage

Run on each target server as root (or via sudo):

```bash
# On app server
sudo ./scripts/deploy/setup-app-server.sh

# On python server
sudo ./scripts/deploy/setup-python-server.sh

# On sso server
sudo ./scripts/deploy/setup-sso-server.sh
```

Or use the wrapper:

```bash
sudo ./scripts/deploy/setup-all.sh app
sudo ./scripts/deploy/setup-all.sh python
sudo ./scripts/deploy/setup-all.sh sso
```

## Recommended: single-file deploy flow

1. Copy and edit a single config file:

```bash
cp scripts/deploy/env.example scripts/deploy/env.sh
# edit scripts/deploy/env.sh with your real server values/secrets
```

2. On each server, run the same command with its role:

```bash
# On SSO server
sudo ./scripts/deploy/deploy.sh --role sso --config ./scripts/deploy/env.sh

# On Python server
sudo ./scripts/deploy/deploy.sh --role python --config ./scripts/deploy/env.sh

# On App server
sudo ./scripts/deploy/deploy.sh --role app --config ./scripts/deploy/env.sh
```

This command automatically exports values from the config file and invokes the
correct role setup script in non-interactive mode.

## Non-interactive / CI usage

All setup scripts support non-interactive mode:

- Set `NON_INTERACTIVE=true` (or pass `--non-interactive` in wrapper)
- Provide required values via environment variables

### App server example

```bash
sudo env NON_INTERACTIVE=true \
  DB_PASS='strong-db-pass' \
  KEYCLOAK_CLIENT_SECRET='kc-secret' \
  PYTHON_API_KEY='shared-api-key' \
  MINIO_ACCESS_KEY='minio-user' \
  MINIO_SECRET_KEY='minio-pass' \
  ./scripts/deploy/setup-app-server.sh
```

### Python server example

```bash
sudo env NON_INTERACTIVE=true \
  API_SECRET_KEY='shared-api-key' \
  POSTGRES_DSN='postgresql://transcription_user:strong-db-pass@192.168.1.66:5432/transcription_db' \
  MINIO_ACCESS_KEY='minio-user' \
  MINIO_SECRET_KEY='minio-pass' \
  CORS_ALLOW_ORIGINS='https://transcription.example.com' \
  ./scripts/deploy/setup-python-server.sh
```

### SSO server example

```bash
sudo env NON_INTERACTIVE=true \
  KC_ADMIN_PASS='admin-pass' \
  KC_DB_PASS='keycloak-db-pass' \
  REALM_NAME='mxa' \
  APP_URL='https://transcription.example.com' \
  ./scripts/deploy/setup-sso-server.sh
```

## Rollback / cleanup by role

If you started setup on the wrong server role, run:

```bash
# On server that needs cleanup
sudo ./scripts/deploy/rollback.sh app
# or
sudo ./scripts/deploy/rollback.sh python
# or
sudo ./scripts/deploy/rollback.sh sso
```

`rollback.sh` stops/disables related services, removes systemd units, and
cleans role-specific artifacts (for example, accidental `python-backend/.venv`
on app servers).

## Idempotency notes

- Scripts are designed to be safe to rerun.
- Existing users, databases, directories, and services are reused.
- `.env` files are created once and updated in-place.
