# Maintenance Guide

## Daily Operations

### Checking Service Health

```bash
# On Python server (192.168.1.90)
sudo systemctl status transcription-api
sudo systemctl status transcription-worker

# Quick health check
curl http://192.168.1.90:8000/api/health
```

### Viewing Logs

```bash
# Python API logs
sudo journalctl -u transcription-api -n 100 --no-pager

# Celery worker logs
tail -100 /var/log/mxa-transcription/celery.log

# Apache logs (App server)
tail -100 /var/log/apache2/transcription_error.log
tail -100 /var/log/apache2/transcription_access.log

# PHP application logs
tail -100 /var/www/gismartanalytics/storage/logs/php_errors.log
```

---

## Routine Tasks

### Clear old job events (keep last 90 days)

```sql
-- Run on PostgreSQL (App server)
DELETE FROM job_events
WHERE created_at < NOW() - INTERVAL '90 days';
```

### Check disk usage on MinIO

```bash
# On Python server
du -sh /data/minio
```

### Restart services after updates

```bash
# Python API
sudo systemctl restart transcription-api

# Celery worker (waits for current task to finish)
sudo systemctl restart transcription-worker

# Apache
sudo systemctl reload apache2
```

---

## Updating Models

The Whisper model files are downloaded automatically by `faster-whisper` on first use.
They are stored in `~/.cache/huggingface/` (for the `transcription` user).

To use a different model by default, change `DEFAULT_MODEL_SIZE` in
`python-backend/.env`. Available sizes: `tiny`, `base`, `small`, `medium`, `large-v3`.

---

## Backup

### PostgreSQL

```bash
# Daily backup (run as postgres user or with correct credentials)
pg_dump -U transcription_user transcription_db \
  | gzip > /backups/transcription_db_$(date +%Y%m%d).sql.gz
```

### MinIO

MinIO supports `mc mirror` for replication:
```bash
mc mirror minio/audio-uploads     /backups/minio/audio-uploads/
mc mirror minio/transcription-results /backups/minio/transcription-results/
```

---

## Adding a New Processing Option

To add a new Whisper model size or device option:

1. Update `app_settings` in PostgreSQL:
   ```sql
   UPDATE app_settings SET value = 'tiny,base,small,medium,large-v3,large-v3-turbo'
   WHERE key = 'default_model';
   ```

2. The PHP upload form passes whatever model the user selects.
3. The Celery task accepts any value that `faster-whisper` supports.

---

## Scaling

### More Celery workers

If you need to process more files simultaneously:

```bash
# Increase concurrency on the same server
sudo systemctl edit transcription-worker
# Change --concurrency=2 to --concurrency=4
sudo systemctl restart transcription-worker
```

Or start a second worker service by copying and editing
`transcription-worker.service`.

Note: Each worker that loads a large Whisper model uses ~2–4 GB RAM.
Monitor with `htop` before increasing concurrency.
