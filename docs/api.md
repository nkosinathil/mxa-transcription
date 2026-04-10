# Python API Reference

Base URL: `http://192.168.1.90:8000`

All endpoints (except `/api/health`) require the header:
```
X-Api-Key: <API_SECRET_KEY from .env>
```

---

## GET /api/health

**Purpose:** Check that the Python API is running.  
**Auth:** None required.

**Response:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2026-04-10T12:00:00Z"
}
```

---

## POST /api/upload

**Purpose:** Upload an audio file from PHP to MinIO.  
**Content-Type:** `multipart/form-data`

**Form fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | file | Yes | Audio file |
| `case_id` | integer | Yes | PostgreSQL case ID |

**Response (201):**
```json
{
  "minio_bucket": "audio-uploads",
  "minio_path": "case_42/abc123.mp3",
  "size_bytes": 5242880,
  "sha256": "abc...def",
  "original_filename": "interview.mp3"
}
```

**Errors:**
- `422` – Invalid file type or missing field
- `413` – File exceeds size limit
- `401` – Invalid API key

---

## POST /api/process

**Purpose:** Queue a Celery transcription job.  
**Content-Type:** `application/json`

**Request body:**
```json
{
  "job_id": 123,
  "minio_bucket": "audio-uploads",
  "minio_path": "case_42/abc123.mp3",
  "original_filename": "interview.mp3",
  "model_size": "base",
  "device": "auto",
  "compute_type": null,
  "diarization_enabled": true
}
```

**Response (202):**
```json
{
  "job_id": 123,
  "celery_task_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued"
}
```

---

## GET /api/job/{job_id}/status

**Purpose:** Poll job progress.

**Response:**
```json
{
  "job_id": 123,
  "celery_task_id": "550e...",
  "status": "processing",
  "progress": 60,
  "events": [
    {
      "event_type": "info",
      "message": "Downloading audio file from storage…",
      "created_at": "2026-04-10T12:01:00Z"
    },
    {
      "event_type": "info",
      "message": "Transcription complete. Language detected: en",
      "created_at": "2026-04-10T12:01:30Z"
    }
  ],
  "error_message": null
}
```

**Status values:** `queued`, `processing`, `completed`, `failed`, `cancelled`

---

## GET /api/job/{job_id}/result

**Purpose:** Retrieve the full transcript and metadata after a job completes.

**Response:**
```json
{
  "job_id": 123,
  "status": "completed",
  "language": "en",
  "language_probability": 0.9987,
  "duration_seconds": 182.4,
  "speaker_count": 2,
  "diarization_available": true,
  "diarization_note": null,
  "segments": [
    {
      "start": 0.0,
      "end": 4.2,
      "text": "Good morning, let's begin the interview.",
      "speaker": "Speaker 1"
    },
    {
      "start": 4.5,
      "end": 9.1,
      "text": "Thank you for having me.",
      "speaker": "Speaker 2"
    }
  ],
  "minio_transcript_path": "interview_mp3/123/transcript.txt",
  "minio_json_path": "interview_mp3/123/result.json",
  "minio_html_path": null,
  "created_at": "2026-04-10T12:03:00Z"
}
```

---

## Error Responses

All error responses follow this format:
```json
{
  "detail": "Human-readable error message"
}
```

Common HTTP status codes:
- `401` – Missing or invalid API key
- `404` – Job not found
- `422` – Validation error (wrong types, missing fields)
- `503` – Downstream service unavailable (Redis, MinIO)
