"""
app/core/dependencies.py
------------------------
FastAPI dependency injectors shared across routes.

Plain-language explanation
--------------------------
FastAPI's "dependencies" are reusable functions that run before a route
handler.  We use them here to validate the internal API secret key so only
the PHP application can call the Python API.
"""
from __future__ import annotations

from fastapi import Header, HTTPException, status

from app.core.config import get_settings


async def verify_api_key(x_api_key: str = Header(...)) -> None:
    """
    Every request from the PHP app must include the header:
        X-Api-Key: <api_secret_key from .env>

    If the header is missing or wrong, we return 401 Unauthorized.
    This is a lightweight internal authentication layer – Keycloak handles
    end-user authentication, but we also want to make sure only trusted
    internal clients can call these Python endpoints.
    """
    settings = get_settings()
    if x_api_key != settings.api_secret_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )
