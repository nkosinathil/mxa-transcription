-- Migration 006: Create results table
--
-- Why this table exists:
--   When a transcription job completes, the Python worker saves the transcript
--   and JSON output to MinIO. We record those MinIO paths here along with
--   metadata extracted during processing (language, duration, speaker count).
--   This avoids re-reading MinIO objects just to display summaries.
--
-- Relations:
--   results.job_id → processing_jobs.id

CREATE TABLE IF NOT EXISTS results (
    id                      SERIAL PRIMARY KEY,
    job_id                  INTEGER      NOT NULL REFERENCES processing_jobs(id) ON DELETE CASCADE,
    minio_transcript_path   VARCHAR(1024),      -- .txt transcript in MinIO
    minio_json_path         VARCHAR(1024),      -- .json full result in MinIO
    minio_html_path         VARCHAR(1024),      -- .html transcript page in MinIO
    language                VARCHAR(10),
    language_probability    NUMERIC(5,4),
    duration_seconds        NUMERIC(10,2),
    speaker_count           SMALLINT,
    segment_count           INTEGER,
    diarization_available   BOOLEAN,
    diarization_note        TEXT,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_results_job_id ON results (job_id);
