# MXA Transcription – Web Application

A browser-based audio transcription and speaker diarization platform built on a
three-server architecture.  Converts spoken audio to text with automatic speaker
identification, accessible to multiple users through any web browser.

> **Migration note:** This repository was originally a Qt desktop application.
> The web application code lives in `php-app/`, `python-backend/`, `database/`,
> `docs/`, and `deploy/`.  The original Qt code is preserved in the root for
> reference. See [docs/migration-from-qt.md](docs/migration-from-qt.md).

---

## Architecture

```
Browser → Apache/PHP (192.168.1.66) → FastAPI/Celery/Python (192.168.1.90)
                  ↕                              ↕
         PostgreSQL (App Server)        MinIO + Redis (Python Server)
                  ↑
         Keycloak SSO (192.168.1.59)
```

| Server | IP | Role |
|--------|----|------|
| SSO | 192.168.1.59 | Keycloak authentication |
| Application | 192.168.1.66 | PHP web UI + PostgreSQL |
| Processing | 192.168.1.90 | Python API + Celery workers + MinIO |

---

## Features

- **Keycloak OIDC login** – no passwords stored in the application
- **Role-based access** – Admin / Analyst / Viewer roles
- **Case management** – organise audio files into workspaces
- **File upload** – drag-and-drop or click to upload audio files
- **Background processing** – Celery workers process files without blocking the UI
- **Live progress tracking** – real-time event log and progress bar
- **Speaker diarization** – identifies who spoke when using pyannote.audio
- **Multi-language support** – English and Afrikaans (Faster-Whisper)
- **Downloadable transcripts** – download plain text transcripts
- **Audit logging** – every action recorded for security compliance

---

## Repository Structure

```
├── php-app/            PHP web frontend (MVC)
├── python-backend/     FastAPI + Celery processing backend
├── database/           PostgreSQL migrations and schema
├── docs/               Documentation
├── deploy/             Apache vhost, systemd services, nginx config
├── audio_pipeline/     Original Qt audio pipeline (preserved, reused in web app)
└── README.md
```

---

## Deployment Status

✅ **Code is ready for deployment** with proper environment configuration.

### Pre-Deployment Requirements

1. **Validate deployment readiness:**
   ```bash
   python validate-deployment.py
   ```

2. **Review the complete checklist:**
   See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for a comprehensive list of tasks.

3. **Key requirements before deployment:**
   - Create and configure `.env` files (copy from `.env.example`)
   - Generate strong secrets for `SESSION_SECRET` and `API_SECRET_KEY`
   - Set up external services (Keycloak, PostgreSQL, Redis, MinIO)
   - Run database migrations
   - Install dependencies (`composer install`, `pip install -r requirements.txt`)
   - Configure HTTPS for production
   - Change all default passwords

---

## Quick Start

See the full deployment guide: [docs/deployment.md](docs/deployment.md)

```bash
# 1. Set up PostgreSQL (App Server)
psql -U transcription_user -d transcription_db -f database/schema.sql

# 2. Configure PHP app
cp php-app/.env.example php-app/.env
# Edit php-app/.env with your settings

# 3. Install PHP dependencies
cd php-app && composer install --no-dev

# 4. Configure Python backend
cp python-backend/.env.example python-backend/.env
# Edit python-backend/.env with your settings

# 5. Install Python dependencies
cd python-backend && pip install -r requirements.txt

# 6. Start services (Python server)
uvicorn app.main:app --host 0.0.0.0 --port 8000
celery -A app.core.celery_app worker --loglevel=info
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design and data flow |
| [Deployment](docs/deployment.md) | Step-by-step deployment guide |
| [Configuration](docs/configuration.md) | All environment variables |
| [Database](docs/database.md) | Schema reference |
| [API](docs/api.md) | Python API endpoints |
| [Authentication](docs/authentication.md) | Keycloak OIDC login flow |
| [Maintenance](docs/maintenance.md) | Day-to-day operations |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and fixes |
| [Migration from Qt](docs/migration-from-qt.md) | What changed from the desktop app |

---

## Security Notes

- Secrets are stored in `.env` files, never in source code
- All user input is validated and sanitised
- CSRF protection available via `CsrfService::generate()` and `CsrfService::validate()`
- Role checks on all protected routes
- Audit log for all important actions
- `HttpOnly` session cookies
- **Production requirement:** Enable HTTPS and update all URLs in `.env` files

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Web frontend | PHP 8.1 (no framework) |
| Web server | Apache 2.4 + PHP-FPM |
| Database | PostgreSQL 15 |
| API backend | Python 3.11, FastAPI |
| Task queue | Celery 5 |
| Broker | Redis |
| Object storage | MinIO |
| Authentication | Keycloak OIDC |
| Transcription | Faster-Whisper |
| Diarization | pyannote.audio |

---

## Original Desktop Application

The original Qt desktop app is still runnable for reference:

```bash
pip install -r requirements.txt
python run_audio_qt.py
```

Or use the CLI:
```bash
python run_audio_pipeline.py --input "/input_folder" --output "/output_folder"
```
