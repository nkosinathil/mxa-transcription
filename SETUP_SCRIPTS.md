# Setup Scripts Guide

This repository provides 3 automated setup scripts for the 3-server architecture. Each script is designed to run on its respective server with interactive prompts for configuration.

## Overview

| Script | Server | IP | Components |
|--------|--------|----|-----------| 
| `setup-app-server.sh` | App Server | 192.168.1.66 | PHP, Apache, PostgreSQL |
| `setup-python-server.sh` | Python Server | 192.168.1.90 | Python, FastAPI, Celery, Redis, MinIO |
| `setup-sso-server.sh` | SSO Server | 192.168.1.59 | Keycloak, PostgreSQL |

## Prerequisites

- Ubuntu/Debian-based Linux on all servers
- Root access (scripts must be run with `sudo`)
- Network connectivity between servers
- Repository cloned on each server

## Setup Order

Run the scripts in this order for optimal setup:

### 1. SSO Server (192.168.1.59)

```bash
sudo ./setup-sso-server.sh
```

**What it does:**
- Installs Java and PostgreSQL
- Downloads and configures Keycloak
- Creates systemd service for Keycloak
- Provides instructions for realm/client configuration

**Prompts for:**
- Keycloak version
- Admin username and password
- Database credentials
- Realm name and client ID

**After completion:**
- Complete realm and client setup via web console
- Copy client secret for next step

### 2. App Server (192.168.1.66)

```bash
sudo ./setup-app-server.sh
```

**What it does:**
- Installs PHP 8.1+, Apache, PostgreSQL
- Configures database and runs migrations
- Creates `.env` file with your settings
- Installs Composer dependencies
- Configures Apache virtual host
- Generates API key for Python server

**Prompts for:**
- Database name, user, and password
- Keycloak server URL, realm, client ID, and secret
- Python API server URL
- MinIO endpoint and credentials

**Important:**
- Saves API key to `/tmp/mxa_api_key.txt`
- You must copy this file to Python server before running its setup

**Copy API key to Python server:**
```bash
scp /tmp/mxa_api_key.txt user@192.168.1.90:/tmp/
```

### 3. Python Server (192.168.1.90)

```bash
sudo ./setup-python-server.sh
```

**What it does:**
- Installs Python 3.11+, FFmpeg, Redis
- Downloads and configures MinIO
- Creates virtual environment and installs dependencies
- Creates `.env` file with your settings
- Sets up systemd services for FastAPI and Celery
- Creates MinIO storage buckets

**Prompts for:**
- API key (auto-detected from `/tmp/mxa_api_key.txt` if present)
- Redis URL
- PostgreSQL connection details (from App Server)
- MinIO credentials
- HuggingFace token (optional, for speaker diarization)

**Services created:**
- `mxa-api.service` - FastAPI application
- `mxa-celery.service` - Celery worker
- `minio.service` - MinIO object storage

## Interactive Features

All scripts include:

✅ **Interactive prompts** - Ask for configuration values at runtime
✅ **Password confirmation** - Critical passwords require confirmation
✅ **Default values** - Sensible defaults for most settings
✅ **Password hiding** - Passwords are hidden during input
✅ **Validation** - Checks for required values
✅ **Color output** - Easy-to-read status messages
✅ **Error handling** - Stops on errors, safe to re-run

## Example Usage

### App Server Setup

```
$ sudo ./setup-app-server.sh

=========================================================================
MXA Transcription - App Server Setup
Server: 192.168.1.66 (PHP/Apache/PostgreSQL)
=========================================================================

Configuration

PostgreSQL database name [transcription_db]: 
PostgreSQL database user [transcription_user]: 
PostgreSQL database password: ****
Confirm password: ****
Keycloak server URL [http://192.168.1.59:8080]: 
Keycloak realm name: mxa-realm
Keycloak client ID [transcription-web]: 
Keycloak client secret: ****
Python API server URL [http://192.168.1.90:8000]: 
MinIO endpoint [192.168.1.90:9000]: 
MinIO access key [minioadmin]: 
MinIO secret key [minioadmin]: ****

Step 1: Installing system packages...
  ✓ PHP and Apache installed
  ✓ PostgreSQL installed
  ✓ Composer installed
...
```

## Post-Setup Tasks

### After App Server Setup
1. Verify Apache is running: `systemctl status apache2`
2. Test PHP application: `http://192.168.1.66`
3. Check logs if needed: `tail -f /var/log/apache2/mxa-error.log`

### After Python Server Setup
1. Check service status:
   ```bash
   sudo systemctl status mxa-api
   sudo systemctl status mxa-celery
   sudo systemctl status minio
   ```
2. Test API: `http://192.168.1.90:8000/docs`
3. Access MinIO Console: `http://192.168.1.90:9001`
4. View logs:
   ```bash
   sudo journalctl -u mxa-api -f
   sudo journalctl -u mxa-celery -f
   ```

### After SSO Server Setup
1. Access Keycloak Admin Console: `http://192.168.1.59:8080/admin`
2. Complete realm and client configuration (see script output)
3. Create test users
4. Assign roles: admin, analyst, viewer

## Troubleshooting

### Script fails with "permission denied"
Make sure to run with `sudo`:
```bash
sudo ./setup-app-server.sh
```

### API key file not found on Python server
Copy from App server:
```bash
scp /tmp/mxa_api_key.txt user@192.168.1.90:/tmp/
```

### Service won't start
Check logs:
```bash
sudo journalctl -u <service-name> -n 50
```

### Want to re-run setup
Scripts are designed to be idempotent (safe to re-run). Existing configurations will be preserved where possible, with warnings shown.

## Security Notes

⚠️ **Important:**
- Scripts save passwords to `.env` files - ensure proper file permissions
- Change default MinIO credentials (minioadmin/minioadmin)
- API key file at `/tmp/mxa_api_key.txt` should be deleted after Python setup
- Use HTTPS in production (update URLs in `.env` files)
- Keycloak admin password is stored only in environment variable during service startup

## Need Help?

- See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for manual deployment steps
- See [docs/deployment.md](docs/deployment.md) for detailed documentation
- Run validation: `python validate-deployment.py`

## Legacy Setup Script

The original `setup.sh` script is still available but creates configuration for a single-server setup. Use the server-specific scripts instead for the 3-server architecture.
