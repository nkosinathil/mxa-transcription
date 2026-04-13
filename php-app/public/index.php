<?php
/**
 * php-app/public/index.php
 * --------------------------
 * Front controller – every HTTP request comes through this single file.
 *
 * Plain-language:
 *   Apache is configured to route all requests to this file (via .htaccess).
 *   This file boots the application, reads the URL, finds the matching route,
 *   and calls the correct controller action.
 *
 *   This is a lightweight router – no framework needed for this use case.
 */

declare(strict_types=1);

// Bootstrap the application (autoloader, .env, session, config)
require_once __DIR__ . '/../src/bootstrap.php';

$routes = require __DIR__ . '/../src/Config/routes.php';

// Build request key: "METHOD /path"
$method = strtoupper($_SERVER['REQUEST_METHOD']);
$uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri    = '/' . ltrim(rtrim($uri, '/'), '/');   // normalise

// Attempt exact match first
$routeKey = "$method $uri";

if (isset($routes[$routeKey])) {
    [$class, $action] = $routes[$routeKey];
    (new $class())->$action();
    exit;
}

// Attempt pattern match (routes with {id} placeholders)
foreach ($routes as $pattern => $handler) {
    // Convert "GET /cases/{id}" → regex
    $regex = preg_replace('/\{[a-z_]+\}/', '([^/]+)', $pattern);
    $regex = "#^{$regex}$#";

    // Split into method + path
    [$routeMethod, $routePath] = explode(' ', $pattern, 2);
    $routeRegex = '#^' . preg_replace('/\{[a-z_]+\}/', '([^/]+)', $routePath) . '$#';

    if ($routeMethod === $method && preg_match($routeRegex, $uri, $matches)) {
        array_shift($matches);   // remove full match
        $params = array_map(fn($v) => is_numeric($v) ? (int)$v : $v, $matches);
        [$class, $action] = $handler;
        (new $class())->$action(...$params);
        exit;
    }
}

// No route matched – 404
http_response_code(404);
require __DIR__ . '/../src/Views/errors/404.php';
