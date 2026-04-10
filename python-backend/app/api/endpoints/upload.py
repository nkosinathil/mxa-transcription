"""
File upload endpoints
"""
from __future__ import annotations

import hashlib
import logging
from pathlib import Path
from typing import Any, Dict

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.core.config import settings
from app.core.dependencies import verify_api_key
from app.core.storage import storage
from app.tasks.transcription_tasks import transcribe_audio_task

router = APIRouter()
logger = logging.getLogger(__name__)


async def validate_audio_file(file: UploadFile) -> None:
    """Validate uploaded audio file extension and declared size."""
    file_ext = Path(file.filename or "").suffix.lower()
    if file_ext not in settings.ALLOWED_AUDIO_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Invalid file type '{file_ext}'. "
                f"Allowed: {', '.join(settings.ALLOWED_AUDIO_EXTENSIONS)}"
            ),
        )
    if file.size and file.size > settings.MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"File too large. "
                f"Maximum size: {settings.MAX_UPLOAD_SIZE / (1024 * 1024):.0f} MB"
            ),
        )


@router.post("/", response_model=Dict[str, Any])
async def upload_audio(
    file: UploadFile = File(...),
    job_id: str = ...,
    api_key: str = Depends(verify_api_key),
) -> Dict[str, Any]:
    """
    Receive an audio file, persist it in MinIO, and queue a Celery transcription task.

    Args:
        file:    Audio file to transcribe.
        job_id:  UUID of the pre-created job record (from the PHP frontend).
        api_key: Verified via X-Api-Key header.

    Returns:
        JSON payload with job_id, task_id, and initial status.
    """
    await validate_audio_file(file)

    try:
        content: bytes = await file.read()
        file_size = len(content)

        # Guard against declared-size bypass
        if file_size > settings.MAX_UPLOAD_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File too large. Maximum size: {settings.MAX_UPLOAD_SIZE / (1024 * 1024):.0f} MB",
            )

        file_hash = hashlib.sha256(content).hexdigest()
        filename = file.filename or f"{job_id}.audio"

        # Persist in MinIO
        minio_path = storage.upload_audio(job_id, filename, content)
        logger.info("Stored audio %s -> %s", filename, minio_path)

        # Queue Celery task
        task = transcribe_audio_task.delay(
            job_id=job_id,
            filename=filename,
            file_hash=file_hash,
            minio_path=minio_path,
        )
        logger.info("Queued transcription task %s for job %s", task.id, job_id)

        return {
            "success": True,
            "job_id": job_id,
            "task_id": task.id,
            "filename": filename,
            "file_size": file_size,
            "file_hash": file_hash,
            "minio_path": minio_path,
            "status": "queued",
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Upload failed for job %s: %s", job_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Upload failed: {exc}",
        )
