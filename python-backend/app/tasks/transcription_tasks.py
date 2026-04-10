"""
Celery tasks for audio transcription
"""
from __future__ import annotations

import json
import logging
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict

# Ensure the repo root (which contains audio_pipeline/) is on sys.path
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from app.tasks.celery_app import celery_app
from app.core.config import settings
from app.core.storage import storage
from audio_pipeline.pipeline import AudioPipeline

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, name="transcribe_audio_task")
def transcribe_audio_task(
    self,
    job_id: str,
    filename: str,
    file_hash: str,
    minio_path: str,
) -> Dict[str, Any]:
    """
    Celery task that:
      1. Downloads the audio file from MinIO.
      2. Runs the AudioPipeline (Whisper transcription + Pyannote diarization).
      3. Uploads transcript JSON and TXT back to MinIO.
      4. Returns a result summary used by the job-status endpoint.

    Args:
        job_id:     Job UUID from the database.
        filename:   Original filename (used to preserve the extension).
        file_hash:  SHA-256 of the original file (for audit / integrity checks).
        minio_path: Path returned by the upload endpoint (``bucket/object``).

    Returns:
        Dictionary with transcription results.
    """
    logger.info("Transcription started  job=%s  file=%s", job_id, filename)
    self.update_state(state="STARTED", meta={"status": "downloading", "progress": 0})

    with tempfile.TemporaryDirectory(prefix="mxa_celery_") as tmp:
        tmp_path = Path(tmp)
        input_dir = tmp_path / "input"
        output_dir = tmp_path / "output"
        input_dir.mkdir()
        output_dir.mkdir()

        # ------------------------------------------------------------------
        # 1. Download audio from MinIO
        # ------------------------------------------------------------------
        local_audio = input_dir / filename
        try:
            storage.download_audio(job_id, filename, str(local_audio))
        except Exception as exc:
            logger.error("Download failed  job=%s: %s", job_id, exc, exc_info=True)
            raise

        self.update_state(state="STARTED", meta={"status": "processing", "progress": 10})

        # ------------------------------------------------------------------
        # 2. Run transcription pipeline
        # ------------------------------------------------------------------
        pipeline = AudioPipeline(
            model_size=settings.WHISPER_MODEL_SIZE,
            device=settings.WHISPER_DEVICE,
            compute_type=settings.WHISPER_COMPUTE_TYPE,
            diarization_enabled=settings.DIARIZATION_ENABLED,
        )

        def _progress(msg: str) -> None:
            logger.info("[job=%s] %s", job_id, msg)

        def _item(index: int, total: int, name: str) -> None:
            pct = int((index / total) * 80) + 10 if total else 10
            self.update_state(
                state="STARTED",
                meta={"status": "processing", "progress": pct, "current_file": name},
            )

        summary = pipeline.run(
            input_dir=input_dir,
            output_dir=output_dir,
            progress_callback=_progress,
            item_callback=_item,
        )

        if not summary.get("results"):
            raise RuntimeError("Pipeline returned no results")

        result = summary["results"][0]

        # ------------------------------------------------------------------
        # 3. Upload transcripts to MinIO
        # ------------------------------------------------------------------
        self.update_state(state="STARTED", meta={"status": "uploading", "progress": 95})

        stem = Path(filename).stem
        json_file = output_dir / "transcripts" / f"{stem}.json"
        txt_file = output_dir / "transcripts" / f"{stem}.txt"

        transcript_json_path: str | None = None
        transcript_txt_path: str | None = None

        if json_file.exists():
            with open(json_file, "r", encoding="utf-8") as fh:
                transcript_data = json.load(fh)
            transcript_json_path = storage.upload_transcript_json(job_id, transcript_data)
            logger.info("Uploaded JSON transcript  job=%s -> %s", job_id, transcript_json_path)

        if txt_file.exists():
            txt_content = txt_file.read_text(encoding="utf-8")
            transcript_txt_path = storage.upload_transcript_txt(job_id, txt_content)
            logger.info("Uploaded TXT transcript  job=%s -> %s", job_id, transcript_txt_path)

    # ------------------------------------------------------------------
    # 4. Return result summary
    # ------------------------------------------------------------------
    logger.info("Transcription completed  job=%s  status=%s", job_id, result.get("status"))

    return {
        "success": True,
        "job_id": job_id,
        "status": result.get("status"),
        "language": result.get("language"),
        "language_probability": result.get("language_probability"),
        "duration": result.get("duration"),
        "speaker_count": result.get("speaker_count"),
        "segments_count": len(result.get("segments", [])),
        "transcript_json_path": transcript_json_path,
        "transcript_txt_path": transcript_txt_path,
        "note": result.get("note"),
        "diarization_note": result.get("diarization_note"),
    }
