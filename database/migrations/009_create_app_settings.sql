-- Migration 009: Create app_settings table
--
-- Why this table exists:
--   Some configuration values need to be changeable at runtime without
--   redeploying code (e.g. default Whisper model, max upload size, feature flags).
--   We store those here. Secrets are never stored in this table; they live in
--   .env files.

CREATE TABLE IF NOT EXISTS app_settings (
    key         VARCHAR(100) PRIMARY KEY,
    value       TEXT         NOT NULL,
    description TEXT,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Default settings
INSERT INTO app_settings (key, value, description) VALUES
    ('default_model',          'base',    'Default Faster-Whisper model size'),
    ('default_device',         'auto',    'Default inference device: auto, cpu, cuda'),
    ('max_upload_bytes',       '524288000', 'Maximum audio upload size in bytes (500 MB)'),
    ('diarization_enabled',    'true',    'Enable speaker diarization by default'),
    ('allowed_audio_types',    'wav,mp3,m4a,aac,flac,ogg,opus,wma', 'Comma-separated allowed file extensions'),
    ('job_retention_days',     '90',      'How many days to keep completed job records')
ON CONFLICT (key) DO NOTHING;
