"""
app/services/job_service.py
-----------------------------
Writes job events and status updates to PostgreSQL.

Plain-language explanation
--------------------------
When a Celery worker processes an audio file it emits progress messages
("Transcribing file 1/3…", "Running diarization…" etc.).  This service writes
those messages into the job_events table and updates the status/progress
columns in processing_jobs.  The PHP application reads these rows when the
user polls for progress.

We keep this service lightweight – it only does simple INSERT/UPDATE queries.
"""
from __future__ import annotations

import logging
from typing import Optional

import psycopg2
import psycopg2.extras

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def _get_connection():
    """Open a short-lived PostgreSQL connection."""
    settings = get_settings()
    if not settings.postgres_dsn:
        raise RuntimeError("POSTGRES_DSN is not configured in .env")
    return psycopg2.connect(settings.postgres_dsn)


class JobService:
    # ------------------------------------------------------------------
    # Job status updates
    # ------------------------------------------------------------------

    @staticmethod
    def set_status(job_id: int, status: str, progress: int = 0) -> None:
        """Update status and progress percentage for a job."""
        sql = """
            UPDATE processing_jobs
               SET status    = %s,
                   progress  = %s,
                   started_at   = CASE WHEN %s = 'processing' AND started_at IS NULL
                                       THEN NOW() ELSE started_at END,
                   completed_at = CASE WHEN %s IN ('completed','failed','cancelled')
                                       THEN NOW() ELSE completed_at END
             WHERE id = %s
        """
        try:
            with _get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(sql, (status, progress, status, status, job_id))
                conn.commit()
        except Exception as exc:
            logger.error("Failed to update job %d status: %s", job_id, exc)

    @staticmethod
    def set_celery_task_id(job_id: int, celery_task_id: str) -> None:
        """Store the Celery task UUID returned when the task is queued."""
        try:
            with _get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "UPDATE processing_jobs SET celery_task_id = %s WHERE id = %s",
                        (celery_task_id, job_id),
                    )
                conn.commit()
        except Exception as exc:
            logger.error("Failed to set celery_task_id for job %d: %s", job_id, exc)

    @staticmethod
    def set_error(job_id: int, message: str) -> None:
        """Mark a job as failed and store the error message."""
        try:
            with _get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """UPDATE processing_jobs
                              SET status = 'failed',
                                  error_message = %s,
                                  completed_at = NOW()
                            WHERE id = %s""",
                        (message, job_id),
                    )
                conn.commit()
        except Exception as exc:
            logger.error("Failed to set error for job %d: %s", job_id, exc)

    # ------------------------------------------------------------------
    # Job events
    # ------------------------------------------------------------------

    @staticmethod
    def add_event(
        job_id: int,
        message: str,
        event_type: str = "info",
    ) -> None:
        """Append a log event to job_events."""
        try:
            with _get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """INSERT INTO job_events (job_id, event_type, message)
                           VALUES (%s, %s, %s)""",
                        (job_id, event_type, message),
                    )
                conn.commit()
        except Exception as exc:
            logger.error("Failed to add event for job %d: %s", job_id, exc)

    # ------------------------------------------------------------------
    # Result writing
    # ------------------------------------------------------------------

    @staticmethod
    def save_result(
        job_id: int,
        minio_transcript_path: Optional[str],
        minio_json_path: Optional[str],
        minio_html_path: Optional[str],
        language: Optional[str],
        language_probability: Optional[float],
        duration_seconds: Optional[float],
        speaker_count: Optional[int],
        segment_count: int,
        diarization_available: bool,
        diarization_note: Optional[str],
    ) -> None:
        """Write the result record after a job completes."""
        sql = """
            INSERT INTO results (
                job_id, minio_transcript_path, minio_json_path, minio_html_path,
                language, language_probability, duration_seconds, speaker_count,
                segment_count, diarization_available, diarization_note
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (job_id) DO UPDATE SET
                minio_transcript_path  = EXCLUDED.minio_transcript_path,
                minio_json_path        = EXCLUDED.minio_json_path,
                minio_html_path        = EXCLUDED.minio_html_path,
                language               = EXCLUDED.language,
                language_probability   = EXCLUDED.language_probability,
                duration_seconds       = EXCLUDED.duration_seconds,
                speaker_count          = EXCLUDED.speaker_count,
                segment_count          = EXCLUDED.segment_count,
                diarization_available  = EXCLUDED.diarization_available,
                diarization_note       = EXCLUDED.diarization_note
        """
        try:
            with _get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(sql, (
                        job_id, minio_transcript_path, minio_json_path, minio_html_path,
                        language, language_probability, duration_seconds, speaker_count,
                        segment_count, diarization_available, diarization_note,
                    ))
                conn.commit()
        except Exception as exc:
            logger.error("Failed to save result for job %d: %s", job_id, exc)
