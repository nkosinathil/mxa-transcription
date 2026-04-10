"""
app/services/minio_service.py
------------------------------
Wrapper around the MinIO Python SDK.

Plain-language explanation
--------------------------
MinIO is an object storage system (similar to Amazon S3) that we use to store
audio files, transcripts, and export archives.  Instead of storing large files
in the database, we keep them in MinIO and only put the file path (called an
"object key") in PostgreSQL.  This file provides reusable helper methods for
uploading, downloading, and generating pre-signed download URLs.
"""
from __future__ import annotations

import hashlib
import io
import logging
from pathlib import Path
from typing import BinaryIO

from minio import Minio
from minio.error import S3Error

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class MinioService:
    def __init__(self) -> None:
        settings = get_settings()
        self._client = Minio(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure,
        )
        self._ensure_buckets([
            settings.minio_audio_bucket,
            settings.minio_results_bucket,
            settings.minio_exports_bucket,
        ])

    # ------------------------------------------------------------------
    # Bucket management
    # ------------------------------------------------------------------

    def _ensure_buckets(self, names: list[str]) -> None:
        """Create buckets if they do not exist yet."""
        for name in names:
            try:
                if not self._client.bucket_exists(name):
                    self._client.make_bucket(name)
                    logger.info("Created MinIO bucket: %s", name)
            except S3Error as exc:
                logger.error("Failed to create bucket %s: %s", name, exc)

    # ------------------------------------------------------------------
    # Upload helpers
    # ------------------------------------------------------------------

    def upload_file(
        self,
        bucket: str,
        object_name: str,
        file_path: Path,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload a local file to MinIO. Returns the object name."""
        self._client.fput_object(
            bucket_name=bucket,
            object_name=object_name,
            file_path=str(file_path),
            content_type=content_type,
        )
        logger.info("Uploaded %s → minio://%s/%s", file_path, bucket, object_name)
        return object_name

    def upload_bytes(
        self,
        bucket: str,
        object_name: str,
        data: bytes,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload raw bytes to MinIO."""
        self._client.put_object(
            bucket_name=bucket,
            object_name=object_name,
            data=io.BytesIO(data),
            length=len(data),
            content_type=content_type,
        )
        logger.info("Uploaded bytes → minio://%s/%s (%d bytes)", bucket, object_name, len(data))
        return object_name

    def upload_stream(
        self,
        bucket: str,
        object_name: str,
        stream: BinaryIO,
        size: int,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload a file-like stream to MinIO."""
        self._client.put_object(
            bucket_name=bucket,
            object_name=object_name,
            data=stream,
            length=size,
            content_type=content_type,
        )
        return object_name

    # ------------------------------------------------------------------
    # Download helpers
    # ------------------------------------------------------------------

    def download_to_path(self, bucket: str, object_name: str, dest: Path) -> Path:
        """Download an object from MinIO to a local file."""
        self._client.fget_object(bucket, object_name, str(dest))
        return dest

    def get_bytes(self, bucket: str, object_name: str) -> bytes:
        """Download an object and return its content as bytes."""
        response = self._client.get_object(bucket, object_name)
        try:
            return response.read()
        finally:
            response.close()
            response.release_conn()

    # ------------------------------------------------------------------
    # Pre-signed URL generation
    # ------------------------------------------------------------------

    def presigned_url(
        self,
        bucket: str,
        object_name: str,
        expires_seconds: int = 3600,
    ) -> str:
        """Generate a pre-signed URL that allows temporary direct download."""
        from datetime import timedelta
        url = self._client.presigned_get_object(
            bucket_name=bucket,
            object_name=object_name,
            expires=timedelta(seconds=expires_seconds),
        )
        return url

    # ------------------------------------------------------------------
    # Utility
    # ------------------------------------------------------------------

    @staticmethod
    def sha256_stream(stream: BinaryIO, chunk_size: int = 1024 * 1024) -> str:
        """Compute SHA-256 hash of a file-like stream."""
        h = hashlib.sha256()
        while True:
            chunk = stream.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
        return h.hexdigest()
