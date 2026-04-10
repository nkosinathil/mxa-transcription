"""
Transcript retrieval endpoints
"""
from __future__ import annotations

import logging
from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import PlainTextResponse
from minio.error import S3Error

from app.core.dependencies import verify_api_key
from app.core.storage import storage

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/{job_id}/json", response_model=Dict[str, Any])
async def get_transcript_json(
    job_id: str,
    api_key: str = Depends(verify_api_key),
) -> Dict[str, Any]:
    """
    Return the JSON transcript for a completed job.

    Args:
        job_id:  Job UUID.
        api_key: Verified via X-Api-Key header.

    Returns:
        Transcript data (segments with speaker labels, metadata, etc.).
    """
    try:
        return storage.get_transcript_json(job_id)
    except S3Error as exc:
        if exc.code in ("NoSuchKey", "NoSuchBucket"):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transcript not found")
        logger.error("MinIO error retrieving JSON transcript job=%s: %s", job_id, exc)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Storage error")
    except Exception as exc:
        logger.error("Error retrieving JSON transcript job=%s: %s", job_id, exc, exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to retrieve transcript")


@router.get("/{job_id}/txt", response_class=PlainTextResponse)
async def get_transcript_txt(
    job_id: str,
    api_key: str = Depends(verify_api_key),
) -> str:
    """
    Return the plain-text transcript for a completed job.

    Args:
        job_id:  Job UUID.
        api_key: Verified via X-Api-Key header.

    Returns:
        Transcript as plain text with ``[Speaker N] text`` lines.
    """
    try:
        return storage.get_transcript_txt(job_id)
    except S3Error as exc:
        if exc.code in ("NoSuchKey", "NoSuchBucket"):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transcript not found")
        logger.error("MinIO error retrieving TXT transcript job=%s: %s", job_id, exc)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Storage error")
    except Exception as exc:
        logger.error("Error retrieving TXT transcript job=%s: %s", job_id, exc, exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to retrieve transcript")
