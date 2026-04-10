-- Migration 003: Create uploads table
--
-- Why this table exists:
--   When a user uploads an audio file, PHP forwards it to MinIO (object storage)
--   and records the metadata here. We store the MinIO object path (not the file
--   itself) so PostgreSQL stays small and fast. The sha256 hash lets us detect
--   duplicate uploads without reading the file again.
--
-- Relations:
--   uploads.case_id → cases.id
--   uploads.user_id → users.id
--   Referenced by processing_jobs

CREATE TABLE IF NOT EXISTS uploads (
    id             SERIAL PRIMARY KEY,
    case_id        INTEGER      NOT NULL REFERENCES cases(id)  ON DELETE CASCADE,
    user_id        INTEGER      NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    filename       VARCHAR(512) NOT NULL,           -- original file name from the user
    minio_bucket   VARCHAR(255) NOT NULL,           -- MinIO bucket name
    minio_path     VARCHAR(1024) NOT NULL,          -- object key inside the bucket
    size_bytes     BIGINT       NOT NULL DEFAULT 0,
    sha256         CHAR(64),                        -- hex SHA-256 of the audio file
    mime_type      VARCHAR(128),
    upload_status  VARCHAR(50)  NOT NULL DEFAULT 'pending'
                       CHECK (upload_status IN ('pending', 'stored', 'failed')),
    uploaded_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_uploads_case_id ON uploads (case_id);
CREATE INDEX IF NOT EXISTS idx_uploads_user_id ON uploads (user_id);
CREATE INDEX IF NOT EXISTS idx_uploads_sha256  ON uploads (sha256);
