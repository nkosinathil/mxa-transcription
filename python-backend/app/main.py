"""
app/main.py
------------
FastAPI application entry point.

Plain-language explanation
--------------------------
This is the "front door" of the Python API.  When you start the server with
  uvicorn app.main:app --host 0.0.0.0 --port 8000
FastAPI reads this file, registers all the route modules, and begins
listening for incoming HTTP requests from the PHP application.

The /api prefix keeps all routes under a common path so they are easy to
proxy via Apache or nginx.
"""
from __future__ import annotations

import logging
import logging.config

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import health, process, status, upload
from app.core.config import get_settings

settings = get_settings()

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    docs_url="/docs" if settings.debug else None,   # disable Swagger in production
    redoc_url=None,
    openapi_url="/openapi.json" if settings.debug else None,
)

# ---------------------------------------------------------------------------
# CORS – allow the PHP application server to call this API
# In production, restrict origins to the exact PHP server hostname.
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
app.include_router(health.router,  prefix="/api")
app.include_router(upload.router,  prefix="/api")
app.include_router(process.router, prefix="/api")
app.include_router(status.router,  prefix="/api")


# ---------------------------------------------------------------------------
# Global exception handler
# ---------------------------------------------------------------------------
@app.exception_handler(Exception)
async def global_exception_handler(request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


@app.on_event("startup")
async def startup() -> None:
    logger.info("%s v%s starting up", settings.app_name, settings.app_version)
