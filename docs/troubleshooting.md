# Troubleshooting Guide

## Login Issues

### "OAuth state mismatch – possible CSRF attack"
**Cause:** User's session expired between clicking "Login" and returning from Keycloak,
or the session cookie was lost.  
**Fix:** Clear browser cookies and try again. Ensure `SESSION_SECRET` is set in `.env`.

### Blank page or redirect loop after Keycloak login
**Cause:** `KEYCLOAK_REDIRECT_URI` in PHP `.env` does not match what is configured
in Keycloak's Valid Redirect URIs.  
**Fix:** Make both values identical.

### "Login failed – token exchange failed"
**Cause:** `KEYCLOAK_CLIENT_SECRET` is wrong, or Keycloak is unreachable from the
App server.  
**Fix:**
```bash
# Test connectivity from App server
curl http://192.168.1.59:8080/realms/your-realm/.well-known/openid-configuration
```

---

## Upload Issues

### "File upload to storage failed"
**Cause:** PHP cannot reach the Python API.  
**Fix:**
```bash
# From App server (192.168.1.66):
curl http://192.168.1.90:8000/api/health
```
If this fails, check that `transcription-api` is running on the Python server.

### "File type not allowed"
**Cause:** The uploaded file extension is not in the allowed list.  
**Fix:** Check supported formats: `.wav .mp3 .m4a .aac .flac .ogg .opus .wma`

---

## Processing Issues

### Job stuck in "queued" forever
**Cause:** Celery worker is not running.  
**Fix:**
```bash
sudo systemctl status transcription-worker
sudo systemctl start transcription-worker
```

### Job fails with "FFmpeg not found"
**Cause:** FFmpeg is not installed on the Python server.  
**Fix:**
```bash
sudo apt-get install -y ffmpeg
```

### Job fails with "CUDA out of memory"
**Cause:** GPU has insufficient memory for the selected Whisper model.  
**Fix:** Choose a smaller model (e.g. `base` instead of `large-v3`),
or set `DEFAULT_DEVICE=cpu` in `python-backend/.env`.

### "missing_huggingface_token" in job events
**Cause:** `HUGGINGFACE_TOKEN` is not set in `python-backend/.env`.  
**Fix:** Add your HuggingFace token. Speaker diarization will be disabled
until this is configured – transcription still works.

---

## Database Issues

### "Database connection failed"
**Cause:** Wrong credentials in `php-app/.env` or PostgreSQL is not running.  
**Fix:**
```bash
# Check PostgreSQL
sudo systemctl status postgresql

# Test connection
psql -U transcription_user -d transcription_db -h localhost -c "SELECT 1"
```

---

## MinIO Issues

### "Bucket does not exist"
**Cause:** MinIO is running but buckets haven't been created.  
**Fix:** The Python `MinioService` creates buckets automatically on startup.
Restart `transcription-api`.

### Results not showing up
**Cause:** Python server's MinIO endpoint differs from what the PHP app expects.  
**Fix:** Ensure both `.env` files use the correct `MINIO_ENDPOINT`.
The Python server should use `localhost:9000`; the PHP server should use
`192.168.1.90:9000`.

---

## Log Locations

| Log | Path |
|-----|------|
| PHP errors | `/var/www/gismartanalytics/storage/logs/php_errors.log` |
| Apache errors | `/var/log/apache2/transcription_error.log` |
| Python API | `journalctl -u transcription-api` |
| Celery worker | `/var/log/mxa-transcription/celery.log` |
| PostgreSQL | `/var/log/postgresql/postgresql-*.log` |
