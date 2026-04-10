#!/bin/bash
# Deployment script for Python Backend Server (192.168.1.90)
# Run as root or with sudo

set -e  # Exit on error

echo "======================================"
echo "MXA Transcription - Python Server Setup"
echo "Server: 192.168.1.90"
echo "======================================"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Variables
APP_DIR="/opt/mxa-transcription"
REPO_URL="https://github.com/nkosinathil/mxa-transcription.git"
BRANCH="main"
VENV_DIR="$APP_DIR/venv"
USER="mxa"

# Step 1: Update system
echo "[1/12] Updating system packages..."
apt-get update
apt-get upgrade -y

# Step 2: Install system dependencies
echo "[2/12] Installing system dependencies..."
apt-get install -y \
    python3.10 \
    python3.10-venv \
    python3-pip \
    redis-server \
    git \
    curl \
    wget \
    ffmpeg \
    build-essential \
    libpq-dev

# Step 3: Create application user
echo "[3/12] Creating application user..."
if ! id "$USER" &>/dev/null; then
    useradd -m -s /bin/bash $USER
    echo "User $USER created"
else
    echo "User $USER already exists"
fi

# Step 4: Install MinIO
echo "[4/12] Installing MinIO..."
wget https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
chmod +x /usr/local/bin/minio

# Create MinIO directories
mkdir -p /opt/minio/data
chown -R $USER:$USER /opt/minio

# Create MinIO systemd service
cat > /etc/systemd/system/minio.service <<'MINIO_SERVICE'
[Unit]
Description=MinIO Object Storage
After=network.target

[Service]
Type=simple
User=mxa
Group=mxa
ExecStart=/usr/local/bin/minio server /opt/minio/data --console-address :9001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
MINIO_SERVICE

# Step 5: Clone repository
echo "[5/12] Cloning repository..."
if [ -d "$APP_DIR" ]; then
    echo "Directory exists, pulling latest changes..."
    cd $APP_DIR
    git pull origin $BRANCH
else
    git clone -b $BRANCH $REPO_URL $APP_DIR
    cd $APP_DIR
fi

# Change ownership
chown -R $USER:$USER $APP_DIR

# Step 6: Set up Python virtual environment
echo "[6/12] Setting up Python virtual environment..."
sudo -u $USER python3.10 -m venv $VENV_DIR
sudo -u $USER $VENV_DIR/bin/pip install --upgrade pip wheel

# Step 7: Install Python dependencies
echo "[7/12] Installing Python dependencies..."
sudo -u $USER $VENV_DIR/bin/pip install -r $APP_DIR/python-backend/requirements.txt
sudo -u $USER $VENV_DIR/bin/pip install -r $APP_DIR/requirements.txt

# Step 8: Configure environment
echo "[8/12] Configuring environment..."
sudo -u $USER cp $APP_DIR/python-backend/.env.example $APP_DIR/python-backend/.env
echo "IMPORTANT: Edit $APP_DIR/python-backend/.env with your actual credentials"

# Step 9: Configure Redis
echo "[9/12] Configuring Redis..."
systemctl enable redis-server
systemctl start redis-server

# Step 10: Create systemd services for FastAPI
echo "[10/12] Creating FastAPI systemd service..."
cat > /etc/systemd/system/mxa-api.service <<FASTAPI_SERVICE
[Unit]
Description=MXA Transcription FastAPI
After=network.target redis-server.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$APP_DIR/python-backend
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
FASTAPI_SERVICE

# Step 11: Create systemd service for Celery worker
echo "[11/12] Creating Celery worker systemd service..."
cat > /etc/systemd/system/mxa-celery.service <<CELERY_SERVICE
[Unit]
Description=MXA Transcription Celery Worker
After=network.target redis-server.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$APP_DIR/python-backend
Environment="PATH=$VENV_DIR/bin"
Environment="PYTHONPATH=$APP_DIR"
ExecStart=$VENV_DIR/bin/celery -A app.tasks.celery_app worker --loglevel=info --concurrency=2
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
CELERY_SERVICE

# Step 12: Enable and start services
echo "[12/12] Starting services..."
systemctl daemon-reload
systemctl enable minio
systemctl start minio
systemctl enable mxa-api
systemctl start mxa-api
systemctl enable mxa-celery
systemctl start mxa-celery

# Create log directory
mkdir -p /var/log/mxa-transcription
chown -R $USER:$USER /var/log/mxa-transcription

echo
echo "======================================"
echo "Python Server Deployment Complete!"
echo "======================================"
echo
echo "Services status:"
systemctl status minio --no-pager -l || true
systemctl status mxa-api --no-pager -l || true
systemctl status mxa-celery --no-pager -l || true
echo
echo "Next steps:"
echo "1. Edit $APP_DIR/python-backend/.env with your configuration"
echo "2. Configure MinIO access credentials"
echo "3. Add Hugging Face token for speaker diarization"
echo "4. Test the API: http://192.168.1.90:8000/health"
echo "5. MinIO console: http://192.168.1.90:9001"
echo
echo "Service management:"
echo "  - FastAPI API: systemctl [start|stop|restart] mxa-api"
echo "  - Celery Worker: systemctl [start|stop|restart] mxa-celery"
echo "  - MinIO: systemctl [start|stop|restart] minio"
echo "  - Redis: systemctl [start|stop|restart] redis-server"
echo
echo "Logs:"
echo "  - API: journalctl -u mxa-api -f"
echo "  - Celery: journalctl -u mxa-celery -f"
echo "  - MinIO: journalctl -u minio -f"
echo
