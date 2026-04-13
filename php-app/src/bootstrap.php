<?php
/**
 * php-app/src/bootstrap.php
 * --------------------------
 * Application bootstrap – runs before every request.
 *
 * Plain-language:
 *   This file is the first thing loaded by the front controller.  It:
 *   1. Loads Composer's autoloader (makes all classes available).
 *   2. Loads environment variables from .env.
 *   3. Initialises application configuration.
 *   4. Configures session handling.
 *   5. Sets up error logging.
 */

declare(strict_types=1);

// 1. Autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// 2. Load .env file (one level above /src, i.e. php-app/.env)
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->safeLoad();

// 3. Configuration
App\Config\Config::load();

// 4. Error handling
$debug = filter_var($_ENV['APP_DEBUG'] ?? 'false', FILTER_VALIDATE_BOOLEAN);
ini_set('display_errors', $debug ? '1' : '0');
error_reporting(E_ALL);
ini_set('log_errors', '1');
ini_set('error_log', __DIR__ . '/../storage/logs/php_errors.log');

// 5. Session
$sessionName     = App\Config\Config::get('session.name', 'mxa_session');
$sessionLifetime = App\Config\Config::get('session.lifetime', 7200);
$sessionSecure   = App\Config\Config::get('session.secure_cookie', false);
$sessionSameSite = App\Config\Config::get('session.same_site', 'Lax');

session_name($sessionName);
session_set_cookie_params([
    'lifetime' => $sessionLifetime,
    'path'     => '/',
    'secure'   => (bool) $sessionSecure,
    'httponly' => true,
    'samesite' => (string) $sessionSameSite,
]);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
