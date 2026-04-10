"""
app/api/status.py
------------------
Job status and result retrieval endpoints.

Plain-language explanation
--------------------------
These two endpoints are called repeatedly by the PHP app while a job is
running (polling) and once more when it completes.

GET /job/{job_id}/status  – lightweight, called every few seconds
GET /job/{job_id}/result  – full result, called once after completion

The PHP app displays a progress bar and live event log based on the
/status response.  When the job is marked "completed", the UI switches
to showing the transcript.
"""
from __future__ import annotations

import logging
from typing import Optional

import psycopg2
import psycopg2.extras

from fastapi import APIRouter, Depends, HTTPException, status as http_status

from app.core.config import get_settings
from app.core.dependencies import verify_api_key
from app.models.schemas import (
    EventType,
    JobEvent,
    JobResultResponse,
    JobStatus,
    JobStatusResponse,
    SegmentResult,
)

logger = logging.getLogger(__name__)
router = APIRouter()


def _get_db():
    settings = get_settings()
    if not settings.postgres_dsn:
        raise HTTPException(
            status_code=http_status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database not configured on Python server",
        )
    return psycopg2.connect(settings.postgres_dsn, cursor_factory=psycopg2.extras.RealDictCursor)


@router.get(
    "/job/{job_id}/status",
    response_model=JobStatusResponse,
    tags=["jobs"],
    dependencies=[Depends(verify_api_key)],
)
async def get_job_status(job_id: int) -> JobStatusResponse:
    """
    Return the current status and recent log events for a job.
    Called by PHP every few seconds while processing is underway.
    """
    with _get_db() as conn:
        with conn.cursor() as cur:
            # Fetch job row
            cur.execute(
                """SELECT id, celery_task_id, status, progress, error_message
                     FROM processing_jobs WHERE id = %s""",
                (job_id,),
            )
            job = cur.fetchone()
            if not job:
                raise HTTPException(
                    status_code=http_status.HTTP_404_NOT_FOUND,
                    detail=f"Job {job_id} not found",
                )

            # Fetch recent events (last 50)
            cur.execute(
                """SELECT event_type, message, created_at
                     FROM job_events
                    WHERE job_id = %s
                    ORDER BY created_at DESC
                    LIMIT 50""",
                (job_id,),
            )
            raw_events = cur.fetchall()

    events = [
        JobEvent(
            event_type=EventType(row["event_type"]),
            message=row["message"],
            created_at=row["created_at"],
        )
        for row in reversed(raw_events)     # chronological order
    ]

    return JobStatusResponse(
        job_id=job["id"],
        celery_task_id=job["celery_task_id"],
        status=JobStatus(job["status"]),
        progress=job["progress"],
        events=events,
        error_message=job["error_message"],
    )


@router.get(
    "/job/{job_id}/result",
    response_model=JobResultResponse,
    tags=["jobs"],
    dependencies=[Depends(verify_api_key)],
)
async def get_job_result(job_id: int) -> JobResultResponse:
    """
    Return the full result of a completed job, including transcript segments.
    The PHP app calls this once the /status endpoint reports 'completed'.
    """
    import json as _json

    from app.services.minio_service import MinioService
    settings = get_settings()

    with _get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT j.id, j.celery_task_id, j.status, j.error_message,
                          r.language, r.language_probability, r.duration_seconds,
                          r.speaker_count, r.diarization_available, r.diarization_note,
                          r.minio_transcript_path, r.minio_json_path, r.minio_html_path,
                          r.created_at
                     FROM processing_jobs j
                LEFT JOIN results r ON r.job_id = j.id
                    WHERE j.id = %s""",
                (job_id,),
            )
            row = cur.fetchone()

    if not row:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )

    # Load transcript segments from the JSON file stored in MinIO
    segments: list[SegmentResult] = []
    if row["minio_json_path"] and row["status"] == "completed":
        try:
            minio = MinioService()
            raw = minio.get_bytes(settings.minio_results_bucket, row["minio_json_path"])
            payload = _json.loads(raw)
            segments = [
                SegmentResult(
                    start=seg["start"],
                    end=seg["end"],
                    text=seg["text"],
                    speaker=seg.get("speaker", "Speaker 1"),
                )
                for seg in payload.get("segments", [])
            ]
        except Exception as exc:
            logger.warning("Could not load segments for job %d: %s", job_id, exc)

    return JobResultResponse(
        job_id=row["id"],
        celery_task_id=row["celery_task_id"],
        status=JobStatus(row["status"]),
        language=row["language"],
        language_probability=row["language_probability"],
        duration_seconds=float(row["duration_seconds"]) if row["duration_seconds"] else None,
        speaker_count=row["speaker_count"],
        diarization_available=bool(row["diarization_available"]) if row["diarization_available"] is not None else False,
        diarization_note=row["diarization_note"],
        segments=segments,
        minio_transcript_path=row["minio_transcript_path"],
        minio_json_path=row["minio_json_path"],
        minio_html_path=row["minio_html_path"],
        error_message=row["error_message"],
        created_at=row["created_at"],
    )
