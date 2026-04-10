# MXA Transcription — Deployment Checklist

Work through each section in order. Tick items off as you complete them.

---

## 0. Prerequisites

- [ ] All three servers are provisioned and accessible on the 192.168.1.0/24 network
- [ ] You have `sudo`/root access on all three servers
- [ ] DNS or `/etc/hosts` entries are in place if hostnames are used
- [ ] Git is installed on the deployment workstation

---

## 1. Keycloak Server (192.168.1.59)

Run on **192.168.1.59**:

```bash
sudo bash deploy/keycloak-server/deploy.sh
```

Then complete the manual steps in the Keycloak Admin Console (`http://192.168.1.59:8080`):

- [ ] Change the default `admin` password
- [ ] Create realm: `mxa-transcription`
- [ ] Create client `mxa-transcription-client`
  - [ ] Protocol: `openid-connect`
  - [ ] Access type: `confidential`
  - [ ] Valid redirect URIs: `http://192.168.1.66/*`
  - [ ] Web origins: `http://192.168.1.66`
- [ ] Note down the **Client Secret** from the *Credentials* tab
- [ ] Create roles: `user`, `admin`, `operator`
- [ ] Create at least one admin user and assign the `admin` role
- [ ] Create at least one regular user and assign the `user` role

---

## 2. Python Backend Server (192.168.1.90)

Run on **192.168.1.90**:

```bash
sudo bash deploy/python-server/deploy.sh
```

Then configure the environment file:

```bash
sudo nano /opt/mxa-transcription/python-backend/.env
```

- [ ] Set `API_SECRET_KEY` to a long random string (≥ 32 chars)
- [ ] Set `DATABASE_URL` with the real PostgreSQL password
- [ ] Set `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` (change from defaults)
- [ ] Set `HUGGINGFACE_TOKEN` (required for speaker diarization)
- [ ] Set `WHISPER_MODEL_SIZE` to `base`, `small`, `medium`, or `large-v3`
- [ ] Set `WHISPER_DEVICE` to `cuda` if an NVIDIA GPU is present

Restart services after editing `.env`:

```bash
sudo systemctl restart mxa-api mxa-celery
```

Verification:

- [ ] `curl http://192.168.1.90:8000/health` returns `{"status":"healthy",...}`
- [ ] MinIO console accessible at `http://192.168.1.90:9001`
- [ ] Change MinIO root credentials in the console → *Administrator → Users*

---

## 3. PHP Frontend Server (192.168.1.66)

Run on **192.168.1.66**:

```bash
sudo bash deploy/php-server/deploy.sh
```

Then configure the environment file:

```bash
sudo nano /var/www/html/mxa-transcription/php-app/.env
```

- [ ] Set `DB_PASSWORD` to the PostgreSQL password created in step 3
- [ ] Set `API_SECRET_KEY` — **must match** the value set on Server 2
- [ ] Set `KEYCLOAK_CLIENT_SECRET` from the Keycloak console (step 1)
- [ ] Confirm `KEYCLOAK_SERVER_URL`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID`

Import the database schema:

```bash
sudo -u postgres psql -d mxa_transcription \
  -f /var/www/html/mxa-transcription/database/migrations/001_initial_schema.sql
```

Restart Apache:

```bash
sudo systemctl restart apache2
```

Verification:

- [ ] `http://192.168.1.66` redirects to Keycloak login
- [ ] Login with a test user succeeds and lands on the Dashboard
- [ ] Upload a short audio file and confirm a job is created
- [ ] Job status page shows `queued` or `processing`
- [ ] Job completes and transcript is visible

---

## 4. End-to-End Test

- [ ] Upload a short English audio clip (< 1 min)
- [ ] Confirm language is detected as `en`
- [ ] Confirm transcript text is correct
- [ ] Upload a short Afrikaans audio clip
- [ ] Confirm language is detected as `af`
- [ ] Upload an unsupported language clip — confirm job is marked `skipped_language`
- [ ] Upload a file > 500 MB — confirm it is rejected with an error message
- [ ] Log out and confirm session is cleared
- [ ] Attempt to access `/jobs` without logging in — confirm redirect to Keycloak

---

## 5. Security Hardening (production)

- [ ] Enable HTTPS on Apache (Let's Encrypt or internal CA)
- [ ] Set `secure = true` in `php-app/.env` session settings
- [ ] Uncomment HTTPS redirect in `php-app/public/.htaccess`
- [ ] Set `MINIO_SECURE=True` in python-backend `.env`
- [ ] Update all `http://` URLs to `https://` in both `.env` files
- [ ] Restrict firewall: only port 80/443 publicly; 8000, 9000/9001 internal only
- [ ] Change all default passwords (MinIO, PostgreSQL, Keycloak admin)
- [ ] Enable PostgreSQL SSL

---

## 6. Ongoing Operations

- [ ] Configure log rotation (`/etc/logrotate.d/mxa-transcription`)
- [ ] Set up regular PostgreSQL backups (`pg_dump`)
- [ ] Set up MinIO bucket versioning or off-site sync
- [ ] Monitor services:
  - `systemctl status mxa-api mxa-celery minio redis-server apache2 postgresql`

---

## Quick Reference

| Component | Server | Port | Command |
|-----------|--------|------|---------|
| PHP App | 192.168.1.66 | 80 | `systemctl restart apache2` |
| PostgreSQL | 192.168.1.66 | 5432 | `systemctl restart postgresql` |
| FastAPI | 192.168.1.90 | 8000 | `systemctl restart mxa-api` |
| Celery | 192.168.1.90 | — | `systemctl restart mxa-celery` |
| Redis | 192.168.1.90 | 6379 | `systemctl restart redis-server` |
| MinIO | 192.168.1.90 | 9000/9001 | `systemctl restart minio` |
| Keycloak | 192.168.1.59 | 8080 | `systemctl restart keycloak` |
