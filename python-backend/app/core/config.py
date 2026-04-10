"""
app/core/config.py
------------------
Centralised configuration loaded from environment variables.

All settings that change between environments (dev / staging / production)
are read from .env via python-dotenv.  Secrets must NEVER be hardcoded here.

Plain-language explanation
--------------------------
Think of this file as the application's "settings panel". Every piece of
information that is environment-specific (database URL, MinIO credentials,
Redis URL, etc.) comes from this file.  You configure these by editing the
.env file on the server – you never touch the code itself.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ------------------------------------------------------------------
    # Application
    # ------------------------------------------------------------------
    app_name: str = "MXA Transcription API"
    app_version: str = "1.0.0"
    debug: bool = False
    log_level: str = "INFO"

    # ------------------------------------------------------------------
    # Internal API security
    # An API key shared between the PHP app and the Python API so that
    # random internet users cannot call the Python endpoints directly.
    # ------------------------------------------------------------------
    api_secret_key: str = "change-me-in-production"

    # ------------------------------------------------------------------
    # Redis (Celery broker + result backend)
    # ------------------------------------------------------------------
    redis_url: str = "redis://localhost:6379/0"

    # ------------------------------------------------------------------
    # MinIO / S3-compatible object storage
    # ------------------------------------------------------------------
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_secure: bool = False                  # set True for HTTPS
    minio_audio_bucket: str = "audio-uploads"
    minio_results_bucket: str = "transcription-results"
    minio_exports_bucket: str = "exports"

    # ------------------------------------------------------------------
    # PostgreSQL (used by PHP app; Python only needs it for job event writes)
    # ------------------------------------------------------------------
    postgres_dsn: Optional[str] = None          # e.g. postgresql://user:pass@host/db

    # ------------------------------------------------------------------
    # HuggingFace token (required for speaker diarization via pyannote)
    # ------------------------------------------------------------------
    huggingface_token: Optional[str] = None

    # ------------------------------------------------------------------
    # Default processing options
    # ------------------------------------------------------------------
    default_model_size: str = "base"
    default_device: str = "auto"
    max_upload_bytes: int = 524_288_000         # 500 MB


@lru_cache
def get_settings() -> Settings:
    """Return the cached Settings singleton."""
    return Settings()
