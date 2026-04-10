-- Migration 001: Create users table
--
-- Why this table exists:
--   Users log in through Keycloak (the SSO server). When a user logs in for the
--   first time, we create a local record that maps their Keycloak identity to an
--   application role and stores their profile details for audit logging and UI
--   display. We never store passwords here – Keycloak handles that.
--
-- Relations:
--   Referenced by cases, uploads, processing_jobs, audit_logs

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    keycloak_id   VARCHAR(255) NOT NULL UNIQUE,  -- The sub claim from Keycloak JWT
    email         VARCHAR(320) NOT NULL UNIQUE,
    name          VARCHAR(255) NOT NULL,
    role          VARCHAR(50)  NOT NULL DEFAULT 'viewer'
                      CHECK (role IN ('admin', 'analyst', 'viewer')),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_keycloak_id ON users (keycloak_id);
CREATE INDEX IF NOT EXISTS idx_users_email       ON users (email);
