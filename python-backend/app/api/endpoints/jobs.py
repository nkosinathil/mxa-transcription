"""
Job status endpoints
"""
from fastapi import APIRouter, HTTPException, Depends, status
from typing import Dict, Any
from celery.result import AsyncResult

from app.core.dependencies import verify_api_key
from app.tasks.celery_app import celery_app

router = APIRouter()


@router.get("/{job_id}/status", response_model=Dict[str, Any])
async def get_job_status(
    job_id: str,
    api_key: str = Depends(verify_api_key)
) -> Dict[str, Any]:
    """
    Get status of a transcription job
    
    Args:
        job_id: Job UUID
        api_key: API key for authentication
    
    Returns:
        Job status information
    """
    try:
        # Query Celery task result
        # Note: In production, we'd query database for job_id to task_id mapping
        # For now, assuming job_id == task_id
        result = AsyncResult(job_id, app=celery_app)
        
        response = {
            "job_id": job_id,
            "status": result.state,
            "ready": result.ready(),
            "successful": result.successful() if result.ready() else None,
        }
        
        if result.ready():
            if result.successful():
                response["result"] = result.result
            else:
                response["error"] = str(result.info)
        
        return response
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get job status: {str(e)}"
        )


@router.get("/{job_id}", response_model=Dict[str, Any])
async def get_job_details(
    job_id: str,
    api_key: str = Depends(verify_api_key)
) -> Dict[str, Any]:
    """
    Get detailed information about a job
    
    Args:
        job_id: Job UUID
        api_key: API key for authentication
    
    Returns:
        Detailed job information
    """
    # TODO: Query PostgreSQL database for job details
    # For now, return Celery task status
    return await get_job_status(job_id, api_key)
