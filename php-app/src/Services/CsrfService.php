<?php
/**
 * php-app/src/Services/CsrfService.php
 * -------------------------------------
 * CSRF token generation and validation service.
 *
 * Plain-language:
 *   Cross-Site Request Forgery (CSRF) attacks trick users into submitting
 *   forms they didn't intend to. This service generates unique tokens for
 *   each form and validates them on submission.
 *
 *   Usage:
 *     In form: <input type="hidden" name="csrf_token" value="<?= CsrfService::generate() ?>">
 *     On submit: CsrfService::validate($_POST['csrf_token']);
 */

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

class CsrfService
{
    private const TOKEN_LENGTH = 32;
    private const SESSION_KEY = 'csrf_tokens';
    private const MAX_TOKENS = 10; // Keep last 10 tokens to support multiple tabs

    /**
     * Generate a new CSRF token and store it in the session.
     *
     * @return string The generated token
     */
    public static function generate(): string
    {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            throw new RuntimeException('Session must be started before generating CSRF token');
        }

        // Generate a cryptographically secure random token
        $token = bin2hex(random_bytes(self::TOKEN_LENGTH));

        // Initialize token array if it doesn't exist
        if (!isset($_SESSION[self::SESSION_KEY]) || !is_array($_SESSION[self::SESSION_KEY])) {
            $_SESSION[self::SESSION_KEY] = [];
        }

        // Add token with timestamp
        $_SESSION[self::SESSION_KEY][$token] = time();

        // Limit number of stored tokens (prevent memory bloat from many tabs)
        if (count($_SESSION[self::SESSION_KEY]) > self::MAX_TOKENS) {
            // Remove oldest tokens
            $tokens = $_SESSION[self::SESSION_KEY];
            asort($tokens); // Sort by timestamp
            $_SESSION[self::SESSION_KEY] = array_slice($tokens, -self::MAX_TOKENS, null, true);
        }

        return $token;
    }

    /**
     * Validate a CSRF token and remove it (one-time use).
     *
     * @param string|null $token The token to validate
     * @return bool True if valid, false otherwise
     */
    public static function validate(?string $token): bool
    {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            return false;
        }

        if ($token === null || $token === '') {
            return false;
        }

        if (!isset($_SESSION[self::SESSION_KEY]) || !is_array($_SESSION[self::SESSION_KEY])) {
            return false;
        }

        // Check if token exists
        if (!isset($_SESSION[self::SESSION_KEY][$token])) {
            return false;
        }

        // Token is valid - remove it (one-time use)
        unset($_SESSION[self::SESSION_KEY][$token]);

        return true;
    }

    /**
     * Validate a CSRF token and throw an exception if invalid.
     *
     * @param string|null $token The token to validate
     * @throws RuntimeException If token is invalid
     */
    public static function validateOrFail(?string $token): void
    {
        if (!self::validate($token)) {
            throw new RuntimeException('CSRF token validation failed');
        }
    }

    /**
     * Clean up expired tokens (optional maintenance).
     * Tokens older than the session lifetime are removed.
     *
     * @param int $maxAge Maximum age in seconds (default: 1 hour)
     */
    public static function cleanup(int $maxAge = 3600): void
    {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            return;
        }

        if (!isset($_SESSION[self::SESSION_KEY]) || !is_array($_SESSION[self::SESSION_KEY])) {
            return;
        }

        $now = time();
        foreach ($_SESSION[self::SESSION_KEY] as $token => $timestamp) {
            if ($now - $timestamp > $maxAge) {
                unset($_SESSION[self::SESSION_KEY][$token]);
            }
        }
    }
}
