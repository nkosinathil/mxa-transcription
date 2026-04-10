<?php
/**
 * Authentication Controller
 */

class AuthController
{
    private $auth;
    private $db;

    public function __construct($auth, $db)
    {
        $this->auth = $auth;
        $this->db = $db;
    }

    /**
     * Handle OAuth callback from Keycloak
     */
    public function callback()
    {
        // Validate state
        $state = $_GET['state'] ?? '';
        if (!$this->auth->validateState($state)) {
            die('Invalid state parameter');
        }

        // Get authorization code
        $code = $_GET['code'] ?? '';
        if (!$code) {
            die('Authorization code not provided');
        }

        try {
            // Exchange code for tokens
            $tokens = $this->auth->exchangeCode($code);
            
            if (!isset($tokens['access_token'])) {
                throw new Exception('Failed to obtain access token');
            }

            // Get user info
            $userInfo = $this->auth->getUserInfo($tokens['access_token']);
            
            // Sync user to database
            $userId = $this->auth->syncUser($userInfo);

            // Store session data
            $_SESSION['user_id'] = $userId;
            $_SESSION['access_token'] = $tokens['access_token'];
            $_SESSION['refresh_token'] = $tokens['refresh_token'] ?? null;

            // Log audit event
            $this->db->query(
                'INSERT INTO audit_logs (user_id, action, ip_address, user_agent) VALUES (?, ?, ?, ?)',
                [$userId, 'login', $_SERVER['REMOTE_ADDR'], $_SERVER['HTTP_USER_AGENT'] ?? '']
            );

            // Redirect to dashboard
            header('Location: /');
            exit;

        } catch (Exception $e) {
            error_log('Authentication error: ' . $e->getMessage());
            die('Authentication failed. Please try again.');
        }
    }
}
