# MXA Transcription Web App - Quick Start Deployment Guide

**Last updated:** April 2026

This guide gets you from zero to a running MXA Transcription web application in minimal time.

---

## 🎯 Overview

**What you're deploying:** A 3-server web application for audio transcription with speaker diarization

**Architecture:**
```
┌─────────────────┐      ┌──────────────────┐      ┌────────────────────┐
│  SSO Server     │      │  App Server      │      │  Processing Server │
│  192.168.1.59   │◄────►│  192.168.1.66    │◄────►│  192.168.1.90      │
│                 │      │                  │      │                    │
│  • Keycloak     │      │  • PHP/Apache    │      │  • Python/FastAPI  │
│                 │      │  • PostgreSQL    │      │  • Celery Workers  │
│                 │      │                  │      │  • Redis           │
│                 │      │                  │      │  • MinIO           │
└─────────────────┘      └──────────────────┘      └────────────────────┘
```

**Deployment time:** 30-60 minutes (automated) or 2-3 hours (manual)

---

## ✅ Prerequisites

Before you begin, ensure you have:

- [ ] **3 Linux servers** (Ubuntu 22.04 LTS recommended) with SSH access
- [ ] **Root or sudo access** on all servers
- [ ] **Network connectivity** between servers
- [ ] **Domain name or IP addresses** for accessing the application
- [ ] **SSL certificate** (recommended for production) or Let's Encrypt
- [ ] **Git installed** on all servers
- [ ] **Hugging Face token** (optional, for speaker diarization)

**Minimum Server Requirements:**

| Server | CPU | RAM | Storage | Purpose |
|--------|-----|-----|---------|---------|
| SSO (192.168.1.59) | 2 cores | 2 GB | 20 GB | Keycloak authentication |
| App (192.168.1.66) | 2 cores | 4 GB | 50 GB | Web UI + database |
| Processing (192.168.1.90) | 4+ cores | 8+ GB | 100+ GB | Transcription + storage |

---

## 🚀 Option 1: Automated Setup (Recommended)

The fastest way to deploy is using the provided automated setup scripts.

### Step 1: Clone the Repository (on all 3 servers)

```bash
# Run on each server
git clone https://github.com/nkosinathil/mxa-transcription.git
cd mxa-transcription
git checkout copilot/convert-desktop-app-to-web-app
```

### Step 2: SSO Server Setup (192.168.1.59)

```bash
# On the SSO server
sudo ./setup-sso-server.sh
```

**The script will prompt you for:**
- Keycloak admin username and password
- Database password for Keycloak
- Realm name (e.g., "mxa-transcription")
- Server hostname/IP

**After completion:**
1. Access Keycloak admin console: `http://192.168.1.59:8080/admin`
2. Login with the admin credentials you created
3. Note the realm name for the next steps

### Step 3: Configure Keycloak Client

**In the Keycloak admin console:**

1. Navigate to your realm → **Clients** → **Create client**
2. Set **Client ID:** `mxa-transcription-app`
3. Set **Client Type:** OpenID Connect
4. Enable **Client authentication**
5. Set **Valid Redirect URIs:**
   - `http://192.168.1.66/auth/callback`
   - `https://your-domain.com/auth/callback` (for production)
6. Save and go to **Credentials** tab
7. **Copy the Client Secret** - you'll need this for the app server

**Create roles:**
1. Go to **Realm roles** → **Create role**
2. Create three roles: `admin`, `analyst`, `viewer`

**Create a test user:**
1. Go to **Users** → **Create user**
2. Set username and email
3. Go to **Credentials** tab → Set password (disable temporary)
4. Go to **Role mapping** → Assign the `admin` role

### Step 4: App Server Setup (192.168.1.66)

```bash
# On the App server
sudo ./setup-app-server.sh
```

**The script will prompt you for:**
- Database name, user, and password
- Session secret (auto-generated if you press Enter)
- Keycloak details:
  - Base URL: `http://192.168.1.59:8080`
  - Realm: (the realm you created)
  - Client ID: `mxa-transcription-app`
  - Client Secret: (from step 3)
  - Redirect URI: `http://192.168.1.66/auth/callback`
- Python API details:
  - Base URL: `http://192.168.1.90:8000`
  - API Key: (auto-generated if you press Enter)
- MinIO credentials

**After completion:**
1. The script creates the PostgreSQL database
2. Runs all database migrations
3. Configures Apache virtual host
4. Sets up PHP-FPM

### Step 5: Processing Server Setup (192.168.1.90)

```bash
# On the Processing server
sudo ./setup-python-server.sh
```

**The script will prompt you for:**
- API secret key (must match the API key from step 4)
- Redis password (or leave empty for no auth)
- PostgreSQL connection details (same as step 4)
- MinIO credentials (must match step 4)
- Hugging Face token (optional, for speaker diarization)
- Model settings (device: cpu/cuda, model size: tiny/base/small/medium/large)

**After completion:**
1. MinIO buckets are created
2. Redis is configured
3. Systemd services are installed and started:
   - `transcription-api.service` (FastAPI)
   - `transcription-worker.service` (Celery)

### Step 6: Verify Deployment

```bash
# On the App server (192.168.1.66)
cd mxa-transcription
python3 validate-deployment.py
```

This script checks:
- ✓ Directory structure
- ✓ Configuration files
- ✓ Dependencies installed
- ✓ Database migrations
- ✓ Service connectivity

### Step 7: Access the Application

1. **Open your browser:** `http://192.168.1.66`
2. **Click "Login with Keycloak"**
3. **Enter the test user credentials** from step 3
4. **You should see the dashboard!**

---

## 🔧 Option 2: Manual Setup

For those who prefer step-by-step manual configuration or have custom requirements.

### Prerequisites Installation

#### All Servers:
```bash
sudo apt-get update
sudo apt-get install -y git curl wget
```

### 1️⃣ SSO Server (192.168.1.59) - Keycloak

```bash
# Install Java
sudo apt-get install -y openjdk-17-jdk

# Download Keycloak (adjust version as needed)
wget https://github.com/keycloak/keycloak/releases/download/23.0.0/keycloak-23.0.0.tar.gz
tar -xzf keycloak-23.0.0.tar.gz
cd keycloak-23.0.0

# Set admin credentials
export KC_BOOTSTRAP_ADMIN_USERNAME=admin
export KC_BOOTSTRAP_ADMIN_PASSWORD=your-secure-password

# Start Keycloak in development mode
bin/kc.sh start-dev --http-port=8080

# For production, use:
# bin/kc.sh start --hostname=192.168.1.59
```

**Configure as described in Step 3 of the automated setup above.**

### 2️⃣ App Server (192.168.1.66) - PHP + PostgreSQL

```bash
# Install dependencies
sudo apt-get install -y \
    apache2 \
    php8.1 php8.1-fpm php8.1-pgsql php8.1-curl php8.1-json \
    postgresql-15 \
    composer

# Configure PostgreSQL
sudo -u postgres createuser transcription_user -P
sudo -u postgres createdb -O transcription_user transcription_db

# Clone repository
git clone https://github.com/nkosinathil/mxa-transcription.git
cd mxa-transcription
git checkout copilot/convert-desktop-app-to-web-app

# Install PHP dependencies
cd php-app
composer install --no-dev --optimize-autoloader

# Configure environment
cp .env.example .env
nano .env  # Edit all required values

# Generate session secret
php -r "echo bin2hex(random_bytes(32));"
# Add to .env as SESSION_SECRET=<generated-value>

# Deploy to web root
sudo mkdir -p /var/www/gismartanalytics
sudo cp -r /path/to/mxa-transcription/php-app/* /var/www/gismartanalytics/
sudo chown -R www-data:www-data /var/www/gismartanalytics
sudo chmod -R 755 /var/www/gismartanalytics
sudo chmod -R 775 /var/www/gismartanalytics/storage/logs

# Configure Apache
sudo cp /path/to/mxa-transcription/deploy/apache/vhost.conf \
    /etc/apache2/sites-available/transcription.conf
sudo a2enmod rewrite headers proxy_fcgi
sudo a2ensite transcription.conf
sudo systemctl restart apache2

# Run database migrations
cd /path/to/mxa-transcription
psql -U transcription_user -d transcription_db -f database/schema.sql
```

### 3️⃣ Processing Server (192.168.1.90) - Python + Celery + Redis + MinIO

```bash
# Install system dependencies
sudo apt-get install -y \
    python3.11 python3.11-venv python3-pip \
    redis-server \
    ffmpeg

# Configure Redis (optional password)
sudo nano /etc/redis/redis.conf
# Uncomment: requirepass your-redis-password
sudo systemctl restart redis-server

# Install MinIO
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Create MinIO data directory
sudo mkdir -p /opt/minio/data
sudo useradd -r minio-user -s /sbin/nologin
sudo chown minio-user:minio-user /opt/minio/data

# Start MinIO (development)
MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=minioadmin \
    minio server /opt/minio/data --console-address ":9001"

# For production, create systemd service (see deploy/systemd/ for examples)

# Create MinIO buckets
# Install mc (MinIO Client)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

mc alias set local http://localhost:9000 minioadmin minioadmin
mc mb local/audio-uploads
mc mb local/transcription-results
mc mb local/exports

# Setup Python application
cd /path/to/mxa-transcription/python-backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Configure environment
cp .env.example .env
nano .env  # Edit all required values

# Generate API secret
python -c "import secrets; print(secrets.token_hex(32))"
# Add to .env as API_SECRET_KEY=<generated-value>

# Install systemd services
sudo cp /path/to/mxa-transcription/deploy/systemd/transcription-api.service \
    /etc/systemd/system/
sudo cp /path/to/mxa-transcription/deploy/systemd/transcription-worker.service \
    /etc/systemd/system/

# Edit service files to update paths
sudo nano /etc/systemd/system/transcription-api.service
sudo nano /etc/systemd/system/transcription-worker.service

# Start services
sudo systemctl daemon-reload
sudo systemctl enable transcription-api transcription-worker
sudo systemctl start transcription-api transcription-worker

# Check status
sudo systemctl status transcription-api
sudo systemctl status transcription-worker
```

---

## 🔍 Testing the Deployment

### 1. Test Service Connectivity

From the **App Server** (192.168.1.66):

```bash
# Test Python API
curl http://192.168.1.90:8000/api/health

# Test Keycloak
curl http://192.168.1.59:8080/realms/mxa-transcription/.well-known/openid-configuration
```

From the **Processing Server** (192.168.1.90):

```bash
# Test PostgreSQL
psql -h 192.168.1.66 -U transcription_user -d transcription_db -c "SELECT 1;"

# Test Redis
redis-cli ping

# Test MinIO
mc ls local/
```

### 2. End-to-End Functional Test

1. **Login** - Navigate to http://192.168.1.66 and login
2. **Create a case** - Click "New Case" and enter details
3. **Upload audio** - Upload a small audio file (e.g., .mp3, .wav)
4. **Start transcription** - Click "Start Transcription"
5. **Monitor progress** - Watch the real-time progress bar and event log
6. **Download transcript** - Once complete, download the transcript
7. **Check audit log** - Verify all actions are logged

---

## 🔐 Production Security Checklist

Before going to production, **ensure these are completed:**

- [ ] **HTTPS enabled** with valid SSL certificates
- [ ] **All default passwords changed** (database, Redis, MinIO, Keycloak admin)
- [ ] **Firewall rules configured:**
  - PostgreSQL (5432): Only from Python server
  - Redis (6379): Localhost only
  - MinIO (9000): Only from App and Python servers
  - Keycloak (8080): Only from App server and client network
  - Python API (8000): Only from App server
  - Web (80, 443): From client network only
- [ ] **Environment files secured** (.env files should be 600 or 640)
- [ ] **APP_DEBUG=false** in PHP .env
- [ ] **DEBUG=false** in Python .env
- [ ] **Session secrets are random and strong** (32+ characters)
- [ ] **API keys are random and strong** (64+ characters)
- [ ] **Database backups configured** (automated daily backups)
- [ ] **Log rotation configured** (logrotate for all application logs)
- [ ] **Monitoring set up** (disk space, service health, error rates)

---

## 🐛 Troubleshooting

### Issue: Can't login - Keycloak redirect fails

**Cause:** Redirect URI mismatch

**Solution:**
1. Check `KEYCLOAK_REDIRECT_URI` in php-app/.env
2. Verify it matches exactly in Keycloak client settings
3. Include both http and https variants if needed

### Issue: Upload fails - MinIO connection error

**Cause:** MinIO credentials mismatch or network issue

**Solution:**
1. Verify MinIO credentials match in both php-app/.env and python-backend/.env
2. Test MinIO connectivity: `curl http://192.168.1.90:9000/minio/health/live`
3. Check MinIO logs: `journalctl -u minio -n 50`

### Issue: Transcription stuck in "processing" state

**Cause:** Celery worker not running or crashed

**Solution:**
1. Check worker status: `sudo systemctl status transcription-worker`
2. View worker logs: `journalctl -u transcription-worker -n 100 -f`
3. Restart worker: `sudo systemctl restart transcription-worker`
4. Check for Python errors in logs

### Issue: Database connection failed

**Cause:** PostgreSQL not accessible or wrong credentials

**Solution:**
1. Test connection from Python server:
   ```bash
   psql -h 192.168.1.66 -U transcription_user -d transcription_db
   ```
2. Check PostgreSQL is listening on external interface:
   ```bash
   sudo nano /etc/postgresql/15/main/postgresql.conf
   # Ensure: listen_addresses = '*'
   ```
3. Check pg_hba.conf allows connection from Python server:
   ```bash
   sudo nano /etc/postgresql/15/main/pg_hba.conf
   # Add: host transcription_db transcription_user 192.168.1.90/32 md5
   sudo systemctl restart postgresql
   ```

### Issue: Apache shows 500 error

**Cause:** PHP errors or missing dependencies

**Solution:**
1. Check Apache error log: `sudo tail -f /var/log/apache2/error.log`
2. Check PHP error log: `tail -f /var/www/gismartanalytics/storage/logs/php_errors.log`
3. Verify composer dependencies: `cd /var/www/gismartanalytics && composer install`
4. Check file permissions: `sudo chown -R www-data:www-data /var/www/gismartanalytics`

### Getting More Help

- **View application logs:** Check `php-app/storage/logs/` and `journalctl` for systemd services
- **Run validation:** `python3 validate-deployment.py` to identify configuration issues
- **Consult full docs:** See `DEPLOYMENT_CHECKLIST.md` and `docs/` directory
- **Common issues:** See `docs/troubleshooting.md` for more scenarios

---

## 📚 Next Steps

After successful deployment:

1. **Configure monitoring** - Set up Prometheus/Grafana or similar
2. **Set up backups** - Automate PostgreSQL dumps and MinIO snapshots
3. **Performance tuning** - Adjust PHP-FPM workers, Celery concurrency based on load
4. **User training** - Train users on case management and transcription workflow
5. **Custom configuration** - Adjust default model size, upload limits, etc. in .env files

---

## 📖 Additional Resources

| Resource | Location |
|----------|----------|
| Full deployment checklist | DEPLOYMENT_CHECKLIST.md |
| Architecture documentation | docs/architecture.md |
| Configuration reference | docs/configuration.md |
| Database schema | docs/database.md |
| API documentation | docs/api.md |
| Maintenance guide | docs/maintenance.md |
| Troubleshooting guide | docs/troubleshooting.md |

---

## 🎉 Success!

If you can login, create a case, upload audio, and see transcription results - **congratulations!** You've successfully deployed the MXA Transcription web application.

For questions or issues not covered in this guide, please refer to the comprehensive documentation in the `docs/` directory or consult the DEPLOYMENT_CHECKLIST.md file.

**Happy transcribing! 🎙️✨**
