<?php
/**
 * php-app/src/Config/config.php
 * --------------------------------
 * Loads configuration from environment variables.
 *
 * Plain-language:
 *   This file reads all the settings from the .env file (loaded earlier by
 *   bootstrap.php) and makes them available through a simple Config::get()
 *   helper.  Never hardcode values – always use Config::get().
 */

declare(strict_types=1);

namespace App\Config;

class Config
{
    private static array $data = [];

    public static function load(): void
    {
        self::$data = [
            'app' => [
                'name'      => $_ENV['APP_NAME']      ?? 'MXA Transcription',
                'env'       => $_ENV['APP_ENV']       ?? 'production',
                'url'       => rtrim($_ENV['APP_URL'] ?? 'http://localhost', '/'),
                'debug'     => filter_var($_ENV['APP_DEBUG'] ?? 'false', FILTER_VALIDATE_BOOLEAN),
                'log_level' => $_ENV['APP_LOG_LEVEL'] ?? 'warning',
            ],
            'session' => [
                'name'     => $_ENV['SESSION_NAME']     ?? 'mxa_session',
                'lifetime' => (int) ($_ENV['SESSION_LIFETIME'] ?? 7200),
                'secret'   => $_ENV['SESSION_SECRET']   ?? '',
            ],
            'db' => [
                'host' => $_ENV['DB_HOST'] ?? 'localhost',
                'port' => (int) ($_ENV['DB_PORT'] ?? 5432),
                'name' => $_ENV['DB_NAME'] ?? 'transcription_db',
                'user' => $_ENV['DB_USER'] ?? '',
                'pass' => $_ENV['DB_PASS'] ?? '',
            ],
            'keycloak' => [
                'base_url'     => rtrim($_ENV['KEYCLOAK_BASE_URL'] ?? '', '/'),
                'realm'        => $_ENV['KEYCLOAK_REALM']        ?? '',
                'client_id'    => $_ENV['KEYCLOAK_CLIENT_ID']    ?? '',
                'client_secret'=> $_ENV['KEYCLOAK_CLIENT_SECRET']?? '',
                'redirect_uri' => $_ENV['KEYCLOAK_REDIRECT_URI'] ?? '',
            ],
            'python_api' => [
                'base_url' => rtrim($_ENV['PYTHON_API_BASE_URL'] ?? '', '/'),
                'api_key'  => $_ENV['PYTHON_API_KEY'] ?? '',
            ],
            'minio' => [
                'endpoint'       => $_ENV['MINIO_ENDPOINT']        ?? 'localhost:9000',
                'access_key'     => $_ENV['MINIO_ACCESS_KEY']      ?? '',
                'secret_key'     => $_ENV['MINIO_SECRET_KEY']      ?? '',
                'secure'         => filter_var($_ENV['MINIO_SECURE'] ?? 'false', FILTER_VALIDATE_BOOLEAN),
                'audio_bucket'   => $_ENV['MINIO_AUDIO_BUCKET']    ?? 'audio-uploads',
                'results_bucket' => $_ENV['MINIO_RESULTS_BUCKET']  ?? 'transcription-results',
                'exports_bucket' => $_ENV['MINIO_EXPORTS_BUCKET']  ?? 'exports',
            ],
            'csrf' => [
                'lifetime' => (int) ($_ENV['CSRF_TOKEN_LIFETIME'] ?? 3600),
            ],
        ];
    }

    /**
     * Retrieve a config value using dot notation.
     * Example: Config::get('db.host')
     */
    public static function get(string $key, mixed $default = null): mixed
    {
        $parts = explode('.', $key);
        $current = self::$data;

        foreach ($parts as $part) {
            if (!is_array($current) || !array_key_exists($part, $current)) {
                return $default;
            }
            $current = $current[$part];
        }

        return $current;
    }
}
