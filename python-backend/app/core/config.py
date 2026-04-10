"""
Configuration settings using pydantic-settings
"""
from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    """Application settings"""
    
    # API Settings
    API_SECRET_KEY: str = os.getenv("API_SECRET_KEY", "change-this-in-production")
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    ALLOWED_ORIGINS: List[str] = ["http://192.168.1.66", "http://localhost"]
    
    # Database Settings
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://mxa_transcription:password@192.168.1.66:5432/mxa_transcription"
    )
    
    # Redis Settings
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    # Celery Settings
    CELERY_BROKER_URL: str = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0")
    CELERY_RESULT_BACKEND: str = os.getenv("CELERY_RESULT_BACKEND", "redis://localhost:6379/1")
    
    # MinIO Settings
    MINIO_ENDPOINT: str = os.getenv("MINIO_ENDPOINT", "localhost:9000")
    MINIO_ACCESS_KEY: str = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
    MINIO_SECRET_KEY: str = os.getenv("MINIO_SECRET_KEY", "minioadmin")
    MINIO_SECURE: bool = os.getenv("MINIO_SECURE", "False").lower() == "true"
    MINIO_BUCKET_AUDIO: str = "audio-uploads"
    MINIO_BUCKET_TRANSCRIPTS: str = "transcripts"
    MINIO_BUCKET_TEMP: str = "temp"
    
    # Transcription Settings
    WHISPER_MODEL_SIZE: str = os.getenv("WHISPER_MODEL_SIZE", "base")
    WHISPER_DEVICE: str = os.getenv("WHISPER_DEVICE", "auto")
    WHISPER_COMPUTE_TYPE: str = os.getenv("WHISPER_COMPUTE_TYPE", "int8")
    DIARIZATION_ENABLED: bool = os.getenv("DIARIZATION_ENABLED", "True").lower() == "true"
    HUGGINGFACE_TOKEN: str = os.getenv("HUGGINGFACE_TOKEN", "")
    
    # File Upload Settings
    MAX_UPLOAD_SIZE: int = int(os.getenv("MAX_UPLOAD_SIZE", str(500 * 1024 * 1024)))  # 500MB default
    ALLOWED_AUDIO_EXTENSIONS: List[str] = [".wav", ".mp3", ".m4a", ".aac", ".flac", ".ogg", ".opus", ".wma"]
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
