"""
API router for MXA Transcription
"""
from fastapi import APIRouter

from app.api.endpoints import upload, jobs, transcripts

api_router = APIRouter()

# Include endpoint routers
api_router.include_router(upload.router, prefix="/upload", tags=["upload"])
api_router.include_router(jobs.router, prefix="/jobs", tags=["jobs"])
api_router.include_router(transcripts.router, prefix="/transcripts", tags=["transcripts"])
