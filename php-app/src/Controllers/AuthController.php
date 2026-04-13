<?php
/**
 * php-app/src/Controllers/AuthController.php
 * ---------------------------------------------
 * Handles Keycloak OIDC login, callback, and logout.
 */

declare(strict_types=1);

namespace App\Controllers;

use App\Config\Config;
use App\Middleware\AuthMiddleware;
use App\Repositories\UserRepository;
use App\Services\AuditService;
use App\Services\KeycloakService;
use Throwable;

class AuthController
{
    /**
     * Redirect the user to Keycloak's login page.
     */
    public function login(): void
    {
        if (AuthMiddleware::check()) {
            header('Location: /dashboard');
            exit;
        }

        $keycloak = new KeycloakService();
        $loginUrl = $keycloak->buildLoginUrl();
        header("Location: {$loginUrl}");
        exit;
    }

    /**
     * Handle the redirect back from Keycloak.
     * Keycloak sends ?code=…&state=… to this URL.
     */
    public function callback(): void
    {
        $code  = $_GET['code']  ?? '';
        $state = $_GET['state'] ?? '';
        $error = $_GET['error'] ?? '';

        if ($error) {
            $this->renderError("Keycloak error: " . htmlspecialchars($error));
            return;
        }

        if (!$code || !$state) {
            $this->renderError("Missing authorization code or state parameter.");
            return;
        }

        try {
            $keycloak = new KeycloakService();
            $tokens   = $keycloak->exchangeCode($code, $state);
            $profile  = $keycloak->decodeIdToken($tokens['id_token']);

            // Upsert user in our database
            $userRepo = new UserRepository();
            $user     = $userRepo->upsertFromKeycloak($profile);

            // Store tokens for future API calls if needed
            $user['access_token']  = $tokens['access_token'];
            $user['refresh_token'] = $tokens['refresh_token'] ?? null;

            AuthMiddleware::login($user);

            AuditService::log('login', $user['id'], 'user', $user['id']);

        } catch (Throwable $e) {
            error_log('Auth callback error: ' . $e->getMessage());
            $this->renderError("Login failed. Please try again.");
            return;
        }

        $intended = $_SESSION['intended_url'] ?? '/dashboard';
        unset($_SESSION['intended_url']);
        header("Location: {$intended}");
        exit;
    }

    /**
     * Log the user out locally and redirect to Keycloak logout.
     */
    public function logout(): void
    {
        $user = AuthMiddleware::user();
        if ($user) {
            AuditService::log('logout', $user['id'] ?? null);
        }

        $keycloak   = new KeycloakService();
        $logoutUrl  = $keycloak->buildLogoutUrl();

        AuthMiddleware::logout();

        header("Location: {$logoutUrl}");
        exit;
    }

    private function renderError(string $message): void
    {
        require __DIR__ . '/../Views/auth/error.php';
    }
}
