#!/bin/bash
# =============================================================================
# MXA Transcription - Quick Setup Helper
# =============================================================================
# This script helps prepare the repository for deployment by:
#   1. Creating .env files from examples
#   2. Generating secure secrets
#   3. Creating required directories
#   4. Checking dependencies
#
# Usage:
#   ./setup.sh [--skip-deps]
#
# Options:
#   --skip-deps   Skip dependency installation (composer, pip)
#
# Note: This script does NOT start services or create databases.
#       See DEPLOYMENT_CHECKLIST.md for complete deployment steps.
# =============================================================================

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SKIP_DEPS=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
    esac
done

echo -e "${BLUE}=========================================================================${NC}"
echo -e "${BLUE}MXA Transcription - Quick Setup${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""

# =============================================================================
# Step 1: Create .env files
# =============================================================================
echo -e "${BLUE}Step 1: Creating .env files...${NC}"

if [ -f "php-app/.env" ]; then
    echo -e "${YELLOW}  ⚠ php-app/.env already exists - skipping${NC}"
else
    cp php-app/.env.example php-app/.env
    echo -e "${GREEN}  ✓ Created php-app/.env${NC}"
fi

if [ -f "python-backend/.env" ]; then
    echo -e "${YELLOW}  ⚠ python-backend/.env already exists - skipping${NC}"
else
    cp python-backend/.env.example python-backend/.env
    echo -e "${GREEN}  ✓ Created python-backend/.env${NC}"
fi

echo ""

# =============================================================================
# Step 2: Generate secrets
# =============================================================================
echo -e "${BLUE}Step 2: Generating secure secrets...${NC}"

# Generate SESSION_SECRET for PHP
if command -v php &> /dev/null; then
    SESSION_SECRET=$(php -r "echo bin2hex(random_bytes(32));")
    if grep -q "SESSION_SECRET=replace-with-a-long-random-string" php-app/.env; then
        sed -i.bak "s/SESSION_SECRET=replace-with-a-long-random-string/SESSION_SECRET=$SESSION_SECRET/" php-app/.env
        rm php-app/.env.bak
        echo -e "${GREEN}  ✓ Generated SESSION_SECRET${NC}"
    else
        echo -e "${YELLOW}  ⚠ SESSION_SECRET already set - skipping${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ PHP not found - SESSION_SECRET not generated${NC}"
fi

# Generate API_SECRET_KEY for Python
if command -v python3 &> /dev/null; then
    API_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    if grep -q "API_SECRET_KEY=replace-with-a-long-random-string" python-backend/.env; then
        sed -i.bak "s/API_SECRET_KEY=replace-with-a-long-random-string/API_SECRET_KEY=$API_SECRET/" python-backend/.env
        rm python-backend/.env.bak
        echo -e "${GREEN}  ✓ Generated API_SECRET_KEY${NC}"
    else
        echo -e "${YELLOW}  ⚠ API_SECRET_KEY already set - skipping${NC}"
    fi
    
    # Update PYTHON_API_KEY in PHP .env to match
    if grep -q "PYTHON_API_KEY=replace-with-same-key-as-python-env" php-app/.env; then
        sed -i.bak "s/PYTHON_API_KEY=replace-with-same-key-as-python-env/PYTHON_API_KEY=$API_SECRET/" php-app/.env
        rm php-app/.env.bak
        echo -e "${GREEN}  ✓ Updated PYTHON_API_KEY in php-app/.env${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Python3 not found - API_SECRET_KEY not generated${NC}"
fi

echo ""

# =============================================================================
# Step 3: Create required directories
# =============================================================================
echo -e "${BLUE}Step 3: Creating required directories...${NC}"

mkdir -p php-app/storage/logs
echo -e "${GREEN}  ✓ Created php-app/storage/logs/${NC}"

echo ""

# =============================================================================
# Step 4: Check dependencies
# =============================================================================
echo -e "${BLUE}Step 4: Checking dependencies...${NC}"

# Check PHP
if command -v php &> /dev/null; then
    PHP_VERSION=$(php -v | head -n 1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
    echo -e "${GREEN}  ✓ PHP $PHP_VERSION installed${NC}"
else
    echo -e "${RED}  ✗ PHP not found${NC}"
fi

# Check Composer
if command -v composer &> /dev/null; then
    echo -e "${GREEN}  ✓ Composer installed${NC}"
else
    echo -e "${YELLOW}  ⚠ Composer not found - required for PHP dependencies${NC}"
fi

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d ' ' -f 2)
    echo -e "${GREEN}  ✓ Python $PYTHON_VERSION installed${NC}"
else
    echo -e "${RED}  ✗ Python3 not found${NC}"
fi

# Check FFmpeg
if command -v ffmpeg &> /dev/null; then
    echo -e "${GREEN}  ✓ FFmpeg installed${NC}"
else
    echo -e "${YELLOW}  ⚠ FFmpeg not found - required for audio processing${NC}"
    echo -e "${YELLOW}    Install: sudo apt-get install ffmpeg${NC}"
fi

echo ""

# =============================================================================
# Step 5: Install dependencies (optional)
# =============================================================================
if [ "$SKIP_DEPS" = false ]; then
    echo -e "${BLUE}Step 5: Installing dependencies...${NC}"
    
    # PHP dependencies
    if command -v composer &> /dev/null; then
        if [ -d "php-app/vendor" ]; then
            echo -e "${YELLOW}  ⚠ PHP dependencies already installed - skipping${NC}"
        else
            echo -e "${BLUE}  → Installing PHP dependencies (this may take a few minutes)...${NC}"
            cd php-app
            composer install --no-dev --optimize-autoloader
            cd ..
            echo -e "${GREEN}  ✓ PHP dependencies installed${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ Skipping PHP dependencies (Composer not found)${NC}"
    fi
    
    # Python dependencies
    if command -v python3 &> /dev/null; then
        if [ -d "python-backend/.venv" ]; then
            echo -e "${YELLOW}  ⚠ Python virtual environment already exists - skipping${NC}"
        else
            echo -e "${BLUE}  → Creating Python virtual environment...${NC}"
            cd python-backend
            python3 -m venv .venv
            echo -e "${GREEN}  ✓ Created Python virtual environment${NC}"
            
            echo -e "${BLUE}  → Installing Python dependencies (this may take several minutes)...${NC}"
            .venv/bin/pip install --upgrade pip
            .venv/bin/pip install -r requirements.txt
            cd ..
            echo -e "${GREEN}  ✓ Python dependencies installed${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ Skipping Python dependencies (Python3 not found)${NC}"
    fi
else
    echo -e "${YELLOW}Step 5: Skipping dependency installation (--skip-deps flag)${NC}"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}=========================================================================${NC}"
echo -e "${BLUE}Setup Complete!${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""
echo -e "${YELLOW}Important:${NC} You still need to:"
echo ""
echo "  1. Edit .env files with your actual configuration:"
echo "     - php-app/.env"
echo "     - python-backend/.env"
echo ""
echo "  2. Configure external services:"
echo "     - PostgreSQL database"
echo "     - Redis server"
echo "     - MinIO object storage"
echo "     - Keycloak SSO"
echo ""
echo "  3. Run database migrations:"
echo "     psql -U transcription_user -d transcription_db -f database/schema.sql"
echo ""
echo "  4. Review the complete deployment checklist:"
echo "     cat DEPLOYMENT_CHECKLIST.md"
echo ""
echo "  5. Validate your setup:"
echo "     python3 validate-deployment.py"
echo ""
echo -e "See ${BLUE}docs/deployment.md${NC} for detailed deployment instructions."
echo ""
