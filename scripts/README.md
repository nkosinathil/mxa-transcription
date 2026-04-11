# Deployment Scripts

This folder contains server-focused deployment scripts for the web architecture.

## Structure

- `deploy/setup-app-server.sh` - App server setup (PHP/Apache/PostgreSQL)
- `deploy/setup-python-server.sh` - Python server setup (FastAPI/Celery/Redis/MinIO)
- `deploy/setup-sso-server.sh` - SSO server setup (Keycloak)
- `deploy/setup-all.sh` - wrapper entrypoint
- `lib/common.sh` - shared shell helpers

## Usage

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
