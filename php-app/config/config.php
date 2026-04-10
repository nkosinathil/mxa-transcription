<?php
/**
 * PHP Application Configuration
 */

return [
    // Application
    'app_name' => getenv('APP_NAME') ?: 'MXA Transcription',
    'app_url' => getenv('APP_URL') ?: 'http://192.168.1.66',
    'debug' => (getenv('APP_DEBUG') === 'true'),
    
    // Database
    'db' => [
        'host' => getenv('DB_HOST') ?: '192.168.1.66',
        'port' => getenv('DB_PORT') ?: '5432',
        'database' => getenv('DB_NAME') ?: 'mxa_transcription',
        'username' => getenv('DB_USER') ?: 'mxa_transcription',
        'password' => getenv('DB_PASSWORD') ?: 'password',
    ],
    
    // Python API
    'api' => [
        'base_url' => getenv('API_BASE_URL') ?: 'http://192.168.1.90:8000/api/v1',
        'secret_key' => getenv('API_SECRET_KEY') ?: 'change-this-in-production',
        'timeout' => 30,
    ],
    
    // Keycloak OIDC
    'keycloak' => [
        'server_url' => getenv('KEYCLOAK_SERVER_URL') ?: 'http://192.168.1.59:8080',
        'realm' => getenv('KEYCLOAK_REALM') ?: 'mxa-transcription',
        'client_id' => getenv('KEYCLOAK_CLIENT_ID') ?: 'mxa-transcription-client',
        'client_secret' => getenv('KEYCLOAK_CLIENT_SECRET') ?: '',
        'redirect_uri' => getenv('KEYCLOAK_REDIRECT_URI') ?: 'http://192.168.1.66/auth/callback',
    ],
    
    // Session
    'session' => [
        'lifetime' => 7200, // 2 hours
        'cookie_name' => 'mxa_session',
        'secure' => false, // Set to true in production with HTTPS
        'httponly' => true,
    ],
    
    // Upload
    'upload' => [
        'max_size' => 500 * 1024 * 1024, // 500MB
        'allowed_extensions' => ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma'],
    ],
    
    // Logging
    'log' => [
        'path' => __DIR__ . '/../storage/logs/app.log',
        'level' => getenv('LOG_LEVEL') ?: 'info',
    ],
];
