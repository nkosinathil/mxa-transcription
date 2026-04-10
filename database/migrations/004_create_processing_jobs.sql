-- Migration 004: Create processing_jobs table
--
-- Why this table exists:
--   When a user requests transcription, the PHP app calls the Python API which
--   queues a Celery task and returns a task ID. We record that task ID here so
--   we can poll for progress and associate the result with the correct upload.
--   The status column mirrors Celery task states so the UI can show a clear
--   indicator: queued → processing → completed / failed.
--
-- Relations:
--   processing_jobs.upload_id → uploads.id
--   processing_jobs.case_id   → cases.id
--   processing_jobs.user_id   → users.id
--   Referenced by job_events, results

CREATE TABLE IF NOT EXISTS processing_jobs (
    id              SERIAL PRIMARY KEY,
    upload_id       INTEGER      NOT NULL REFERENCES uploads(id) ON DELETE CASCADE,
    case_id         INTEGER      NOT NULL REFERENCES cases(id)   ON DELETE CASCADE,
    user_id         INTEGER      NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    celery_task_id  VARCHAR(255),                   -- UUID returned by Celery
    status          VARCHAR(50)  NOT NULL DEFAULT 'queued'
                        CHECK (status IN ('queued','processing','completed','failed','cancelled')),
    progress        SMALLINT     NOT NULL DEFAULT 0
                        CHECK (progress BETWEEN 0 AND 100),
    model_size      VARCHAR(50)  NOT NULL DEFAULT 'base',
    device          VARCHAR(50)  NOT NULL DEFAULT 'auto',
    compute_type    VARCHAR(50),
    diarization     BOOLEAN      NOT NULL DEFAULT TRUE,
    error_message   TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_jobs_upload_id      ON processing_jobs (upload_id);
CREATE INDEX IF NOT EXISTS idx_jobs_case_id        ON processing_jobs (case_id);
CREATE INDEX IF NOT EXISTS idx_jobs_user_id        ON processing_jobs (user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_celery_task_id ON processing_jobs (celery_task_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status         ON processing_jobs (status);
