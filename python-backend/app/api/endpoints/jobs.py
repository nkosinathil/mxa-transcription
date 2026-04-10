"""
Job status endpoints
"""
from __future__ import annotations

import logging
from typing import Any, Dict

from celery.result import AsyncResult
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import verify_api_key
from app.core.storage import storage
from app.tasks.celery_app import celery_app

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/{job_id}/status", response_model=Dict[str, Any])
async def get_job_status(
    job_id: str,
    api_key: str = Depends(verify_api_key),
) -> Dict[str, Any]:
    """
    Return the current status of a transcription job.

    The PHP frontend polls this endpoint to update the database record and
    display live progress to the user.

    Args:
        job_id:  Job UUID. Treated as the Celery task ID for now.
        api_key: Verified via X-Api-Key header.

    Returns:
        Status payload including progress metadata when available.
    """
    try:
        result = AsyncResult(job_id, app=celery_app)

        response: Dict[str, Any] = {
            "job_id": job_id,
            "state": result.state,
            "ready": result.ready(),
        }

        if result.ready():
            response["successful"] = result.successful()
            if result.successful():
                response["result"] = result.result
            else:
                response["error"] = str(result.info)
        elif result.state == "STARTED":
            # Progress metadata injected by the task via update_state()
            response["meta"] = result.info or {}

        return response

    except Exception as exc:
        logger.error("get_job_status failed  job=%s: %s", job_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve job status",
        )


@router.get("/{job_id}", response_model=Dict[str, Any])
async def get_job_details(
    job_id: str,
    api_key: str = Depends(verify_api_key),
) -> Dict[str, Any]:
    """
    Return detailed information about a job including transcript availability.

    Args:
        job_id:  Job UUID.
        api_key: Verified via X-Api-Key header.

    Returns:
        Status payload enriched with transcript availability flags.
    """
    base = await get_job_status(job_id, api_key)
    base["transcript_available"] = storage.transcript_exists(job_id)
    return base
