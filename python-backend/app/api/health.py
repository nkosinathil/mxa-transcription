"""
app/api/health.py
------------------
Health check endpoint.

Plain-language explanation
--------------------------
This endpoint lets monitoring tools (or the PHP app) quickly verify that the
Python API is running.  It returns the application version and a timestamp.
No authentication is required for health checks.
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter

from app.core.config import get_settings
from app.models.schemas import HealthResponse

router = APIRouter()
settings = get_settings()


@router.get("/health", response_model=HealthResponse, tags=["system"])
async def health_check() -> HealthResponse:
    """Returns service health status."""
    return HealthResponse(
        status="ok",
        version=settings.app_version,
        timestamp=datetime.now(tz=timezone.utc),
    )
