"""
File upload endpoints
"""
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, status
from typing import Dict, Any
import os
import hashlib
from pathlib import Path

from app.core.dependencies import verify_api_key
from app.core.config import settings
from app.tasks.transcription_tasks import transcribe_audio_task

router = APIRouter()


async def validate_audio_file(file: UploadFile) -> None:
    """Validate uploaded audio file"""
    # Check file extension
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in settings.ALLOWED_AUDIO_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(settings.ALLOWED_AUDIO_EXTENSIONS)}"
        )
    
    # Check file size (if content_length is available)
    if file.size and file.size > settings.MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size: {settings.MAX_UPLOAD_SIZE / (1024*1024):.0f}MB"
        )


@router.post("/", response_model=Dict[str, Any])
async def upload_audio(
    file: UploadFile = File(...),
    job_id: str = None,
    api_key: str = Depends(verify_api_key)
) -> Dict[str, Any]:
    """
    Upload audio file and queue transcription task
    
    Args:
        file: Audio file to transcribe
        job_id: UUID of the job (from PHP frontend)
        api_key: API key for authentication
    
    Returns:
        Job information including task ID
    """
    # Validate file
    await validate_audio_file(file)
    
    try:
        # Read file content
        content = await file.read()
        file_size = len(content)
        
        # Calculate SHA256 hash
        file_hash = hashlib.sha256(content).hexdigest()
        
        # Generate storage path
        storage_path = f"{job_id}/{file.filename}" if job_id else file.filename
        
        # TODO: Upload to MinIO
        # For now, store locally in temp directory
        temp_dir = Path("/tmp/mxa-uploads")
        temp_dir.mkdir(parents=True, exist_ok=True)
        temp_file = temp_dir / f"{job_id}_{file.filename}"
        temp_file.write_bytes(content)
        
        # Queue Celery task
        task = transcribe_audio_task.delay(
            audio_path=str(temp_file),
            job_id=job_id,
            filename=file.filename,
            file_hash=file_hash
        )
        
        return {
            "success": True,
            "job_id": job_id,
            "task_id": task.id,
            "filename": file.filename,
            "file_size": file_size,
            "file_hash": file_hash,
            "status": "queued"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Upload failed: {str(e)}"
        )
