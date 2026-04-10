# Deployment Checklist

This checklist ensures all requirements are met before deploying the MXA Transcription web application to production.

## Pre-Deployment Validation

### 1. Directory Structure ✓
- [x] `php-app/storage/logs/` exists with write permissions
- [ ] Verify all directories have correct ownership (www-data for PHP, transcription user for Python)

### 2. Environment Configuration (CRITICAL)

#### PHP Application Server (192.168.1.66)
- [ ] Copy `php-app/.env.example` to `php-app/.env`
- [ ] Set `APP_ENV=production`
- [ ] Set `APP_DEBUG=false`
- [ ] Generate `SESSION_SECRET` using: `php -r "echo bin2hex(random_bytes(32));"`
- [ ] Configure `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`
- [ ] Set `KEYCLOAK_BASE_URL`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`
- [ ] Set `KEYCLOAK_REDIRECT_URI` (must match Keycloak configuration)
- [ ] Set `PYTHON_API_BASE_URL=http://192.168.1.90:8000`
- [ ] Generate `PYTHON_API_KEY` and ensure it matches Python backend
- [ ] Configure MinIO settings: `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`
- [ ] Change default MinIO credentials from minioadmin/minioadmin

#### Python Backend Server (192.168.1.90)
- [ ] Copy `python-backend/.env.example` to `python-backend/.env`
- [ ] Set `DEBUG=false`
- [ ] Set `LOG_LEVEL=INFO` or `WARNING`
- [ ] Generate `API_SECRET_KEY` using: `python -c "import secrets; print(secrets.token_hex(32))"`
- [ ] Ensure `API_SECRET_KEY` matches `PYTHON_API_KEY` in PHP .env
- [ ] Configure `REDIS_URL` (include password if Redis requires auth)
- [ ] Configure `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`
- [ ] Set `POSTGRES_DSN` to connect to App server database
- [ ] (Optional) Set `HUGGINGFACE_TOKEN` for speaker diarization
- [ ] Review `DEFAULT_MODEL_SIZE`, `DEFAULT_DEVICE`, `MAX_UPLOAD_BYTES`

### 3. External Services

#### Keycloak SSO (192.168.1.59)
- [ ] Keycloak server is running and accessible
- [ ] Realm created (note the realm name)
- [ ] Client created for the application
  - Client ID matches `KEYCLOAK_CLIENT_ID` in PHP .env
  - Client secret matches `KEYCLOAK_CLIENT_SECRET`
  - Valid Redirect URIs includes the callback URL
  - Access Type: confidential
- [ ] Roles configured: `admin`, `analyst`, `viewer`
- [ ] Test users created with appropriate roles

#### PostgreSQL (App Server)
- [ ] PostgreSQL 15+ installed
- [ ] Database created: `transcription_db`
- [ ] User created with appropriate permissions
- [ ] Migrations run successfully:
  ```bash
  psql -U transcription_user -d transcription_db -f database/schema.sql
  ```
- [ ] Verify all 9 tables created (users, cases, uploads, processing_jobs, job_events, results, exports, audit_logs, app_settings)
- [ ] Database accessible from Python server for Celery workers

#### Redis (Python Server)
- [ ] Redis server installed and running
- [ ] Redis accessible on localhost:6379 (or custom configuration)
- [ ] Password configured if required
- [ ] Test connection: `redis-cli ping`

#### MinIO (Python Server)
- [ ] MinIO server installed and running
- [ ] Accessible on configured endpoint (default: localhost:9000)
- [ ] Buckets created:
  - `audio-uploads`
  - `transcription-results`
  - `exports`
- [ ] Access credentials changed from defaults
- [ ] Test upload/download operations

### 4. Dependencies Installation

#### PHP Application
- [ ] PHP 8.1+ installed
- [ ] Required PHP extensions: pdo, pdo_pgsql, json, curl
- [ ] Composer installed
- [ ] Run: `cd php-app && composer install --no-dev --optimize-autoloader`
- [ ] Verify vendor/ directory created

#### Python Backend
- [ ] Python 3.11+ installed
- [ ] FFmpeg installed: `sudo apt-get install -y ffmpeg`
- [ ] Create virtual environment: `python3 -m venv .venv`
- [ ] Activate: `source .venv/bin/activate`
- [ ] Run: `pip install -r requirements.txt`
- [ ] Verify all packages installed without errors

### 5. System Services

#### Apache/PHP-FPM (App Server)
- [ ] Apache 2.4+ installed
- [ ] PHP 8.1-FPM installed and running
- [ ] Apache modules enabled: `rewrite`, `headers`, `proxy_fcgi`
- [ ] Virtual host configured:
  ```bash
  sudo cp deploy/apache/vhost.conf /etc/apache2/sites-available/transcription.conf
  sudo a2ensite transcription.conf
  sudo systemctl reload apache2
  ```
- [ ] DocumentRoot points to `/var/www/gismartanalytics/public`
- [ ] Test: Access http://192.168.1.66 in browser

#### Systemd Services (Python Server)
- [ ] Copy service files:
  ```bash
  sudo cp deploy/systemd/transcription-api.service /etc/systemd/system/
  sudo cp deploy/systemd/transcription-worker.service /etc/systemd/system/
  ```
- [ ] Update paths in service files if not using `/opt/mxa-transcription/`
- [ ] Reload systemd: `sudo systemctl daemon-reload`
- [ ] Enable services:
  ```bash
  sudo systemctl enable transcription-api
  sudo systemctl enable transcription-worker
  ```
- [ ] Start services:
  ```bash
  sudo systemctl start transcription-api
  sudo systemctl start transcription-worker
  ```
- [ ] Check status:
  ```bash
  sudo systemctl status transcription-api
  sudo systemctl status transcription-worker
  ```

### 6. File Permissions
- [ ] PHP application owned by www-data:
  ```bash
  sudo chown -R www-data:www-data /var/www/gismartanalytics
  sudo chmod -R 755 /var/www/gismartanalytics
  sudo chmod -R 775 /var/www/gismartanalytics/storage/logs
  ```
- [ ] Python backend owned by transcription user:
  ```bash
  sudo chown -R transcription:transcription /opt/mxa-transcription/python-backend
  ```
- [ ] .env files are readable only by service accounts (600 or 640)

### 7. Security Hardening

- [ ] **HTTPS Configuration** (CRITICAL for production)
  - [ ] SSL certificates obtained (Let's Encrypt or commercial)
  - [ ] Apache HTTPS virtual host configured
  - [ ] HTTP redirects to HTTPS
  - [ ] Update `APP_URL` in PHP .env to use https://
  - [ ] Update Keycloak redirect URIs to use https://

- [ ] **Secrets Management**
  - [ ] All default passwords changed
  - [ ] Strong, unique passwords for database
  - [ ] Strong, unique API keys generated
  - [ ] MinIO credentials changed from defaults
  - [ ] Session secrets are random and secure

- [ ] **CSRF Protection**
  - [ ] Review forms in `php-app/src/Views/` for CSRF token implementation
  - [ ] Add CSRF token generation/validation if not present

- [ ] **Firewall Rules**
  - [ ] PostgreSQL port (5432) accessible only from Python server
  - [ ] Redis port (6379) accessible only from localhost
  - [ ] MinIO port (9000) accessible only from App and Python servers
  - [ ] Keycloak port (8080) accessible from App server
  - [ ] Python API port (8000) accessible only from App server
  - [ ] Web ports (80, 443) accessible from client networks only

- [ ] **File Upload Restrictions**
  - [ ] Verify `MAX_UPLOAD_BYTES` is set appropriately
  - [ ] File type validation enforced (only audio formats)
  - [ ] Upload directory not web-accessible (using MinIO, so ✓)

### 8. Testing

#### Connectivity Tests
- [ ] From App server, test Python API: `curl http://192.168.1.90:8000/api/health`
- [ ] From App server, test Keycloak: `curl http://192.168.1.59:8080/realms/{realm}/.well-known/openid-configuration`
- [ ] From Python server, test PostgreSQL connection
- [ ] From Python server, test Redis: `redis-cli ping`
- [ ] From Python server, test MinIO access

#### Functional Tests
- [ ] Navigate to application URL in browser
- [ ] Complete Keycloak login flow
- [ ] Access dashboard as each role (admin, analyst, viewer)
- [ ] Create a new case
- [ ] Upload an audio file
- [ ] Start transcription job
- [ ] Monitor job progress in real-time
- [ ] Verify job completion
- [ ] Download transcript
- [ ] Check audit logs
- [ ] Test logout

#### Error Handling
- [ ] Test invalid file upload (wrong type, too large)
- [ ] Test job failure scenarios
- [ ] Verify error messages are user-friendly
- [ ] Check that errors are logged appropriately

### 9. Monitoring & Logging

- [ ] **Application Logs**
  - [ ] PHP error logs: `/var/www/gismartanalytics/storage/logs/php_errors.log`
  - [ ] Apache error logs: `/var/log/apache2/transcription_error.log`
  - [ ] Python API logs: Check systemd journal or configured log file
  - [ ] Celery worker logs: Check systemd journal

- [ ] **Log Rotation**
  - [ ] Configure logrotate for application logs
  - [ ] Set retention policy (e.g., 30 days)

- [ ] **Monitoring Setup**
  - [ ] Set up monitoring for systemd services
  - [ ] Monitor disk space (audio files can be large)
  - [ ] Monitor Redis memory usage
  - [ ] Monitor MinIO storage capacity
  - [ ] Monitor database size and performance

### 10. Backup & Recovery

- [ ] **Database Backups**
  - [ ] Automated PostgreSQL backups configured
  - [ ] Backup retention policy defined
  - [ ] Test database restore procedure

- [ ] **Object Storage Backups**
  - [ ] MinIO backup strategy defined
  - [ ] Test file restore procedure

- [ ] **Configuration Backups**
  - [ ] .env files backed up securely (encrypted)
  - [ ] Apache/systemd configurations backed up

- [ ] **Rollback Plan**
  - [ ] Document rollback procedure
  - [ ] Test rollback on staging environment

### 11. Documentation

- [ ] Update `docs/deployment.md` with environment-specific details
- [ ] Document custom configurations
- [ ] Create operations runbook for common tasks
- [ ] Document troubleshooting procedures for known issues

### 12. Performance Tuning

- [ ] Configure PHP-FPM worker processes based on server resources
- [ ] Set Celery worker concurrency based on CPU cores
- [ ] Configure PostgreSQL connection pooling if needed
- [ ] Tune Apache MaxClients/MaxRequestWorkers

### 13. Post-Deployment Verification

- [ ] All services running: `sudo systemctl status transcription-api transcription-worker apache2 postgresql redis-server`
- [ ] No errors in logs
- [ ] Complete end-to-end workflow test
- [ ] Performance acceptable under expected load
- [ ] Security scan completed (no critical vulnerabilities)

## Sign-Off

- [ ] Development team approves deployment
- [ ] Operations team approves deployment
- [ ] Security review completed
- [ ] Stakeholder acceptance

---

## Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| Development Lead | | |
| Operations | | |
| Database Admin | | |
| Security | | |

## Rollback Procedure

If critical issues are discovered post-deployment:

1. Stop systemd services:
   ```bash
   sudo systemctl stop transcription-api transcription-worker
   ```

2. Restore database from backup:
   ```bash
   psql -U transcription_user -d transcription_db < backup.sql
   ```

3. Revert code to previous version

4. Restart services with previous version

5. Investigate issues in non-production environment
