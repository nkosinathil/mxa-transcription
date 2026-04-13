#!/bin/bash
# =============================================================================
# MXA Transcription - Python Server Setup (192.168.1.90)
# =============================================================================
# This script sets up the Python/FastAPI/Celery/Redis/MinIO server
#
# Components installed/configured:
#   - Python 3.11+ with virtual environment
#   - FFmpeg for audio processing
#   - Redis (Celery broker)
#   - MinIO object storage
#   - FastAPI application
#   - Celery worker (systemd service)
#
# Usage:
#   sudo ./setup-python-server.sh
# =============================================================================

set -e  # Exit on error

# Must run as root for system package installation
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================================================${NC}"
echo -e "${BLUE}MXA Transcription - Python Server Setup${NC}"
echo -e "${BLUE}Server: 192.168.1.90 (Python/FastAPI/Celery/Redis/MinIO)${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""

# =============================================================================
# Interactive Configuration
# =============================================================================
echo -e "${BLUE}Configuration${NC}"
echo ""

# Check for API key from app server
if [ -f "/tmp/mxa_api_key.txt" ]; then
    API_SECRET_KEY=$(cat /tmp/mxa_api_key.txt)
    echo -e "${GREEN}  ✓ Found API key from app server${NC}"
else
    echo -e "${YELLOW}  ⚠ API key file not found at /tmp/mxa_api_key.txt${NC}"
    read -p "Do you want to generate a new API key? (y/n) [y]: " GEN_KEY
    GEN_KEY=${GEN_KEY:-y}
    if [ "$GEN_KEY" = "y" ]; then
        API_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
        echo -e "${YELLOW}  → Generated new API key${NC}"
        echo -e "${YELLOW}    You MUST update PYTHON_API_KEY in php-app/.env on 192.168.1.66${NC}"
        echo -e "${YELLOW}    API Key: $API_SECRET_KEY${NC}"
    else
        read -sp "Enter API key: " API_SECRET_KEY
        echo ""
    fi
fi

read -p "Redis URL [redis://localhost:6379/0]: " REDIS_URL
REDIS_URL=${REDIS_URL:-redis://localhost:6379/0}

read -p "PostgreSQL host (App server) [192.168.1.66]: " PG_HOST
PG_HOST=${PG_HOST:-192.168.1.66}

read -p "PostgreSQL port [5432]: " PG_PORT
PG_PORT=${PG_PORT:-5432}

read -p "PostgreSQL database [transcription_db]: " PG_DB
PG_DB=${PG_DB:-transcription_db}

read -p "PostgreSQL user [transcription_user]: " PG_USER
PG_USER=${PG_USER:-transcription_user}

read -sp "PostgreSQL password: " PG_PASS
echo ""
while [ -z "$PG_PASS" ]; do
    echo -e "${RED}Database password is required${NC}"
    read -sp "PostgreSQL password: " PG_PASS
    echo ""
done

read -p "MinIO access key [minioadmin]: " MINIO_ACCESS_KEY
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-minioadmin}

read -sp "MinIO secret key [minioadmin]: " MINIO_SECRET_KEY
echo ""
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-minioadmin}

read -p "HuggingFace token (optional, for speaker diarization): " HF_TOKEN

echo ""

# =============================================================================
# Step 1: Install system packages
# =============================================================================
echo -e "${BLUE}Step 1: Installing system packages...${NC}"

apt-get update

# Install Python 3.11+
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    wget

echo -e "${GREEN}  ✓ Python and FFmpeg installed${NC}"

# Install Redis
apt-get install -y redis-server
systemctl start redis-server
systemctl enable redis-server
echo -e "${GREEN}  ✓ Redis installed and started${NC}"

# Install MinIO
if ! command -v minio &> /dev/null; then
    echo -e "${BLUE}  → Installing MinIO...${NC}"
    wget -q https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
    chmod +x /usr/local/bin/minio
    echo -e "${GREEN}  ✓ MinIO installed${NC}"
else
    echo -e "${GREEN}  ✓ MinIO already installed${NC}"
fi

# Install MinIO Client (mc)
if ! command -v mc &> /dev/null; then
    echo -e "${BLUE}  → Installing MinIO Client...${NC}"
    wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
    echo -e "${GREEN}  ✓ MinIO Client installed${NC}"
else
    echo -e "${GREEN}  ✓ MinIO Client already installed${NC}"
fi

echo ""

# =============================================================================
# Step 2: Configure MinIO
# =============================================================================
echo -e "${BLUE}Step 2: Configuring MinIO...${NC}"

# Create MinIO user and directories
useradd -r -s /bin/false minio-user 2>/dev/null || echo -e "${YELLOW}  ⚠ minio-user already exists${NC}"
mkdir -p /mnt/data/minio
chown -R minio-user:minio-user /mnt/data/minio

# Create MinIO systemd service
cat > /etc/systemd/system/minio.service << EOF
[Unit]
Description=MinIO
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
User=minio-user
Group=minio-user
Environment="MINIO_ROOT_USER=$MINIO_ACCESS_KEY"
Environment="MINIO_ROOT_PASSWORD=$MINIO_SECRET_KEY"
ExecStart=/usr/local/bin/minio server /mnt/data/minio --console-address ":9001"
Restart=always
LimitNOFILE=65536
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

# Start MinIO
systemctl daemon-reload
systemctl start minio
systemctl enable minio

echo -e "${GREEN}  ✓ MinIO service configured and started${NC}"

# Wait for MinIO to start
sleep 3

# Configure MinIO client and create buckets
mc alias set myminio http://localhost:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" 2>/dev/null || true
mc mb myminio/audio-uploads 2>/dev/null || echo -e "${YELLOW}  ⚠ Bucket audio-uploads already exists${NC}"
mc mb myminio/transcription-results 2>/dev/null || echo -e "${YELLOW}  ⚠ Bucket transcription-results already exists${NC}"
mc mb myminio/exports 2>/dev/null || echo -e "${YELLOW}  ⚠ Bucket exports already exists${NC}"

echo -e "${GREEN}  ✓ MinIO buckets created${NC}"

echo ""

# =============================================================================
# Step 3: Configure Python application
# =============================================================================
echo -e "${BLUE}Step 3: Configuring Python application...${NC}"

# Create .env file
if [ ! -f "python-backend/.env" ]; then
    cp python-backend/.env.example python-backend/.env
    echo -e "${GREEN}  ✓ Created python-backend/.env${NC}"
else
    echo -e "${YELLOW}  ⚠ python-backend/.env already exists - will update values${NC}"
fi

# Update .env file
POSTGRES_DSN="postgresql://$PG_USER:$PG_PASS@$PG_HOST:$PG_PORT/$PG_DB"

sed -i "s|DEBUG=.*|DEBUG=false|" python-backend/.env
sed -i "s|LOG_LEVEL=.*|LOG_LEVEL=INFO|" python-backend/.env
sed -i "s|API_SECRET_KEY=.*|API_SECRET_KEY=$API_SECRET_KEY|" python-backend/.env
sed -i "s|REDIS_URL=.*|REDIS_URL=$REDIS_URL|" python-backend/.env
sed -i "s|MINIO_ENDPOINT=.*|MINIO_ENDPOINT=localhost:9000|" python-backend/.env
sed -i "s|MINIO_ACCESS_KEY=.*|MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY|" python-backend/.env
sed -i "s|MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=$MINIO_SECRET_KEY|" python-backend/.env
sed -i "s|POSTGRES_DSN=.*|POSTGRES_DSN=$POSTGRES_DSN|" python-backend/.env

if [ -n "$HF_TOKEN" ]; then
    sed -i "s|HUGGINGFACE_TOKEN=.*|HUGGINGFACE_TOKEN=$HF_TOKEN|" python-backend/.env
fi

echo -e "${GREEN}  ✓ Environment configured${NC}"

# Create Python virtual environment
cd python-backend
if [ ! -d ".venv" ]; then
    echo -e "${BLUE}  → Creating Python virtual environment...${NC}"
    python3 -m venv .venv
    echo -e "${GREEN}  ✓ Virtual environment created${NC}"
fi

# Install Python dependencies
echo -e "${BLUE}  → Installing Python dependencies (this may take several minutes)...${NC}"
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
cd ..
echo -e "${GREEN}  ✓ Python dependencies installed${NC}"

echo ""

# =============================================================================
# Step 4: Configure systemd services
# =============================================================================
echo -e "${BLUE}Step 4: Configuring systemd services...${NC}"

# Create FastAPI systemd service
cat > /etc/systemd/system/mxa-api.service << EOF
[Unit]
Description=MXA Transcription FastAPI
After=network.target redis-server.service minio.service

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=$SCRIPT_DIR/python-backend
Environment="PATH=$SCRIPT_DIR/python-backend/.venv/bin"
ExecStart=$SCRIPT_DIR/python-backend/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Celery worker systemd service
cat > /etc/systemd/system/mxa-celery.service << EOF
[Unit]
Description=MXA Transcription Celery Worker
After=network.target redis-server.service minio.service

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=$SCRIPT_DIR/python-backend
Environment="PATH=$SCRIPT_DIR/python-backend/.venv/bin"
ExecStart=$SCRIPT_DIR/python-backend/.venv/bin/celery -A app.tasks.transcription_tasks worker --loglevel=info
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start services
systemctl daemon-reload
systemctl start mxa-api
systemctl enable mxa-api
systemctl start mxa-celery
systemctl enable mxa-celery

echo -e "${GREEN}  ✓ Services configured and started${NC}"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}=========================================================================${NC}"
echo -e "${GREEN}Python Server Setup Complete!${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""
echo -e "${YELLOW}Service Status:${NC}"
systemctl status redis-server --no-pager | grep "Active:"
systemctl status minio --no-pager | grep "Active:"
systemctl status mxa-api --no-pager | grep "Active:"
systemctl status mxa-celery --no-pager | grep "Active:"
echo ""
echo -e "${YELLOW}Endpoints:${NC}"
echo "  FastAPI:        http://192.168.1.90:8000"
echo "  API Docs:       http://192.168.1.90:8000/docs"
echo "  MinIO Console:  http://192.168.1.90:9001"
echo "  MinIO API:      http://192.168.1.90:9000"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  sudo systemctl status mxa-api"
echo "  sudo systemctl status mxa-celery"
echo "  sudo systemctl restart mxa-api"
echo "  sudo systemctl restart mxa-celery"
echo ""
echo -e "${YELLOW}Logs:${NC}"
echo "  sudo journalctl -u mxa-api -f"
echo "  sudo journalctl -u mxa-celery -f"
echo ""
echo -e "API Key: ${GREEN}$API_SECRET_KEY${NC}"
echo -e "Config: ${GREEN}python-backend/.env${NC}"
echo ""
