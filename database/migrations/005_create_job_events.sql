-- Migration 005: Create job_events table
--
-- Why this table exists:
--   While Celery processes a file, it emits log messages ("Transcribing 1/3…",
--   "Running diarization…" etc.). We store each message as a row here so the
--   web UI can display a live event log to the user. This replaces the Qt
--   application's live log text-box.
--
-- Relations:
--   job_events.job_id → processing_jobs.id

CREATE TABLE IF NOT EXISTS job_events (
    id          BIGSERIAL    PRIMARY KEY,
    job_id      INTEGER      NOT NULL REFERENCES processing_jobs(id) ON DELETE CASCADE,
    event_type  VARCHAR(50)  NOT NULL DEFAULT 'info'
                    CHECK (event_type IN ('info','warning','error','progress')),
    message     TEXT         NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_job_events_job_id     ON job_events (job_id);
CREATE INDEX IF NOT EXISTS idx_job_events_created_at ON job_events (created_at);
