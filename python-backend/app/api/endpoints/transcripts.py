"""
Transcript retrieval endpoints
"""
from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.responses import JSONResponse, PlainTextResponse
from typing import Dict, Any
from pathlib import Path

from app.core.dependencies import verify_api_key

router = APIRouter()


@router.get("/{job_id}/json", response_model=Dict[str, Any])
async def get_transcript_json(
    job_id: str,
    api_key: str = Depends(verify_api_key)
) -> Dict[str, Any]:
    """
    Get transcript in JSON format
    
    Args:
        job_id: Job UUID
        api_key: API key for authentication
    
    Returns:
        Transcript data in JSON format
    """
    # TODO: Retrieve from MinIO or database
    # For now, read from temp storage
    try:
        temp_file = Path(f"/tmp/mxa-transcripts/{job_id}.json")
        if not temp_file.exists():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transcript not found"
            )
        
        import json
        with open(temp_file, 'r') as f:
            transcript_data = json.load(f)
        
        return transcript_data
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve transcript: {str(e)}"
        )


@router.get("/{job_id}/txt", response_class=PlainTextResponse)
async def get_transcript_txt(
    job_id: str,
    api_key: str = Depends(verify_api_key)
) -> str:
    """
    Get transcript in plain text format
    
    Args:
        job_id: Job UUID
        api_key: API key for authentication
    
    Returns:
        Transcript data in plain text format
    """
    # TODO: Retrieve from MinIO or database
    try:
        temp_file = Path(f"/tmp/mxa-transcripts/{job_id}.txt")
        if not temp_file.exists():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transcript not found"
            )
        
        return temp_file.read_text(encoding='utf-8')
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve transcript: {str(e)}"
        )
