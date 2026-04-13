-- Migration 008: Create audit_logs table
--
-- Why this table exists:
--   For security and compliance we must log every important action: who logged in,
--   who uploaded a file, who triggered processing, who downloaded a result. This
--   table stores a record for each of those events. Because audit logs must never
--   be deleted, there are no ON DELETE CASCADE rules here.
--
-- Relations:
--   audit_logs.user_id → users.id  (nullable – pre-login events have no user)

CREATE TABLE IF NOT EXISTS audit_logs (
    id              BIGSERIAL    PRIMARY KEY,
    user_id         INTEGER      REFERENCES users(id) ON DELETE SET NULL,
    action          VARCHAR(100) NOT NULL,     -- e.g. 'login', 'upload', 'process', 'download'
    resource_type   VARCHAR(100),              -- e.g. 'upload', 'job', 'case'
    resource_id     INTEGER,                   -- the ID of the affected row
    ip_address      INET,
    user_agent      TEXT,
    extra           JSONB,                     -- any additional context
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id    ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action     ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs (created_at);
