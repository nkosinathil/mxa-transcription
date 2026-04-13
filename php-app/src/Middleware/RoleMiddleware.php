<?php
/**
 * php-app/src/Middleware/RoleMiddleware.php
 * -------------------------------------------
 * Role-based access control.
 *
 * Plain-language:
 *   Not all users should be able to do everything.  An "analyst" can upload
 *   and trigger processing, but only an "admin" can access settings.  A
 *   "viewer" can only see results.  This class enforces those rules.
 *
 *   Role hierarchy:  admin > analyst > viewer
 */

declare(strict_types=1);

namespace App\Middleware;

class RoleMiddleware
{
    private const HIERARCHY = ['viewer' => 1, 'analyst' => 2, 'admin' => 3];

    /**
     * Abort with 403 if the current user does not have the required role.
     *
     * @param string $requiredRole  'admin', 'analyst', or 'viewer'
     */
    public static function require(string $requiredRole): void
    {
        AuthMiddleware::require();   // ensure logged in first

        $user     = AuthMiddleware::user();
        $userRole = $user['role'] ?? 'viewer';

        $userLevel     = self::HIERARCHY[$userRole]     ?? 0;
        $requiredLevel = self::HIERARCHY[$requiredRole] ?? 9999;

        if ($userLevel < $requiredLevel) {
            http_response_code(403);
            require __DIR__ . '/../Views/errors/403.php';
            exit;
        }
    }

    /**
     * Returns true if the current user has at least $role.
     */
    public static function has(string $role): bool
    {
        $user      = AuthMiddleware::user();
        $userRole  = $user['role'] ?? 'viewer';
        $userLevel = self::HIERARCHY[$userRole]  ?? 0;
        $reqLevel  = self::HIERARCHY[$role]      ?? 9999;
        return $userLevel >= $reqLevel;
    }
}
