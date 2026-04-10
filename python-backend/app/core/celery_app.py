"""
app/core/celery_app.py
-----------------------
Creates and exports the Celery application instance.

Plain-language explanation
--------------------------
Celery is a "task queue" – it lets us kick off long-running work (audio
transcription can take several minutes) without making the web request wait.
When a user clicks "Start Processing", we drop a task into a Redis queue,
return a task ID to the caller immediately, then one of the worker processes
picks it up and does the actual work in the background.
"""
from __future__ import annotations

from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "transcription",
    broker=settings.redis_url,
    backend=settings.redis_url,
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    # Keep results for 24 hours then let Redis evict them.
    result_expires=86400,
    # Route all tasks through a single queue for simplicity.
    task_default_queue="transcription",
    worker_prefetch_multiplier=1,       # process one task at a time per worker
    task_acks_late=True,                # only ack after task completes
    task_reject_on_worker_lost=True,    # re-queue if a worker dies mid-task
)
