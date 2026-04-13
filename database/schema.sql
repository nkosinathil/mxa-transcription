-- =============================================================================
-- MXA Transcription Web – Complete PostgreSQL Schema
-- =============================================================================
-- Run this file to set up a fresh database, or run individual migration files
-- in order (001 → 009) to apply them incrementally.
--
-- Usage:
--   psql -U transcription_user -d transcription_db -f schema.sql
-- =============================================================================

\i migrations/001_create_users.sql
\i migrations/002_create_cases.sql
\i migrations/003_create_uploads.sql
\i migrations/004_create_processing_jobs.sql
\i migrations/005_create_job_events.sql
\i migrations/006_create_results.sql
\i migrations/007_create_exports.sql
\i migrations/008_create_audit_logs.sql
\i migrations/009_create_app_settings.sql
