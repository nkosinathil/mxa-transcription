-- Seed data for development and testing

-- Insert admin user (requires manual Keycloak setup first)
-- UPDATE: Replace keycloak_id with actual Keycloak user ID
INSERT INTO users (username, email, keycloak_id, roles, is_active) VALUES
    ('admin', 'admin@example.com', 'REPLACE_WITH_KEYCLOAK_ID', ARRAY['user', 'admin'], TRUE)
ON CONFLICT (username) DO NOTHING;

-- Insert test user
INSERT INTO users (username, email, keycloak_id, roles, is_active) VALUES
    ('testuser', 'testuser@example.com', 'REPLACE_WITH_KEYCLOAK_ID', ARRAY['user'], TRUE)
ON CONFLICT (username) DO NOTHING;

-- Note: In production, users should be created dynamically via Keycloak integration
