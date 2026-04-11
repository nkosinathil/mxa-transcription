"""
app/models/schemas.py
----------------------
Pydantic models for request validation and response serialisation.

Plain-language explanation
--------------------------
Pydantic models define the shape of data going in and out of the API.
FastAPI uses them to validate incoming JSON, convert types, and generate
automatic API documentation.  Think of them as typed contracts between
the PHP frontend and the Python backend.
"""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class JobStatus(str, Enum):
    queued = "queued"
    processing = "processing"
    completed = "completed"
    failed = "failed"
    cancelled = "cancelled"


class EventType(str, Enum):
    info = "info"
    warning = "warning"
    error = "error"
    progress = "progress"


# ---------------------------------------------------------------------------
# Request models (inbound from PHP)
# ---------------------------------------------------------------------------

class ProcessRequest(BaseModel):
    """Sent by PHP to start a transcription job."""
    job_id: int = Field(..., description="processing_jobs.id in PostgreSQL")
    minio_bucket: str = Field(..., description="MinIO bucket containing the audio file")
    minio_path: str = Field(..., description="Object key of the audio file in MinIO")
    original_filename: str = Field(..., description="Human-readable file name for logs")
    model_size: str = Field(default="base", description="Faster-Whisper model size")
    device: str = Field(default="auto", description="auto, cpu, or cuda")
    compute_type: Optional[str] = Field(default=None, description="Whisper compute type override")
    diarization_enabled: bool = Field(default=True, description="Enable speaker diarization")


# ---------------------------------------------------------------------------
# Response models (outbound to PHP)
# ---------------------------------------------------------------------------

class HealthResponse(BaseModel):
    status: str
    version: str
    timestamp: datetime


class UploadResponse(BaseModel):
    minio_bucket: str
    minio_path: str
    size_bytes: int
    sha256: str
    original_filename: str


class ProcessResponse(BaseModel):
    """Returned immediately when a job is queued."""
    job_id: int
    celery_task_id: str
    status: JobStatus


class JobEvent(BaseModel):
    event_type: EventType
    message: str
    created_at: datetime


class JobStatusResponse(BaseModel):
    """Returned on every poll request."""
    job_id: int
    celery_task_id: Optional[str]
    status: JobStatus
    progress: int
    events: list[JobEvent] = []
    error_message: Optional[str] = None


class SegmentResult(BaseModel):
    start: float
    end: float
    text: str
    speaker: str = "Speaker 1"


class JobResultResponse(BaseModel):
    """Full result returned when a job completes."""
    job_id: int
    celery_task_id: Optional[str] = None
    status: JobStatus
    language: Optional[str]
    language_probability: Optional[float]
    duration_seconds: Optional[float]
    speaker_count: Optional[int]
    diarization_available: bool
    diarization_note: Optional[str]
    segments: list[SegmentResult] = []
    transcript_text: Optional[str] = None
    minio_transcript_path: Optional[str]
    minio_json_path: Optional[str]
    minio_html_path: Optional[str]
    created_at: Optional[datetime]


class ErrorResponse(BaseModel):
    detail: str
    extra: Optional[Any] = None
