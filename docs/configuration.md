# Configuration Reference

This document lists every environment variable used by each component.

---

## PHP Application (`php-app/.env`)

| Variable | Example | Description |
|----------|---------|-------------|
| `APP_NAME` | `MXA Transcription` | Display name in the UI |
| `APP_ENV` | `production` | `production` or `development` |
| `APP_URL` | `http://192.168.1.66` | Base URL of the PHP app (no trailing slash) |
| `APP_DEBUG` | `false` | Set `true` to show PHP errors in browser (dev only) |
| `SESSION_NAME` | `mxa_session` | Cookie name for the PHP session |
| `SESSION_LIFETIME` | `7200` | Session expiry in seconds (7200 = 2 hours) |
| `SESSION_SECRET` | `<random>` | Random string used for session HMAC |
| `SESSION_SECURE_COOKIE` | `true` | Set to `true` in production so cookies are HTTPS-only |
| `SESSION_SAME_SITE` | `Lax` | Session cookie SameSite policy (`Lax`, `Strict`, `None`) |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `transcription_db` | Database name |
| `DB_USER` | `transcription_user` | Database username |
| `DB_PASS` | `secret` | Database password |
| `KEYCLOAK_BASE_URL` | `http://192.168.1.59:8080` | Keycloak server URL |
| `KEYCLOAK_REALM` | `myrealm` | Keycloak realm name |
| `KEYCLOAK_CLIENT_ID` | `transcription-web` | OIDC client ID in Keycloak |
| `KEYCLOAK_CLIENT_SECRET` | `secret` | OIDC client secret from Keycloak |
| `KEYCLOAK_REDIRECT_URI` | `http://192.168.1.66/auth/callback` | Must match Keycloak config |
| `KEYCLOAK_VERIFY_TLS` | `true` | Verify Keycloak TLS certificates in production |
| `PYTHON_API_BASE_URL` | `http://192.168.1.90:8000` | Python API base URL |
| `PYTHON_API_KEY` | `<random>` | Shared secret for PHP→Python auth |
| `MINIO_ENDPOINT` | `192.168.1.90:9000` | MinIO host:port |
| `MINIO_ACCESS_KEY` | `minioadmin` | MinIO access key |
| `MINIO_SECRET_KEY` | `minioadmin` | MinIO secret key |
| `MINIO_SECURE` | `false` | Set `true` if MinIO uses HTTPS |
| `MINIO_AUDIO_BUCKET` | `audio-uploads` | Bucket for uploaded audio files |
| `MINIO_RESULTS_BUCKET` | `transcription-results` | Bucket for transcript outputs |
| `MINIO_EXPORTS_BUCKET` | `exports` | Bucket for downloadable archives |

---

## Python Backend (`python-backend/.env`)

| Variable | Example | Description |
|----------|---------|-------------|
| `APP_NAME` | `MXA Transcription API` | API name (shown in logs) |
| `APP_VERSION` | `1.0.0` | API version |
| `DEBUG` | `false` | Enables Swagger UI at /docs when true |
| `LOG_LEVEL` | `INFO` | Logging level: DEBUG, INFO, WARNING, ERROR |
| `API_SECRET_KEY` | `<random>` | Must match `PYTHON_API_KEY` in PHP |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `MINIO_ENDPOINT` | `localhost:9000` | MinIO host:port (from Python server's perspective) |
| `MINIO_ACCESS_KEY` | `minioadmin` | MinIO access key |
| `MINIO_SECRET_KEY` | `minioadmin` | MinIO secret key |
| `MINIO_SECURE` | `false` | HTTPS for MinIO |
| `MINIO_AUDIO_BUCKET` | `audio-uploads` | Bucket for audio files |
| `MINIO_RESULTS_BUCKET` | `transcription-results` | Bucket for results |
| `MINIO_EXPORTS_BUCKET` | `exports` | Bucket for exports |
| `POSTGRES_DSN` | `postgresql://user:pass@192.168.1.66:5432/db` | Database connection string |
| `HUGGINGFACE_TOKEN` | `hf_xxx` | Token for pyannote speaker diarization |
| `DEFAULT_MODEL_SIZE` | `base` | Default Whisper model (tiny/base/small/medium/large-v3) |
| `DEFAULT_DEVICE` | `auto` | Inference device: auto/cpu/cuda |
| `MAX_UPLOAD_BYTES` | `524288000` | 500 MB maximum file size |
| `CORS_ALLOW_ORIGINS` | `http://192.168.1.66` | Comma-separated allowed browser origins for API CORS |

---

## How to generate a secure random key

```bash
# Python
python -c "import secrets; print(secrets.token_hex(32))"

# PHP
php -r "echo bin2hex(random_bytes(32));"
```

---

## Notes

- The `API_SECRET_KEY` (Python) and `PYTHON_API_KEY` (PHP) **must be identical**.
- Never put real values in `.env.example` – it is committed to version control.
- The real `.env` files should have `chmod 640` and be owned by the web user.
