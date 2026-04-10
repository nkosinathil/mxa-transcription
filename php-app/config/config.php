<?php
/**
 * PHP Application Configuration
 * Reads values from environment variables (set via .env loaded by the web-server
 * or a bootstrap script) with sensible defaults.
 */

// Load .env file if it exists (simple key=value parser, no external dependency)
$envFile = __DIR__ . '/../.env';
if (file_exists($envFile)) {
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (str_starts_with(trim($line), '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $key   = trim($key);
        $value = trim($value, " \t\n\r\0\x0B\"'");
        if (!empty($key) && !array_key_exists($key, $_ENV)) {
            $_ENV[$key] = $value;
            putenv("$key=$value");
        }
    }
}

return [
    // Application
    'app_name' => $_ENV['APP_NAME'] ?? 'MXA Transcription',
    'app_url'  => $_ENV['APP_URL']  ?? 'http://192.168.1.66',
    'debug'    => filter_var($_ENV['APP_DEBUG'] ?? 'false', FILTER_VALIDATE_BOOLEAN),

    // Database
    'db' => [
        'host'     => $_ENV['DB_HOST']     ?? '192.168.1.66',
        'port'     => $_ENV['DB_PORT']     ?? '5432',
        'database' => $_ENV['DB_NAME']     ?? 'mxa_transcription',
        'username' => $_ENV['DB_USER']     ?? 'mxa_transcription',
        'password' => $_ENV['DB_PASSWORD'] ?? '',
    ],

    // Python API (Server 2)
    'api' => [
        'base_url'   => $_ENV['API_BASE_URL']   ?? 'http://192.168.1.90:8000/api/v1',
        'secret_key' => $_ENV['API_SECRET_KEY'] ?? 'change-this-in-production',
        'timeout'    => 30,
    ],

    // Keycloak OIDC (Server 3)
    'keycloak' => [
        'server_url'    => $_ENV['KEYCLOAK_SERVER_URL']    ?? 'http://192.168.1.59:8080',
        'realm'         => $_ENV['KEYCLOAK_REALM']         ?? 'mxa-transcription',
        'client_id'     => $_ENV['KEYCLOAK_CLIENT_ID']     ?? 'mxa-transcription-client',
        'client_secret' => $_ENV['KEYCLOAK_CLIENT_SECRET'] ?? '',
        'redirect_uri'  => $_ENV['KEYCLOAK_REDIRECT_URI']  ?? 'http://192.168.1.66/auth/callback',
    ],

    // Session
    'session' => [
        'lifetime'    => 7200,          // 2 hours
        'cookie_name' => 'mxa_session',
        'secure'      => false,         // Set true in production with HTTPS
        'httponly'    => true,
    ],

    // File upload constraints
    'upload' => [
        'max_size'           => 500 * 1024 * 1024,   // 500 MB
        'allowed_extensions' => ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma'],
    ],

    // Logging
    'log' => [
        'path'  => __DIR__ . '/../storage/logs/app.log',
        'level' => $_ENV['LOG_LEVEL'] ?? 'info',
    ],
];
