"""
app/tasks/transcription_tasks.py
----------------------------------
Celery task that performs the heavy audio transcription work.

Plain-language explanation
--------------------------
This is the "engine room" of the web application.  When a user clicks
"Start Processing", the PHP app sends a request to the Python API which calls
celery_app.send_task(...).  That drops a message into Redis.  One of the
Celery worker processes picks it up and calls the transcribe_audio function
below.  It:

  1. Downloads the audio file from MinIO to a temporary local file.
  2. Runs the existing TranscriptionEngine (Faster-Whisper).
  3. Runs the SpeakerDiarizer if enabled.
  4. Assigns speakers to transcript segments.
  5. Uploads the result files back to MinIO.
  6. Writes the result metadata to PostgreSQL via JobService.
  7. Updates the job status so PHP knows the job is done.

The key design principle is that all the complex ML logic is unchanged from
the original audio_pipeline code – we just wrapped it in a Celery task and
replaced the local file output with MinIO uploads.
"""
from __future__ import annotations

import json
import logging
import os
import tempfile
from pathlib import Path

from app.core.celery_app import celery_app
from app.core.config import get_settings
from app.legacy_logic.diarization import SpeakerDiarizer, assign_speakers_to_transcript
from app.legacy_logic.transcription import ALLOWED_LANGUAGES, TranscriptionEngine
from app.legacy_logic.utils import safe_slug
from app.services.job_service import JobService
from app.services.minio_service import MinioService

logger = logging.getLogger(__name__)


def _emit(job_id: int, message: str, event_type: str = "info") -> None:
    """Helper to log a message and write it to the job_events table."""
    logger.info("[job %d] %s", job_id, message)
    JobService.add_event(job_id, message, event_type)


@celery_app.task(
    name="transcription.transcribe_audio",
    bind=True,
    max_retries=0,          # do not auto-retry; let the job be marked failed
    acks_late=True,
)
def transcribe_audio(
    self,
    job_id: int,
    minio_bucket: str,
    minio_path: str,
    original_filename: str,
    model_size: str = "base",
    device: str = "auto",
    compute_type: str | None = None,
    diarization_enabled: bool = True,
) -> dict:
    """
    Main Celery task: transcribe one audio file.

    Parameters
    ----------
    job_id            : processing_jobs.id in PostgreSQL
    minio_bucket      : MinIO bucket containing the audio file
    minio_path        : Object key of the audio file
    original_filename : Human-readable file name for logs and output naming
    model_size        : Faster-Whisper model size (tiny/base/small/medium/large-v3)
    device            : Inference device (auto/cpu/cuda)
    compute_type      : Optional override for Whisper compute type
    diarization_enabled: Whether to run speaker diarization

    Returns
    -------
    dict summarising the result (also written to PostgreSQL / MinIO)
    """
    settings = get_settings()
    minio = MinioService()

    JobService.set_status(job_id, "processing", progress=0)
    _emit(job_id, f"Task started for: {original_filename}")

    stem = safe_slug(Path(original_filename).stem)
    results_bucket = settings.minio_results_bucket

    with tempfile.TemporaryDirectory(prefix="transcription_") as tmpdir:
        tmp = Path(tmpdir)

        # ------------------------------------------------------------------
        # 1. Download audio from MinIO
        # ------------------------------------------------------------------
        suffix = Path(original_filename).suffix or ".wav"
        local_audio = tmp / f"audio{suffix}"
        _emit(job_id, "Downloading audio file from storage…")
        try:
            minio.download_to_path(minio_bucket, minio_path, local_audio)
        except Exception as exc:
            _emit(job_id, f"Failed to download audio: {exc}", "error")
            JobService.set_error(job_id, str(exc))
            raise

        JobService.set_status(job_id, "processing", progress=10)
        _emit(job_id, "Audio downloaded. Starting transcription…")

        # ------------------------------------------------------------------
        # 2. Transcribe with Faster-Whisper
        # ------------------------------------------------------------------
        try:
            engine = TranscriptionEngine(
                model_size=model_size,
                device=device,
                compute_type=compute_type,
            )
            tx = engine.transcribe(local_audio)
        except Exception as exc:
            _emit(job_id, f"Transcription failed: {exc}", "error")
            JobService.set_error(job_id, str(exc))
            raise

        language = tx.get("language")
        language_probability = tx.get("language_probability")
        duration = tx.get("duration")

        JobService.set_status(job_id, "processing", progress=50)
        _emit(job_id, f"Transcription complete. Language detected: {language}")

        # ------------------------------------------------------------------
        # 3. Language filter (same as original pipeline)
        # ------------------------------------------------------------------
        if language not in ALLOWED_LANGUAGES:
            note = (
                f"Detected language '{language}' is not supported. "
                f"Supported: {', '.join(sorted(ALLOWED_LANGUAGES))}."
            )
            _emit(job_id, note, "warning")
            JobService.set_status(job_id, "completed", progress=100)
            JobService.save_result(
                job_id=job_id,
                minio_transcript_path=None,
                minio_json_path=None,
                minio_html_path=None,
                language=language,
                language_probability=language_probability,
                duration_seconds=duration,
                speaker_count=0,
                segment_count=0,
                diarization_available=False,
                diarization_note=note,
            )
            return {"status": "completed", "language": language, "note": note}

        # ------------------------------------------------------------------
        # 4. Speaker diarization
        # ------------------------------------------------------------------
        _emit(job_id, "Running speaker diarization…")
        try:
            diarizer = SpeakerDiarizer(enabled=diarization_enabled)
            diarization = diarizer.diarize(str(local_audio))
        except Exception as exc:
            _emit(job_id, f"Diarization error (non-fatal): {exc}", "warning")
            diarization = {"available": False, "speaker_segments": [], "note": str(exc)}

        segments = assign_speakers_to_transcript(
            tx.get("segments", []),
            diarization.get("speaker_segments", []),
        )
        speaker_labels = sorted({seg.get("speaker", "Speaker 1") for seg in segments})
        speaker_count = len(speaker_labels) if speaker_labels else diarization.get("speaker_count", 1)

        JobService.set_status(job_id, "processing", progress=80)
        _emit(job_id, f"Diarization complete. Speakers detected: {speaker_count}")

        # ------------------------------------------------------------------
        # 5. Build result payload
        # ------------------------------------------------------------------
        result_payload = {
            "job_id": job_id,
            "filename": original_filename,
            "language": language,
            "language_probability": language_probability,
            "duration": duration,
            "speaker_count": speaker_count,
            "diarization_available": diarization.get("available", False),
            "diarization_note": diarization.get("note"),
            "segments": segments,
        }

        # ------------------------------------------------------------------
        # 6. Upload results to MinIO
        # ------------------------------------------------------------------
        _emit(job_id, "Uploading results to storage…")

        txt_content = "\n".join(
            f"[{seg['speaker']}] {seg['text']}" for seg in segments
        ).encode("utf-8")
        json_content = json.dumps(result_payload, indent=2, ensure_ascii=False).encode("utf-8")

        minio_txt_path = f"{stem}/{job_id}/transcript.txt"
        minio_json_path = f"{stem}/{job_id}/result.json"

        minio.upload_bytes(results_bucket, minio_txt_path, txt_content, "text/plain; charset=utf-8")
        minio.upload_bytes(results_bucket, minio_json_path, json_content, "application/json")

        # ------------------------------------------------------------------
        # 7. Write result to PostgreSQL
        # ------------------------------------------------------------------
        JobService.save_result(
            job_id=job_id,
            minio_transcript_path=minio_txt_path,
            minio_json_path=minio_json_path,
            minio_html_path=None,
            language=language,
            language_probability=language_probability,
            duration_seconds=duration,
            speaker_count=speaker_count,
            segment_count=len(segments),
            diarization_available=diarization.get("available", False),
            diarization_note=diarization.get("note"),
        )

        JobService.set_status(job_id, "completed", progress=100)
        _emit(job_id, f"Job {job_id} completed successfully.")

        return {
            "status": "completed",
            "job_id": job_id,
            "language": language,
            "speaker_count": speaker_count,
            "segment_count": len(segments),
        }
