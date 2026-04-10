<?php
/**
 * Main index.php - Application entry point
 */

// Start session
session_start();

// Load configuration
$config = require __DIR__ . '/../config/config.php';

// Auto-loader for classes
spl_autoload_register(function ($class) {
    $paths = [
        __DIR__ . '/../src/Controllers/' . $class . '.php',
        __DIR__ . '/../src/Services/' . $class . '.php',
        __DIR__ . '/../src/Models/' . $class . '.php',
    ];
    
    foreach ($paths as $path) {
        if (file_exists($path)) {
            require_once $path;
            return;
        }
    }
});

// Initialize database
try {
    $db = Database::getInstance($config['db']);
} catch (Exception $e) {
    die('Database connection failed. Please check configuration.');
}

// Initialize services
$auth = new AuthService($config['keycloak'], $db);
$api = new ApiClient($config['api']);

// Simple routing
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];

// Route handlers
switch ($uri) {
    case '/':
    case '/index.php':
        if (!$auth->isAuthenticated()) {
            header('Location: /auth/login');
            exit;
        }
        require __DIR__ . '/../src/Views/dashboard.php';
        break;
        
    case '/auth/login':
        $authUrl = $auth->getAuthorizationUrl();
        header('Location: ' . $authUrl);
        exit;
        
    case '/auth/callback':
        $controller = new AuthController($auth, $db);
        $controller->callback();
        break;
        
    case '/auth/logout':
        $auth->logout();
        header('Location: /');
        exit;
        
    case '/upload':
        if (!$auth->isAuthenticated()) {
            header('Location: /auth/login');
            exit;
        }
        if ($method === 'GET') {
            require __DIR__ . '/../src/Views/upload.php';
        } else {
            $controller = new UploadController($auth, $db, $api, $config);
            $controller->upload();
        }
        break;
        
    case (preg_match('/^\/jobs\/([a-f0-9\-]+)$/', $uri, $matches) ? true : false):
        if (!$auth->isAuthenticated()) {
            header('Location: /auth/login');
            exit;
        }
        $jobId = $matches[1];
        $controller = new JobController($auth, $db, $api);
        $controller->view($jobId);
        break;
        
    case '/jobs':
        if (!$auth->isAuthenticated()) {
            header('Location: /auth/login');
            exit;
        }
        $controller = new JobController($auth, $db, $api);
        $controller->list();
        break;
        
    default:
        http_response_code(404);
        echo '404 - Page not found';
        break;
}
