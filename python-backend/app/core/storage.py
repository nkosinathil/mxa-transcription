"""
MinIO storage service for audio files and transcripts
"""
from __future__ import annotations

import io
import json
import logging
from pathlib import Path
from typing import Any

from minio import Minio
from minio.error import S3Error

from app.core.config import settings

logger = logging.getLogger(__name__)


class StorageService:
    """Wraps MinIO client with application-level helpers."""

    def __init__(self) -> None:
        self._client: Minio | None = None

    @property
    def client(self) -> Minio:
        if self._client is None:
            self._client = Minio(
                settings.MINIO_ENDPOINT,
                access_key=settings.MINIO_ACCESS_KEY,
                secret_key=settings.MINIO_SECRET_KEY,
                secure=settings.MINIO_SECURE,
            )
            self._ensure_buckets()
        return self._client

    def _ensure_buckets(self) -> None:
        """Create required buckets if they don't exist."""
        for bucket in (
            settings.MINIO_BUCKET_AUDIO,
            settings.MINIO_BUCKET_TRANSCRIPTS,
            settings.MINIO_BUCKET_TEMP,
        ):
            try:
                if not self._client.bucket_exists(bucket):
                    self._client.make_bucket(bucket)
                    logger.info("Created MinIO bucket: %s", bucket)
            except S3Error as exc:
                logger.error("Failed to create bucket %s: %s", bucket, exc)
                raise

    # ------------------------------------------------------------------
    # Upload helpers
    # ------------------------------------------------------------------

    def upload_bytes(
        self,
        bucket: str,
        object_name: str,
        data: bytes,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload raw bytes; returns the object path ``bucket/object_name``."""
        self.client.put_object(
            bucket,
            object_name,
            io.BytesIO(data),
            length=len(data),
            content_type=content_type,
        )
        return f"{bucket}/{object_name}"

    def upload_file(self, bucket: str, object_name: str, file_path: str) -> str:
        """Upload a local file; returns the object path."""
        self.client.fput_object(bucket, object_name, file_path)
        return f"{bucket}/{object_name}"

    def upload_audio(self, job_id: str, filename: str, data: bytes) -> str:
        """Store an audio upload under ``audio-uploads/<job_id>/<filename>``."""
        ext = Path(filename).suffix.lower()
        content_types = {
            ".wav": "audio/wav",
            ".mp3": "audio/mpeg",
            ".m4a": "audio/mp4",
            ".aac": "audio/aac",
            ".flac": "audio/flac",
            ".ogg": "audio/ogg",
            ".opus": "audio/opus",
            ".wma": "audio/x-ms-wma",
        }
        ct = content_types.get(ext, "application/octet-stream")
        object_name = f"{job_id}/{filename}"
        return self.upload_bytes(settings.MINIO_BUCKET_AUDIO, object_name, data, ct)

    def upload_transcript_json(self, job_id: str, data: dict[str, Any]) -> str:
        """Store a JSON transcript and return its object path."""
        payload = json.dumps(data, indent=2, ensure_ascii=False).encode()
        object_name = f"{job_id}/transcript.json"
        return self.upload_bytes(
            settings.MINIO_BUCKET_TRANSCRIPTS, object_name, payload, "application/json"
        )

    def upload_transcript_txt(self, job_id: str, text: str) -> str:
        """Store a plain-text transcript and return its object path."""
        payload = text.encode("utf-8")
        object_name = f"{job_id}/transcript.txt"
        return self.upload_bytes(
            settings.MINIO_BUCKET_TRANSCRIPTS, object_name, payload, "text/plain"
        )

    # ------------------------------------------------------------------
    # Download helpers
    # ------------------------------------------------------------------

    def download_bytes(self, bucket: str, object_name: str) -> bytes:
        """Return the raw bytes of an object."""
        response = self.client.get_object(bucket, object_name)
        try:
            return response.read()
        finally:
            response.close()
            response.release_conn()

    def download_audio(self, job_id: str, filename: str, dest_path: str) -> None:
        """Download an audio file from MinIO to a local path."""
        object_name = f"{job_id}/{filename}"
        self.client.fget_object(settings.MINIO_BUCKET_AUDIO, object_name, dest_path)

    def get_transcript_json(self, job_id: str) -> dict[str, Any]:
        """Return parsed JSON transcript for a job."""
        data = self.download_bytes(
            settings.MINIO_BUCKET_TRANSCRIPTS, f"{job_id}/transcript.json"
        )
        return json.loads(data.decode("utf-8"))

    def get_transcript_txt(self, job_id: str) -> str:
        """Return plain-text transcript for a job."""
        data = self.download_bytes(
            settings.MINIO_BUCKET_TRANSCRIPTS, f"{job_id}/transcript.txt"
        )
        return data.decode("utf-8")

    # ------------------------------------------------------------------
    # Existence checks
    # ------------------------------------------------------------------

    def object_exists(self, bucket: str, object_name: str) -> bool:
        try:
            self.client.stat_object(bucket, object_name)
            return True
        except S3Error:
            return False

    def transcript_exists(self, job_id: str) -> bool:
        return self.object_exists(
            settings.MINIO_BUCKET_TRANSCRIPTS, f"{job_id}/transcript.json"
        )

    # ------------------------------------------------------------------
    # Deletion
    # ------------------------------------------------------------------

    def delete_job_objects(self, job_id: str) -> None:
        """Remove all MinIO objects associated with a job."""
        for bucket in (settings.MINIO_BUCKET_AUDIO, settings.MINIO_BUCKET_TRANSCRIPTS):
            objects = self.client.list_objects(bucket, prefix=f"{job_id}/")
            for obj in objects:
                self.client.remove_object(bucket, obj.object_name)


# Module-level singleton used across the application
storage = StorageService()
