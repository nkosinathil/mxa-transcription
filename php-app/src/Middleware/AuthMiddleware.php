<?php
/**
 * php-app/src/Middleware/AuthMiddleware.php
 * -------------------------------------------
 * Ensures the user is logged in before accessing protected routes.
 *
 * Plain-language:
 *   This class is the "bouncer" of the application.  Before any protected
 *   page loads, we call AuthMiddleware::require() which checks that:
 *   - The session exists and has a valid user record.
 *   - The session has not expired.
 *   If either check fails, the user is redirected to the login page.
 */

declare(strict_types=1);

namespace App\Middleware;

use App\Config\Config;

class AuthMiddleware
{
    /**
     * Redirect to login if the user is not authenticated.
     * Call this at the top of every protected controller action.
     */
    public static function require(): void
    {
        if (!self::check()) {
            $_SESSION['intended_url'] = $_SERVER['REQUEST_URI'] ?? '/';
            header('Location: /auth/login');
            exit;
        }
    }

    /**
     * Returns true if the session contains a valid authenticated user.
     */
    public static function check(): bool
    {
        if (empty($_SESSION['user'])) {
            return false;
        }

        $lifetime = Config::get('session.lifetime', 7200);
        $lastActivity = $_SESSION['last_activity'] ?? 0;

        if ((time() - $lastActivity) > $lifetime) {
            session_unset();
            session_destroy();
            return false;
        }

        $_SESSION['last_activity'] = time();
        return true;
    }

    /**
     * Return the currently logged-in user array, or null.
     *
     * @return array<string,mixed>|null
     */
    public static function user(): ?array
    {
        return $_SESSION['user'] ?? null;
    }

    /**
     * Store a user in the session after successful login.
     *
     * @param array<string,mixed> $user
     */
    public static function login(array $user): void
    {
        session_regenerate_id(true);         // prevent session fixation
        $_SESSION['user']          = $user;
        $_SESSION['last_activity'] = time();
    }

    /**
     * Destroy the session and log the user out.
     */
    public static function logout(): void
    {
        session_unset();
        session_destroy();
    }
}
