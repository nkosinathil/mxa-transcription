#!/usr/bin/env python3
"""
Production Environment Validation Script
-----------------------------------------
Validates that all required services and configurations are in place
before deploying the MXA Transcription application.

Usage:
    python validate-deployment.py

Exit codes:
    0 = All checks passed
    1 = One or more critical checks failed
"""
import os
import sys
from pathlib import Path
import subprocess
import socket
import urllib.request
import urllib.error


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_header(text):
    """Print a section header."""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'=' * 70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'=' * 70}{Colors.RESET}\n")


def print_check(name, passed, message=""):
    """Print a check result."""
    status = f"{Colors.GREEN}✓ PASS{Colors.RESET}" if passed else f"{Colors.RED}✗ FAIL{Colors.RESET}"
    print(f"  {status} {name}")
    if message:
        prefix = "    →" if passed else f"    {Colors.RED}→{Colors.RESET}"
        print(f"{prefix} {message}")


def check_file_exists(path, description):
    """Check if a file exists."""
    exists = Path(path).is_file()
    print_check(description, exists, path if exists else f"Not found: {path}")
    return exists


def check_dir_exists(path, description):
    """Check if a directory exists."""
    exists = Path(path).is_dir()
    print_check(description, exists, path if exists else f"Not found: {path}")
    return exists


def check_command_exists(command, description):
    """Check if a command is available."""
    try:
        subprocess.run([command, "--version"], capture_output=True, check=True)
        print_check(description, True, f"{command} is installed")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print_check(description, False, f"{command} not found in PATH")
        return False


def check_port_open(host, port, description):
    """Check if a port is open and listening."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)
    try:
        result = sock.connect_ex((host, port))
        is_open = result == 0
        print_check(description, is_open, 
                   f"{host}:{port} is {'reachable' if is_open else 'not reachable'}")
        return is_open
    except socket.error:
        print_check(description, False, f"Cannot connect to {host}:{port}")
        return False
    finally:
        sock.close()


def check_http_endpoint(url, description):
    """Check if an HTTP endpoint is reachable."""
    try:
        req = urllib.request.Request(url, method='GET')
        with urllib.request.urlopen(req, timeout=5) as response:
            is_ok = response.status == 200
            print_check(description, is_ok, f"{url} returned {response.status}")
            return is_ok
    except urllib.error.URLError as e:
        print_check(description, False, f"{url} - {str(e)}")
        return False
    except Exception as e:
        print_check(description, False, f"{url} - {str(e)}")
        return False


def check_env_file(path, required_vars, description):
    """Check if .env file exists and contains required variables."""
    if not Path(path).is_file():
        print_check(description, False, f"{path} not found")
        return False
    
    with open(path, 'r') as f:
        content = f.read()
    
    missing_vars = []
    placeholder_vars = []
    
    for var in required_vars:
        if var not in content:
            missing_vars.append(var)
        elif any(placeholder in content for placeholder in [
            'replace-with', 'your-', 'change-me', 'example'
        ]):
            # Check if this specific var has a placeholder
            for line in content.split('\n'):
                if line.startswith(f"{var}=") and any(
                    p in line.lower() for p in ['replace-with', 'your-', 'change-me', 'example']
                ):
                    placeholder_vars.append(var)
    
    if missing_vars:
        print_check(description, False, f"Missing variables: {', '.join(missing_vars)}")
        return False
    elif placeholder_vars:
        print_check(description, False, 
                   f"Placeholder values found: {', '.join(placeholder_vars)}")
        return False
    else:
        print_check(description, True, f"All {len(required_vars)} required variables set")
        return True


def main():
    """Run all validation checks."""
    print(f"{Colors.BOLD}MXA Transcription - Production Deployment Validation{Colors.RESET}")
    print(f"Timestamp: {subprocess.getoutput('date')}")
    
    all_passed = True
    critical_failed = False
    
    # Determine base path (assume script is in repo root)
    base_path = Path(__file__).parent
    
    # -------------------------------------------------------------------------
    # 1. Directory Structure
    # -------------------------------------------------------------------------
    print_header("1. Directory Structure")
    
    checks = [
        (check_dir_exists(base_path / "php-app", "PHP application directory"), True),
        (check_dir_exists(base_path / "python-backend", "Python backend directory"), True),
        (check_dir_exists(base_path / "database", "Database directory"), True),
        (check_dir_exists(base_path / "php-app/storage/logs", "PHP logs directory"), True),
        (check_file_exists(base_path / "php-app/storage/logs/.gitkeep", "Logs .gitkeep"), False),
    ]
    
    for passed, is_critical in checks:
        all_passed = all_passed and passed
        if not passed and is_critical:
            critical_failed = True
    
    # -------------------------------------------------------------------------
    # 2. Configuration Files
    # -------------------------------------------------------------------------
    print_header("2. Configuration Files")
    
    php_env_vars = [
        'APP_NAME', 'APP_ENV', 'APP_DEBUG', 'SESSION_SECRET',
        'DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASS',
        'KEYCLOAK_BASE_URL', 'KEYCLOAK_REALM', 'KEYCLOAK_CLIENT_ID',
        'PYTHON_API_BASE_URL', 'PYTHON_API_KEY',
        'MINIO_ENDPOINT', 'MINIO_ACCESS_KEY', 'MINIO_SECRET_KEY'
    ]
    
    python_env_vars = [
        'APP_NAME', 'DEBUG', 'API_SECRET_KEY',
        'REDIS_URL', 'POSTGRES_DSN',
        'MINIO_ENDPOINT', 'MINIO_ACCESS_KEY', 'MINIO_SECRET_KEY'
    ]
    
    checks = [
        (check_file_exists(base_path / "php-app/.env", "PHP .env file"), True),
        (check_file_exists(base_path / "python-backend/.env", "Python .env file"), True),
        (check_env_file(base_path / "php-app/.env", php_env_vars, "PHP .env variables") 
         if (base_path / "php-app/.env").is_file() else False, True),
        (check_env_file(base_path / "python-backend/.env", python_env_vars, "Python .env variables")
         if (base_path / "python-backend/.env").is_file() else False, True),
    ]
    
    for passed, is_critical in checks:
        all_passed = all_passed and passed
        if not passed and is_critical:
            critical_failed = True
    
    # -------------------------------------------------------------------------
    # 3. Dependencies
    # -------------------------------------------------------------------------
    print_header("3. Dependencies")
    
    checks = [
        (check_dir_exists(base_path / "php-app/vendor", "PHP dependencies (vendor/)"), True),
        (check_dir_exists(base_path / "python-backend/.venv", "Python virtual environment"), True),
        (check_command_exists("php", "PHP executable"), True),
        (check_command_exists("python3", "Python executable"), True),
        (check_command_exists("composer", "Composer"), False),
        (check_command_exists("ffmpeg", "FFmpeg"), True),
    ]
    
    for passed, is_critical in checks:
        all_passed = all_passed and passed
        if not passed and is_critical:
            critical_failed = True
    
    # -------------------------------------------------------------------------
    # 4. Database
    # -------------------------------------------------------------------------
    print_header("4. Database Files")
    
    migrations = [
        "001_create_users.sql",
        "002_create_cases.sql",
        "003_create_uploads.sql",
        "004_create_processing_jobs.sql",
        "005_create_job_events.sql",
        "006_create_results.sql",
        "007_create_exports.sql",
        "008_create_audit_logs.sql",
        "009_create_app_settings.sql",
    ]
    
    for migration in migrations:
        passed = check_file_exists(
            base_path / "database/migrations" / migration,
            f"Migration: {migration}"
        )
        all_passed = all_passed and passed
    
    # -------------------------------------------------------------------------
    # 5. Service Connectivity (Optional - may not work in all environments)
    # -------------------------------------------------------------------------
    print_header("5. Service Connectivity (Optional)")
    
    print(f"{Colors.YELLOW}Note: These checks may fail if not running on production servers{Colors.RESET}\n")
    
    # These are informational only, not critical
    check_port_open("localhost", 5432, "PostgreSQL (localhost:5432)")
    check_port_open("localhost", 6379, "Redis (localhost:6379)")
    check_port_open("localhost", 9000, "MinIO (localhost:9000)")
    
    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------
    print_header("Validation Summary")
    
    if critical_failed:
        print(f"{Colors.RED}{Colors.BOLD}✗ CRITICAL CHECKS FAILED{Colors.RESET}")
        print(f"{Colors.RED}The application is NOT ready for deployment.{Colors.RESET}")
        print(f"\nPlease address the issues above before deploying to production.")
        return 1
    elif not all_passed:
        print(f"{Colors.YELLOW}{Colors.BOLD}⚠ SOME CHECKS FAILED{Colors.RESET}")
        print(f"{Colors.YELLOW}Some non-critical checks failed.{Colors.RESET}")
        print(f"Review the failures above and ensure they are expected.")
        return 0
    else:
        print(f"{Colors.GREEN}{Colors.BOLD}✓ ALL CHECKS PASSED{Colors.RESET}")
        print(f"{Colors.GREEN}The application appears ready for deployment.{Colors.RESET}")
        print(f"\nNext steps:")
        print(f"  1. Review DEPLOYMENT_CHECKLIST.md")
        print(f"  2. Test on staging environment")
        print(f"  3. Complete security hardening")
        print(f"  4. Deploy to production")
        return 0


if __name__ == "__main__":
    sys.exit(main())
