"""
app/api/process.py
-------------------
Endpoint to queue a transcription job.

Plain-language explanation
--------------------------
After a file is uploaded to MinIO and its path recorded in PostgreSQL, the PHP
app calls this endpoint to start processing.  We queue a Celery task and
immediately return the task ID.  The actual transcription happens in the
background; the PHP app polls the /status endpoint to check progress.

This is the key async pattern:
  PHP → POST /process → Python queues Celery task → returns celery_task_id
  PHP → GET /job/{id}/status (every few seconds) → gets current progress
  PHP → GET /job/{id}/result (when complete) → gets transcript
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import verify_api_key
from app.models.schemas import JobStatus, ProcessRequest, ProcessResponse
from app.services.job_service import JobService
from app.tasks.transcription_tasks import transcribe_audio

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/process",
    response_model=ProcessResponse,
    status_code=status.HTTP_202_ACCEPTED,
    tags=["processing"],
    dependencies=[Depends(verify_api_key)],
)
async def start_processing(req: ProcessRequest) -> ProcessResponse:
    """
    Queue a transcription job for a previously uploaded audio file.

    The caller (PHP app) must have already:
    - Uploaded the file via POST /upload
    - Created a processing_jobs row in PostgreSQL (status='queued')
    - Passed us the resulting job_id

    We queue the Celery task and return the celery_task_id so PHP can
    store it in processing_jobs.celery_task_id for future status queries.
    """
    try:
        task = transcribe_audio.apply_async(
            kwargs={
                "job_id": req.job_id,
                "minio_bucket": req.minio_bucket,
                "minio_path": req.minio_path,
                "original_filename": req.original_filename,
                "model_size": req.model_size,
                "device": req.device,
                "compute_type": req.compute_type,
                "diarization_enabled": req.diarization_enabled,
            }
        )
    except Exception as exc:
        logger.error("Failed to queue job %d: %s", req.job_id, exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to queue processing task: {exc}",
        )

    # Store the task ID in PostgreSQL so PHP can query it directly
    JobService.set_celery_task_id(req.job_id, task.id)

    logger.info("Queued Celery task %s for job %d", task.id, req.job_id)

    return ProcessResponse(
        job_id=req.job_id,
        celery_task_id=task.id,
        status=JobStatus.queued,
    )
