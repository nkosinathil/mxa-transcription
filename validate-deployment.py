#!/usr/bin/env python3
"""
validate-deployment.py — Pre-deployment configuration checks for MXA Transcription.

Run this script on each server before starting the services to verify that all
required environment variables and external dependencies are reachable.

Usage:
    python3 validate-deployment.py --role php       # on 192.168.1.66
    python3 validate-deployment.py --role python     # on 192.168.1.90
    python3 validate-deployment.py --role keycloak   # on 192.168.1.59
    python3 validate-deployment.py --role all        # check everything from one host
"""
from __future__ import annotations

import argparse
import os
import socket
import sys
import urllib.request
import urllib.error
from pathlib import Path
from typing import Callable


PASS = "\033[32m✔\033[0m"
FAIL = "\033[31m✘\033[0m"
WARN = "\033[33m⚠\033[0m"

failures: list[str] = []


def check(label: str, fn: Callable[[], bool | str], warn_only: bool = False) -> None:
    """Run a single check and print the result."""
    try:
        result = fn()
        ok = result is True or (isinstance(result, str) and result)
        if ok:
            detail = f" ({result})" if isinstance(result, str) else ""
            print(f"  {PASS} {label}{detail}")
        else:
            icon = WARN if warn_only else FAIL
            print(f"  {icon} {label}")
            if not warn_only:
                failures.append(label)
    except Exception as exc:
        icon = WARN if warn_only else FAIL
        print(f"  {icon} {label}: {exc}")
        if not warn_only:
            failures.append(label)


def env(key: str, *, required: bool = True) -> str | None:
    """Return env var value; record failure if required and missing."""
    val = os.getenv(key)
    if required and not val:
        failures.append(f"env {key} not set")
        print(f"  {FAIL} ${key} not set")
    return val


def tcp_reachable(host: str, port: int, timeout: float = 3.0) -> bool:
    """Return True if a TCP connection can be established."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def http_ok(url: str, timeout: float = 5.0) -> str:
    """Return HTTP status code string; raise on connection error."""
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return str(resp.status)
    except urllib.error.HTTPError as exc:
        return str(exc.code)


# ---------------------------------------------------------------------------
# Role-specific checks
# ---------------------------------------------------------------------------

def check_php_role() -> None:
    print("\n── PHP Frontend (192.168.1.66) ──────────────────────")

    env_file = Path(__file__).parent / "php-app/.env"
    check(".env file exists", lambda: env_file.exists())

    # Load .env for value checks
    if env_file.exists():
        loaded: dict[str, str] = {}
        for line in env_file.read_text().splitlines():
            if line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            loaded[k.strip()] = v.strip().strip("\"'")

        for key in ("DB_PASSWORD", "API_SECRET_KEY", "KEYCLOAK_CLIENT_SECRET"):
            val = loaded.get(key, "")
            check(
                f"{key} is not a placeholder",
                lambda v=val: bool(v) and v not in ("change_this_password", "change-this-in-production", "your_keycloak_client_secret_here"),
            )

    check("PostgreSQL reachable (localhost:5432)", lambda: tcp_reachable("localhost", 5432))
    check("Python API reachable (192.168.1.90:8000)", lambda: tcp_reachable("192.168.1.90", 8000))
    check("Keycloak reachable (192.168.1.59:8080)", lambda: tcp_reachable("192.168.1.59", 8080))
    check("Apache mod_rewrite config present", lambda: Path("/etc/apache2/sites-enabled").exists(), warn_only=True)


def check_python_role() -> None:
    print("\n── Python Backend (192.168.1.90) ────────────────────")

    env_file = Path(__file__).parent / "python-backend/.env"
    check(".env file exists", lambda: env_file.exists())

    if env_file.exists():
        loaded: dict[str, str] = {}
        for line in env_file.read_text().splitlines():
            if line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            loaded[k.strip()] = v.strip().strip("\"'")

        for key in ("API_SECRET_KEY", "MINIO_ACCESS_KEY", "MINIO_SECRET_KEY"):
            val = loaded.get(key, "")
            check(
                f"{key} is not a placeholder",
                lambda v=val: bool(v) and v not in ("change-this-in-production", "minioadmin"),
            )

        hf = loaded.get("HUGGINGFACE_TOKEN", "")
        check("HUGGINGFACE_TOKEN set (for diarization)", lambda: bool(hf) and hf != "your_huggingface_token_here", warn_only=True)

    check("Redis reachable (localhost:6379)", lambda: tcp_reachable("localhost", 6379))
    check("MinIO reachable (localhost:9000)", lambda: tcp_reachable("localhost", 9000))

    # Check FastAPI health endpoint (if already running)
    check("FastAPI health endpoint", lambda: http_ok("http://localhost:8000/health") == "200", warn_only=True)

    # Python imports
    for pkg in ("fastapi", "celery", "minio", "faster_whisper"):
        check(f"Python package '{pkg}' importable", lambda p=pkg: __import__(p) is not None, warn_only=True)


def check_keycloak_role() -> None:
    print("\n── Keycloak SSO (192.168.1.59) ──────────────────────")
    check("Keycloak process listening on port 8080", lambda: tcp_reachable("localhost", 8080))
    check("Keycloak admin console HTTP 200/302", lambda: http_ok("http://localhost:8080/") in ("200", "302", "303"), warn_only=True)
    check("Java available", lambda: bool(__import__("shutil").which("java")))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="MXA Transcription deployment validator")
    parser.add_argument(
        "--role",
        choices=["php", "python", "keycloak", "all"],
        default="all",
        help="Which server role to validate (default: all)",
    )
    args = parser.parse_args()

    print("MXA Transcription — Deployment Validation")
    print("==========================================")

    if args.role in ("php", "all"):
        check_php_role()
    if args.role in ("python", "all"):
        check_python_role()
    if args.role in ("keycloak", "all"):
        check_keycloak_role()

    print()
    if failures:
        print(f"{FAIL} {len(failures)} check(s) failed:")
        for f in failures:
            print(f"    • {f}")
        sys.exit(1)
    else:
        print(f"{PASS} All checks passed — ready to deploy!")


if __name__ == "__main__":
    main()
