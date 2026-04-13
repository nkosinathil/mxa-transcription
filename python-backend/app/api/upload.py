"""
app/api/upload.py
------------------
File upload endpoint.

Plain-language explanation
--------------------------
The PHP application POSTs an audio file to this endpoint.  We:
  1. Validate the file (size, extension, MIME type).
  2. Compute its SHA-256 hash (so we can detect duplicates later).
  3. Store it in MinIO under a deterministic path.
  4. Return the MinIO path and SHA-256 to PHP so it can store them in PostgreSQL.

We do NOT store the file in PostgreSQL – only the path.  Large binary files
belong in object storage, not in relational databases.
"""
from __future__ import annotations

import hashlib
import logging
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.core.config import get_settings
from app.core.dependencies import verify_api_key
from app.models.schemas import UploadResponse
from app.services.minio_service import MinioService

logger = logging.getLogger(__name__)
router = APIRouter()

ALLOWED_EXTENSIONS = {
    ".wav", ".mp3", ".m4a", ".aac", ".flac", ".ogg", ".opus", ".wma"
}

CONTENT_TYPE_MAP = {
    ".wav":  "audio/wav",
    ".mp3":  "audio/mpeg",
    ".m4a":  "audio/mp4",
    ".aac":  "audio/aac",
    ".flac": "audio/flac",
    ".ogg":  "audio/ogg",
    ".opus": "audio/ogg",
    ".wma":  "audio/x-ms-wma",
}


@router.post(
    "/upload",
    response_model=UploadResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["upload"],
    dependencies=[Depends(verify_api_key)],
)
async def upload_audio(
    file: UploadFile = File(..., description="Audio file to upload"),
    case_id: int = Form(..., description="ID of the case this upload belongs to"),
) -> UploadResponse:
    """
    Accept an audio file from PHP, store it in MinIO, return its location.

    The PHP app should call this endpoint, then store the returned
    minio_bucket and minio_path in the uploads table in PostgreSQL.
    """
    settings = get_settings()

    # ----- Validate file extension -----
    suffix = Path(file.filename or "unknown").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"File type '{suffix}' is not allowed. "
                   f"Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    # ----- Read file and enforce size limit -----
    data = await file.read()
    if len(data) > settings.max_upload_bytes:
        mb = settings.max_upload_bytes // (1024 * 1024)
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds maximum size of {mb} MB.",
        )

    # ----- Compute SHA-256 -----
    sha256 = hashlib.sha256(data).hexdigest()

    # ----- Build MinIO object key -----
    # Path: case_<id>/<uuid><extension>
    # Using a UUID prevents filename collisions and avoids path traversal issues.
    object_name = f"case_{case_id}/{uuid.uuid4().hex}{suffix}"
    content_type = CONTENT_TYPE_MAP.get(suffix, "application/octet-stream")

    # ----- Upload to MinIO -----
    minio = MinioService()
    minio.upload_bytes(
        bucket=settings.minio_audio_bucket,
        object_name=object_name,
        data=data,
        content_type=content_type,
    )

    logger.info(
        "Uploaded audio for case %d: %s → minio://%s/%s",
        case_id, file.filename, settings.minio_audio_bucket, object_name,
    )

    return UploadResponse(
        minio_bucket=settings.minio_audio_bucket,
        minio_path=object_name,
        size_bytes=len(data),
        sha256=sha256,
        original_filename=file.filename or "unknown",
    )
