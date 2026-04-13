# Database Schema Reference

## Overview

PostgreSQL database: `transcription_db`  
Server: 192.168.1.66 (App Server)

---

## Tables

### `users`
Maps Keycloak identities to local application users.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | Auto-incremented integer |
| keycloak_id | VARCHAR(255) UNIQUE | The `sub` claim from the Keycloak JWT |
| email | VARCHAR(320) UNIQUE | User's email address |
| name | VARCHAR(255) | Display name |
| role | VARCHAR(50) | `admin`, `analyst`, or `viewer` |
| is_active | BOOLEAN | Soft-disable users without deleting |
| created_at | TIMESTAMPTZ | First login timestamp |
| last_login | TIMESTAMPTZ | Updated on every login |

---

### `cases`
A workspace that groups uploads and jobs.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| user_id | INTEGER FK → users | Case owner |
| name | VARCHAR(255) | Human-readable case name |
| description | TEXT | Optional longer description |
| status | VARCHAR(50) | `open`, `closed`, `archived` |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | Updated when status changes |

---

### `uploads`
Audio files stored in MinIO.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| case_id | INTEGER FK → cases | Which case this belongs to |
| user_id | INTEGER FK → users | Who uploaded it |
| filename | VARCHAR(512) | Original file name |
| minio_bucket | VARCHAR(255) | MinIO bucket name |
| minio_path | VARCHAR(1024) | Object key (path inside bucket) |
| size_bytes | BIGINT | File size |
| sha256 | CHAR(64) | SHA-256 hash for deduplication |
| mime_type | VARCHAR(128) | e.g. `audio/mpeg` |
| upload_status | VARCHAR(50) | `pending`, `stored`, `failed` |
| uploaded_at | TIMESTAMPTZ | |

---

### `processing_jobs`
One job per upload/transcription attempt.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| upload_id | INTEGER FK → uploads | Which audio file |
| case_id | INTEGER FK → cases | |
| user_id | INTEGER FK → users | |
| celery_task_id | VARCHAR(255) | UUID returned by Celery |
| status | VARCHAR(50) | `queued` → `processing` → `completed`/`failed` |
| progress | SMALLINT | 0–100 percentage |
| model_size | VARCHAR(50) | Whisper model used |
| device | VARCHAR(50) | cpu/cuda/auto |
| compute_type | VARCHAR(50) | Optional Whisper compute type override |
| diarization | BOOLEAN | Whether speaker diarization was enabled |
| error_message | TEXT | Error detail if status='failed' |
| created_at | TIMESTAMPTZ | |
| started_at | TIMESTAMPTZ | When the Celery worker started |
| completed_at | TIMESTAMPTZ | When finished/failed |

---

### `job_events`
Log messages emitted during processing.

| Column | Type | Notes |
|--------|------|-------|
| id | BIGSERIAL PK | |
| job_id | INTEGER FK → processing_jobs | |
| event_type | VARCHAR(50) | `info`, `warning`, `error`, `progress` |
| message | TEXT | Log message |
| created_at | TIMESTAMPTZ | |

---

### `results`
Outcome of a completed job.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| job_id | INTEGER UNIQUE FK | One result per job |
| minio_transcript_path | VARCHAR(1024) | Path to `.txt` file in MinIO |
| minio_json_path | VARCHAR(1024) | Path to full `.json` result in MinIO |
| minio_html_path | VARCHAR(1024) | Path to `.html` transcript (optional) |
| language | VARCHAR(10) | Detected language code (`en`, `af`) |
| language_probability | NUMERIC(5,4) | Confidence 0–1 |
| duration_seconds | NUMERIC(10,2) | Audio duration |
| speaker_count | SMALLINT | Number of distinct speakers |
| segment_count | INTEGER | Number of transcript segments |
| diarization_available | BOOLEAN | Whether diarization ran |
| diarization_note | TEXT | Error note if diarization failed |
| created_at | TIMESTAMPTZ | |

---

### `exports`
Downloadable ZIP/CSV archives.

| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| case_id | INTEGER FK → cases | |
| user_id | INTEGER FK → users | Who generated it |
| minio_bucket | VARCHAR(255) | |
| minio_path | VARCHAR(1024) | |
| filename | VARCHAR(512) | Download file name |
| export_type | VARCHAR(50) | `zip`, `csv`, `json`, `txt` |
| size_bytes | BIGINT | |
| created_at | TIMESTAMPTZ | |
| expires_at | TIMESTAMPTZ | Optional expiry |

---

### `audit_logs`
Immutable security audit trail.

| Column | Type | Notes |
|--------|------|-------|
| id | BIGSERIAL PK | |
| user_id | INTEGER FK → users (nullable) | Null for pre-login events |
| action | VARCHAR(100) | e.g. `login`, `upload`, `process`, `download` |
| resource_type | VARCHAR(100) | e.g. `case`, `job`, `upload` |
| resource_id | INTEGER | The affected row's ID |
| ip_address | INET | Client IP address |
| user_agent | TEXT | Browser user agent |
| extra | JSONB | Any additional context |
| created_at | TIMESTAMPTZ | |

---

### `app_settings`
Runtime configuration.

| Column | Type | Notes |
|--------|------|-------|
| key | VARCHAR(100) PK | Setting key |
| value | TEXT | Setting value |
| description | TEXT | Human-readable description |
| updated_at | TIMESTAMPTZ | |
