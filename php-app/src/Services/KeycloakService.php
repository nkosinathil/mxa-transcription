<?php
/**
 * php-app/src/Services/KeycloakService.php
 * ------------------------------------------
 * Handles Keycloak OIDC Authorization Code Flow.
 *
 * Plain-language:
 *   Keycloak is the login system.  When a user clicks "Login", we redirect
 *   them to Keycloak.  After they enter their username and password, Keycloak
 *   redirects them back to our /auth/callback URL with an "authorization code".
 *   We exchange that code for tokens, decode the tokens, and create a session.
 *
 *   This file handles all three of those steps.
 *
 * OIDC endpoints used:
 *   - Authorization: /realms/{realm}/protocol/openid-connect/auth
 *   - Token:         /realms/{realm}/protocol/openid-connect/token
 *   - UserInfo:      /realms/{realm}/protocol/openid-connect/userinfo
 *   - Logout:        /realms/{realm}/protocol/openid-connect/logout
 */

declare(strict_types=1);

namespace App\Services;

use App\Config\Config;
use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use RuntimeException;

class KeycloakService
{
    private string $baseUrl;
    private string $realm;
    private string $clientId;
    private string $clientSecret;
    private string $redirectUri;
    private string $realmUrl;
    private Client $http;

    public function __construct()
    {
        $this->baseUrl       = Config::get('keycloak.base_url');
        $this->realm         = Config::get('keycloak.realm');
        $this->clientId      = Config::get('keycloak.client_id');
        $this->clientSecret  = Config::get('keycloak.client_secret');
        $this->redirectUri   = Config::get('keycloak.redirect_uri');
        $this->realmUrl      = "{$this->baseUrl}/realms/{$this->realm}";
        $this->http          = new Client([
            'timeout' => 10,
            'verify'  => Config::get('keycloak.verify_tls', true),
        ]);
    }

    /**
     * Build the Keycloak login URL and store a PKCE state parameter in the session.
     */
    public function buildLoginUrl(): string
    {
        $state = bin2hex(random_bytes(16));
        $_SESSION['oauth_state'] = $state;

        $params = http_build_query([
            'client_id'     => $this->clientId,
            'response_type' => 'code',
            'scope'         => 'openid email profile',
            'redirect_uri'  => $this->redirectUri,
            'state'         => $state,
        ]);

        return "{$this->realmUrl}/protocol/openid-connect/auth?{$params}";
    }

    /**
     * Exchange the authorization code for tokens.
     *
     * @return array{access_token: string, id_token: string, refresh_token: string}
     * @throws RuntimeException on failure
     */
    public function exchangeCode(string $code, string $state): array
    {
        // Verify state to prevent CSRF
        if (!isset($_SESSION['oauth_state']) || $_SESSION['oauth_state'] !== $state) {
            throw new RuntimeException('OAuth state mismatch – possible CSRF attack.');
        }
        unset($_SESSION['oauth_state']);

        try {
            $response = $this->http->post(
                "{$this->realmUrl}/protocol/openid-connect/token",
                [
                    'form_params' => [
                        'grant_type'    => 'authorization_code',
                        'code'          => $code,
                        'redirect_uri'  => $this->redirectUri,
                        'client_id'     => $this->clientId,
                        'client_secret' => $this->clientSecret,
                    ],
                ]
            );
        } catch (GuzzleException $e) {
            throw new RuntimeException('Token exchange failed: ' . $e->getMessage());
        }

        $tokens = json_decode((string) $response->getBody(), true, 512, JSON_THROW_ON_ERROR);

        if (empty($tokens['access_token'])) {
            throw new RuntimeException('No access_token in Keycloak response.');
        }

        return $tokens;
    }

    /**
     * Decode a Keycloak ID token and extract user profile + roles.
     *
     * Verifies the JWT signature against Keycloak JWKS and validates
     * issuer / audience claims before accepting the token.
     *
     * @return array<string,mixed>
     */
    public function decodeIdToken(string $idToken): array
    {
        try {
            $jwksResponse = $this->http->get("{$this->realmUrl}/protocol/openid-connect/certs");
            $jwks = json_decode((string) $jwksResponse->getBody(), true, 512, JSON_THROW_ON_ERROR);
            $decoded = JWT::decode($idToken, JWK::parseKeySet($jwks));
            $payload = json_decode(json_encode($decoded, JSON_THROW_ON_ERROR), true, 512, JSON_THROW_ON_ERROR);
        } catch (\Throwable $e) {
            throw new RuntimeException('ID token signature verification failed: ' . $e->getMessage());
        }

        $issuer = $payload['iss'] ?? null;
        if ($issuer !== $this->realmUrl) {
            throw new RuntimeException('ID token issuer mismatch.');
        }

        $aud = $payload['aud'] ?? null;
        $audiences = is_array($aud) ? $aud : [$aud];
        if (!in_array($this->clientId, $audiences, true)) {
            throw new RuntimeException('ID token audience mismatch.');
        }

        // Basic expiry check
        if (!empty($payload['exp']) && $payload['exp'] < time()) {
            throw new RuntimeException('ID token has expired.');
        }

        // Extract realm roles
        $realmRoles = $payload['realm_access']['roles'] ?? [];
        $payload['roles'] = $realmRoles;

        return $payload;
    }

    /**
     * Build the Keycloak logout URL.
     */
    public function buildLogoutUrl(): string
    {
        $params = http_build_query([
            'client_id'    => $this->clientId,
            'post_logout_redirect_uri' => Config::get('app.url') . '/auth/login',
        ]);
        return "{$this->realmUrl}/protocol/openid-connect/logout?{$params}";
    }

    /**
     * Refresh the access token using the refresh token.
     *
     * @return array<string,mixed>
     */
    public function refreshToken(string $refreshToken): array
    {
        try {
            $response = $this->http->post(
                "{$this->realmUrl}/protocol/openid-connect/token",
                [
                    'form_params' => [
                        'grant_type'    => 'refresh_token',
                        'refresh_token' => $refreshToken,
                        'client_id'     => $this->clientId,
                        'client_secret' => $this->clientSecret,
                    ],
                ]
            );
        } catch (GuzzleException $e) {
            throw new RuntimeException('Token refresh failed: ' . $e->getMessage());
        }

        return json_decode((string) $response->getBody(), true, 512, JSON_THROW_ON_ERROR);
    }
}
