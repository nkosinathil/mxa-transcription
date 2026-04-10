-- Migration 007: Create exports table
--
-- Why this table exists:
--   Users may request a downloadable export for a whole case (e.g. a ZIP of all
--   transcripts, a CSV summary). We record the generated export file in MinIO and
--   its metadata here so we can provide a download link without regenerating the
--   file on every request.
--
-- Relations:
--   exports.case_id → cases.id
--   exports.user_id → users.id

CREATE TABLE IF NOT EXISTS exports (
    id           SERIAL PRIMARY KEY,
    case_id      INTEGER      NOT NULL REFERENCES cases(id)  ON DELETE CASCADE,
    user_id      INTEGER      NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    minio_bucket VARCHAR(255) NOT NULL,
    minio_path   VARCHAR(1024) NOT NULL,
    filename     VARCHAR(512) NOT NULL,
    export_type  VARCHAR(50)  NOT NULL DEFAULT 'zip'
                     CHECK (export_type IN ('zip','csv','json','txt')),
    size_bytes   BIGINT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ                              -- optional expiry
);

CREATE INDEX IF NOT EXISTS idx_exports_case_id ON exports (case_id);
