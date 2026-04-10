# MXA Transcription – Architecture

## Overview

This system converts audio files to text transcripts using AI (Faster-Whisper).
It is built as a three-server web application.

```
[Browser]  ←HTTPS→  [App Server 192.168.1.66]  ←HTTP→  [Python Server 192.168.1.90]
               ↑                    ↓                              ↓
         [Keycloak SSO      [PostgreSQL DB]              [Redis + MinIO + Celery]
          192.168.1.59]
```

---

## Server 1 – SSO Server (192.168.1.59)

**Software:** Keycloak

**What it does:**
- The central identity provider. All user logins go through here.
- Users enter their username/password on the Keycloak login screen.
- Keycloak issues a token (a signed piece of data) that proves who the user is.
- The PHP application reads this token to know the user's name, email, and role.

**You should not need to change anything on this server.** The realm and client
already exist. The only configuration needed in the PHP app is in `.env`:
- `KEYCLOAK_REALM`
- `KEYCLOAK_CLIENT_ID`
- `KEYCLOAK_CLIENT_SECRET`

---

## Server 2 – Application Server (192.168.1.66)

**Software:** Apache 2.4, PHP 8.1 (FPM), PostgreSQL 15

**What it does:**
- Serves the web interface that users interact with in their browser.
- Handles login sessions after Keycloak authentication.
- Stores all application metadata in PostgreSQL:
  - Which user belongs to which case
  - What files were uploaded
  - What jobs are running
  - Audit trail
- Forwards heavy processing requests to the Python server.
- Generates web pages showing results, progress, and downloads.

**Deployment path:** `/var/www/gismartanalytics/public`

---

## Server 3 – Python Server (192.168.1.90)

**Software:** Python 3.11, FastAPI, Celery, Redis, MinIO

**What it does:**
- Stores all uploaded audio files and generated transcripts in MinIO.
- Exposes a REST API that the PHP app calls to upload files and start jobs.
- When a transcription job is started, it queues it in Redis via Celery.
- Celery workers pick up queued jobs and run the transcription engine
  (Faster-Whisper for speech-to-text + pyannote.audio for speaker diarization).
- Reports job progress and results back to PostgreSQL (which PHP then reads).

**API base URL:** `http://192.168.1.90:8000`

---

## Data Flow

```
1. User clicks "Login"
   → Browser redirects to Keycloak (192.168.1.59)
   → User enters credentials
   → Keycloak redirects back to PHP /auth/callback with an authorization code
   → PHP exchanges code for tokens, creates a session

2. User creates a Case
   → PHP writes a row to PostgreSQL cases table

3. User uploads an audio file
   → Browser POSTs file to PHP
   → PHP forwards it to Python API /api/upload
   → Python stores it in MinIO (audio-uploads bucket)
   → Python returns minio_path and sha256
   → PHP writes a row to PostgreSQL uploads table

4. User clicks "Start Processing"
   → PHP calls Python API POST /api/process
   → Python queues a Celery task (returns celery_task_id)
   → PHP writes celery_task_id to processing_jobs table

5. Browser polls for progress (every 3 seconds)
   → Browser calls PHP GET /jobs/{id}/status
   → PHP calls Python API GET /api/job/{id}/status
   → Python reads job_events from PostgreSQL and returns them
   → Browser updates progress bar and event log

6. Celery worker processes the file
   → Downloads audio from MinIO
   → Runs Faster-Whisper transcription
   → Runs pyannote speaker diarization
   → Uploads transcript to MinIO (transcription-results bucket)
   → Writes result metadata to PostgreSQL results table
   → Updates processing_jobs.status = 'completed'

7. User views result
   → PHP reads result metadata from PostgreSQL
   → PHP retrieves transcript segments from MinIO JSON file
   → Renders transcript page with speaker labels and timestamps
```

---

## Technology Choices Explained

| Technology      | Why we use it |
|-----------------|---------------|
| PHP 8.1         | Already deployed on app server; suitable for web UI |
| FastAPI (Python)| Modern, fast REST API framework with async support |
| PostgreSQL      | Relational database already on app server |
| Redis           | Fast in-memory queue for Celery |
| Celery          | Distributed task queue; lets transcription run in background |
| MinIO           | S3-compatible object storage for large files |
| Keycloak        | Enterprise-grade SSO already in your infrastructure |
| Faster-Whisper  | Faster implementation of OpenAI's Whisper model |
| pyannote.audio  | Speaker diarization (who spoke when) |
