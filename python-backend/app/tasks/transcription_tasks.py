"""
Celery tasks for audio transcription
"""
import sys
import json
from pathlib import Path
from typing import Dict, Any
import logging

# Add the audio_pipeline to Python path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from app.tasks.celery_app import celery_app
from app.core.config import settings
from audio_pipeline.pipeline import AudioPipeline

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, name="transcribe_audio_task")
def transcribe_audio_task(
    self,
    audio_path: str,
    job_id: str,
    filename: str,
    file_hash: str
) -> Dict[str, Any]:
    """
    Celery task to transcribe audio file
    
    Args:
        audio_path: Path to audio file
        job_id: Job UUID from database
        filename: Original filename
        file_hash: SHA256 hash of file
    
    Returns:
        Transcription results
    """
    try:
        logger.info(f"Starting transcription for job {job_id}: {filename}")
        
        # Update task status
        self.update_state(
            state="PROCESSING",
            meta={"status": "processing", "progress": 0}
        )
        
        # Initialize audio pipeline
        pipeline = AudioPipeline(
            model_size=settings.WHISPER_MODEL_SIZE,
            device=settings.WHISPER_DEVICE,
            compute_type=settings.WHISPER_COMPUTE_TYPE,
            diarization_enabled=settings.DIARIZATION_ENABLED
        )
        
        # Create temporary output directory
        output_dir = Path(f"/tmp/mxa-transcripts/{job_id}")
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Run transcription pipeline
        input_file = Path(audio_path)
        
        def progress_callback(msg: str):
            logger.info(f"[{job_id}] {msg}")
        
        def item_callback(index: int, total: int, name: str):
            progress = int((index / total) * 100) if total > 0 else 0
            self.update_state(
                state="PROCESSING",
                meta={"status": "processing", "progress": progress, "current_file": name}
            )
        
        # Run pipeline on single file
        # Note: The pipeline expects a directory, so we'll create a temp directory
        temp_input_dir = Path(f"/tmp/mxa-input/{job_id}")
        temp_input_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy file to temp input directory
        import shutil
        temp_file = temp_input_dir / filename
        shutil.copy2(audio_path, temp_file)
        
        # Run pipeline
        summary = pipeline.run(
            input_dir=temp_input_dir,
            output_dir=output_dir,
            progress_callback=progress_callback,
            item_callback=item_callback
        )
        
        # Extract result for this file
        if summary["results"]:
            result = summary["results"][0]
            
            # Save transcript files
            transcript_json = output_dir / "transcripts" / f"{Path(filename).stem}.json"
            transcript_txt = output_dir / "transcripts" / f"{Path(filename).stem}.txt"
            
            # Save to final location
            final_json = output_dir / f"{job_id}.json"
            final_txt = output_dir / f"{job_id}.txt"
            
            if transcript_json.exists():
                shutil.copy2(transcript_json, final_json)
            if transcript_txt.exists():
                shutil.copy2(transcript_txt, final_txt)
            
            # Cleanup temp files
            shutil.rmtree(temp_input_dir, ignore_errors=True)
            if Path(audio_path).exists():
                Path(audio_path).unlink()
            
            logger.info(f"Transcription completed for job {job_id}")
            
            return {
                "success": True,
                "job_id": job_id,
                "status": result.get("status"),
                "language": result.get("language"),
                "duration": result.get("duration"),
                "speaker_count": result.get("speaker_count"),
                "transcript_json": str(final_json) if final_json.exists() else None,
                "transcript_txt": str(final_txt) if final_txt.exists() else None,
                "segments_count": len(result.get("segments", [])),
                "note": result.get("note"),
                "diarization_note": result.get("diarization_note")
            }
        else:
            raise Exception("No results from transcription pipeline")
            
    except Exception as e:
        logger.error(f"Transcription failed for job {job_id}: {str(e)}", exc_info=True)
        self.update_state(
            state="FAILURE",
            meta={"status": "failed", "error": str(e)}
        )
        raise
