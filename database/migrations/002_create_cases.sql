-- Migration 002: Create cases table
--
-- Why this table exists:
--   A "case" (also called a workspace) is a logical grouping of uploads and
--   their associated transcription jobs. Users create a case first, then
--   upload audio files into it. This mirrors how investigators or analysts
--   organise their work (e.g. one case per investigation).
--
-- Relations:
--   cases.user_id   → users.id   (who created the case)
--   Referenced by uploads, processing_jobs, exports

CREATE TABLE IF NOT EXISTS cases (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    status      VARCHAR(50)  NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'closed', 'archived')),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cases_user_id ON cases (user_id);
