# Deployment Guide

This guide walks you through deploying the MXA Transcription web application
from scratch. Follow the steps in order.

---

## Prerequisites

| Server | IP | Requirements |
|--------|----|-------------|
| SSO    | 192.168.1.59 | Keycloak running with your realm/client configured |
| App    | 192.168.1.66 | Ubuntu 22.04+, Apache 2.4, PHP 8.1-FPM, PostgreSQL 15 |
| Python | 192.168.1.90 | Ubuntu 22.04+, Python 3.11, Redis, MinIO |

---

## Step 1: PostgreSQL Setup (App Server – 192.168.1.66)

```bash
# Create database and user
sudo -u postgres psql <<EOF
CREATE USER transcription_user WITH PASSWORD 'your_strong_password';
CREATE DATABASE transcription_db OWNER transcription_user;
GRANT ALL PRIVILEGES ON DATABASE transcription_db TO transcription_user;
EOF

# Run migrations
cd /var/www/gismartanalytics
psql -U transcription_user -d transcription_db -f database/schema.sql
```

---

## Step 2: PHP Application (App Server – 192.168.1.66)

```bash
# Clone or copy the php-app folder
sudo mkdir -p /var/www/gismartanalytics
sudo cp -r php-app/* /var/www/gismartanalytics/

# Install PHP dependencies
cd /var/www/gismartanalytics
composer install --no-dev --optimize-autoloader

# Configure environment
cp .env.example .env
nano .env    # Fill in all values (see docs/configuration.md)

# Set permissions
sudo chown -R www-data:www-data /var/www/gismartanalytics
sudo chmod -R 755 /var/www/gismartanalytics
sudo chmod -R 775 /var/www/gismartanalytics/storage/logs

# Enable Apache modules and site
sudo a2enmod rewrite headers proxy_fcgi
sudo cp deploy/apache/vhost.conf /etc/apache2/sites-available/transcription.conf
sudo a2ensite transcription.conf
sudo systemctl reload apache2
```

---

## Step 3: Python Backend (Python Server – 192.168.1.90)

### 3a. Install system dependencies
```bash
sudo apt-get update
sudo apt-get install -y python3.11 python3.11-venv ffmpeg redis-server

# Start Redis
sudo systemctl enable --now redis-server
```

### 3b. MinIO Setup
```bash
# Download and install MinIO
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Create data directory
sudo mkdir -p /data/minio
sudo useradd -r -s /sbin/nologin minio-user
sudo chown minio-user:minio-user /data/minio

# Start MinIO (adjust credentials in the environment)
MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=your_minio_password \
    minio server /data/minio --console-address ":9001" &
```

### 3c. Deploy Python Backend
```bash
# Create application user
sudo useradd -r -s /sbin/nologin transcription
sudo mkdir -p /opt/mxa-transcription /var/log/mxa-transcription
sudo chown transcription:transcription /opt/mxa-transcription /var/log/mxa-transcription

# Copy application
sudo cp -r python-backend /opt/mxa-transcription/python-backend

# Create and activate virtualenv
cd /opt/mxa-transcription/python-backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Configure environment
cp .env.example .env
nano .env    # Fill in all values

# Install systemd services
sudo cp deploy/systemd/transcription-api.service    /etc/systemd/system/
sudo cp deploy/systemd/transcription-worker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now transcription-api transcription-worker
```

---

## Step 4: Verify the Deployment

```bash
# Check Python API health
curl http://192.168.1.90:8000/api/health

# Check services
sudo systemctl status transcription-api
sudo systemctl status transcription-worker

# Check logs
sudo journalctl -u transcription-api -f
tail -f /var/log/mxa-transcription/celery.log
tail -f /var/log/apache2/transcription_error.log
```

---

## Step 5: Keycloak Client Configuration

In your Keycloak admin console:

1. Open your realm
2. Go to Clients → find or create `transcription-web`
3. Set **Valid Redirect URIs** to: `http://192.168.1.66/auth/callback`
4. Set **Web Origins** to: `http://192.168.1.66`
5. Note the **Client Secret** and add it to `php-app/.env` → `KEYCLOAK_CLIENT_SECRET`
6. Ensure the roles `admin`, `analyst`, `viewer` exist in the realm (or adjust
   `UserRepository::mapRole()` to match your existing role names)

---

## Step 6: Updating the Application

```bash
# PHP app: pull new code and update dependencies
cd /var/www/gismartanalytics
git pull
composer install --no-dev --optimize-autoloader
sudo systemctl reload apache2

# Python backend: pull new code and restart services
cd /opt/mxa-transcription/python-backend
git pull
source .venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart transcription-api transcription-worker
```
