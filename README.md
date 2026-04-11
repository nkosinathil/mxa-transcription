# MXA Transcription

A distributed web application for automatic audio transcription with speaker diarization, built on three servers.

---

## Architecture

| Server | IP | Role |
|---|---|---|
| PHP Frontend | 192.168.1.66 | Apache + PHP 8.1 + PostgreSQL |
| Python Backend | 192.168.1.90 | FastAPI + Celery + Redis + MinIO |
| Keycloak SSO | 192.168.1.59 | Authentication (OIDC) |

See [docs/architecture.md](docs/architecture.md) for the full design document.

---

## Features

- Folder-based or web-based audio file upload
- Supports: `.wav`, `.mp3`, `.m4a`, `.aac`, `.flac`, `.ogg`, `.opus`, `.wma`
- Language detection via Faster-Whisper (English and Afrikaans supported)
- Speaker diarization with `pyannote.audio`
- Speaker-labelled transcript (JSON + plain text)
- Keycloak SSO — role-based access control (`user`, `operator`, `admin`)
- Async processing via Celery with live status polling
- Object storage via MinIO

---

## Quick Start (Development)

```bash
# 1. Clone the repository
git clone https://github.com/nkosinathil/mxa-transcription.git
cd mxa-transcription

# 2. Copy and configure .env files
bash setup.sh

# 3. Edit the .env files (see prompts from setup.sh)
nano php-app/.env
nano python-backend/.env

# 4. Validate configuration before deploying
python3 validate-deployment.py --role all
```

---

## Deployment

### Production shell deployment framework

This repository includes a production-oriented shell deployment framework under **[`deploy/`](deploy/README.md)** with:
- `deploy/scripts/` orchestration and layered setup scripts
- `deploy/systemd/` service unit templates for FastAPI, Celery, MinIO, and Keycloak
- `deploy/apache/` Apache virtual host template
- `deploy/env/deploy.env.example` for deployment-time variables

Typical usage on the target hosts:

```bash
cp deploy/env/deploy.env.example deploy/env/deploy.env
nano deploy/env/deploy.env

# Keycloak server first (192.168.1.59)
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh keycloak

# Python backend (192.168.1.90)
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh backend

# PHP frontend (192.168.1.66)
sudo DEPLOY_ENV_FILE=$PWD/deploy/env/deploy.env ./deploy/scripts/deploy-master.sh frontend
```

Legacy wrappers remain available:
- `deploy/keycloak-server/deploy.sh`
- `deploy/python-server/deploy.sh`
- `deploy/php-server/deploy.sh`

Then follow every step in **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** and the detailed operator guide in **[`deploy/README.md`](deploy/README.md)**.

---

## Repository Layout

```
├── audio_pipeline/          # Core transcription library (Whisper + Pyannote)
│   ├── pipeline.py          # AudioPipeline orchestrator
│   ├── transcription.py     # Faster-Whisper wrapper
│   ├── diarization.py       # Pyannote speaker diarization
│   ├── reporting.py         # HTML dashboard generator
│   └── ...
│
├── php-app/                 # PHP frontend (Server 1)
│   ├── public/              # Apache document root
│   │   ├── index.php        # Application entry point / router
│   │   └── .htaccess        # URL rewriting rules
│   ├── src/
│   │   ├── Controllers/     # AuthController, UploadController, JobController
│   │   ├── Services/        # AuthService, ApiClient, CsrfService, Database
│   │   └── Views/           # dashboard.php, upload.php, jobs.php, job.php
│   ├── config/config.php    # Application configuration
│   ├── .env.example         # Environment variable template
│   └── storage/logs/        # Application logs
│
├── python-backend/          # FastAPI + Celery backend (Server 2)
│   ├── app/
│   │   ├── main.py          # FastAPI application
│   │   ├── api/endpoints/   # upload.py, jobs.py, transcripts.py
│   │   ├── core/
│   │   │   ├── config.py    # Pydantic settings
│   │   │   ├── dependencies.py  # X-Api-Key auth
│   │   │   └── storage.py   # MinIO wrapper
│   │   └── tasks/
│   │       ├── celery_app.py        # Celery configuration
│   │       └── transcription_tasks.py  # Main Celery task
│   ├── requirements.txt
│   └── .env.example
│
├── database/
│   ├── migrations/001_initial_schema.sql   # PostgreSQL schema
│   └── seeds/001_users.sql
│
├── deploy/
│   ├── php-server/deploy.sh
│   ├── python-server/deploy.sh
│   └── keycloak-server/deploy.sh
│
├── docs/
│   └── architecture.md
│
├── DEPLOYMENT_CHECKLIST.md  # Step-by-step deployment guide
├── setup.sh                 # Initial .env setup helper
├── validate-deployment.py   # Pre-deployment health checks
│
├── run_audio_pipeline.py    # CLI version of the desktop tool
└── run_audio_qt.py          # Qt desktop GUI launcher
```

---

## Desktop CLI (original tool)

The original command-line pipeline is still available:

```bash
pip install -r requirements.txt
python run_audio_pipeline.py --input "path/to/audio" --output "path/to/output"
```

## Optional diarization token

For speaker diarization, set:

```bash
export HUGGINGFACE_TOKEN=your_token_here
```

Without a token the app will transcribe but label all speech as `Speaker 1`.

