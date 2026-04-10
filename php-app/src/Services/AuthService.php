<?php
/**
 * Authentication Service (Keycloak OIDC)
 */

class AuthService
{
    private $config;
    private $db;

    public function __construct($config, $db)
    {
        $this->config = $config;
        $this->db = $db;
    }

    /**
     * Get Keycloak authorization URL
     */
    public function getAuthorizationUrl()
    {
        $params = [
            'client_id' => $this->config['client_id'],
            'redirect_uri' => $this->config['redirect_uri'],
            'response_type' => 'code',
            'scope' => 'openid email profile',
            'state' => $this->generateState(),
        ];

        $authUrl = sprintf(
            '%s/realms/%s/protocol/openid-connect/auth?%s',
            $this->config['server_url'],
            $this->config['realm'],
            http_build_query($params)
        );

        return $authUrl;
    }

    /**
     * Exchange authorization code for tokens
     */
    public function exchangeCode($code)
    {
        $tokenUrl = sprintf(
            '%s/realms/%s/protocol/openid-connect/token',
            $this->config['server_url'],
            $this->config['realm']
        );

        $data = [
            'grant_type' => 'authorization_code',
            'client_id' => $this->config['client_id'],
            'client_secret' => $this->config['client_secret'],
            'code' => $code,
            'redirect_uri' => $this->config['redirect_uri'],
        ];

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $tokenUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

        $response = curl_exec($ch);
        curl_close($ch);

        return json_decode($response, true);
    }

    /**
     * Get user info from token
     */
    public function getUserInfo($accessToken)
    {
        $userInfoUrl = sprintf(
            '%s/realms/%s/protocol/openid-connect/userinfo',
            $this->config['server_url'],
            $this->config['realm']
        );

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $userInfoUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $accessToken,
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        return json_decode($response, true);
    }

    /**
     * Create or update user in database
     */
    public function syncUser($userInfo)
    {
        $keycloakId = $userInfo['sub'];
        $username = $userInfo['preferred_username'] ?? $userInfo['email'];
        $email = $userInfo['email'];

        // Check if user exists
        $existing = $this->db->fetchOne(
            'SELECT * FROM users WHERE keycloak_id = ?',
            [$keycloakId]
        );

        if ($existing) {
            // Update existing user
            $this->db->query(
                'UPDATE users SET username = ?, email = ?, last_login_at = CURRENT_TIMESTAMP WHERE keycloak_id = ?',
                [$username, $email, $keycloakId]
            );
            return $existing['id'];
        } else {
            // Create new user
            $this->db->query(
                'INSERT INTO users (username, email, keycloak_id, roles, last_login_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)',
                [$username, $email, $keycloakId, '{user}']
            );
            return $this->db->lastInsertId();
        }
    }

    /**
     * Generate state parameter
     */
    private function generateState()
    {
        $state = bin2hex(random_bytes(16));
        $_SESSION['oauth_state'] = $state;
        return $state;
    }

    /**
     * Validate state parameter
     */
    public function validateState($state)
    {
        if (!isset($_SESSION['oauth_state'])) {
            return false;
        }
        $valid = hash_equals($_SESSION['oauth_state'], $state);
        unset($_SESSION['oauth_state']);
        return $valid;
    }

    /**
     * Check if user is authenticated
     */
    public function isAuthenticated()
    {
        return isset($_SESSION['user_id']);
    }

    /**
     * Get current user
     */
    public function getCurrentUser()
    {
        if (!$this->isAuthenticated()) {
            return null;
        }

        return $this->db->fetchOne(
            'SELECT * FROM users WHERE id = ?',
            [$_SESSION['user_id']]
        );
    }

    /**
     * Check if user has role
     */
    public function hasRole($role)
    {
        $user = $this->getCurrentUser();
        if (!$user) {
            return false;
        }

        $roles = $user['roles'];
        if (is_string($roles)) {
            // Parse PostgreSQL array format
            $roles = trim($roles, '{}');
            $roles = explode(',', $roles);
        }

        return in_array($role, $roles);
    }

    /**
     * Logout
     */
    public function logout()
    {
        session_destroy();
        session_start();
    }
}
