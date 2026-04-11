<?php
/**
 * php-app/src/Views/layout.php
 * --------------------------------
 * Master HTML layout template.
 *
 * Usage:
 *   $pageTitle  = 'Dashboard';
 *   $bodyClass  = 'page-dashboard';
 *   ob_start();
 *   // … page content …
 *   $content = ob_get_clean();
 *   require __DIR__ . '/layout.php';
 *
 * Variables expected from calling view:
 *   $pageTitle  string  – shown in <title> and top bar
 *   $content    string  – the main body HTML
 *   $bodyClass  string  – optional CSS class on <body>
 */

use App\Middleware\AuthMiddleware;
use App\Middleware\RoleMiddleware;
use App\Services\CsrfService;

$user       = AuthMiddleware::user();
$pageTitle  = $pageTitle  ?? 'MXA Transcription';
$bodyClass  = $bodyClass  ?? '';
$flashError = $_SESSION['flash_error'] ?? null;
$flashOk    = $_SESSION['flash_ok']    ?? null;
unset($_SESSION['flash_error'], $_SESSION['flash_ok']);

$currentPath = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$csrfToken = CsrfService::generate();
function navActive(string $prefix): string {
    global $currentPath;
    return str_starts_with($currentPath, $prefix) ? 'nav-active' : '';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($pageTitle) ?> – MXA Transcription</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body class="<?= htmlspecialchars($bodyClass) ?>">

<!-- ================================================================== -->
<!-- SIDEBAR NAVIGATION                                                    -->
<!-- ================================================================== -->
<nav class="sidebar" id="sidebar">
    <div class="sidebar-logo">
        <span class="logo-icon">🎙️</span>
        <span class="logo-text">MXA Transcription</span>
    </div>

    <ul class="nav-list">
        <li>
            <a href="/dashboard" class="nav-item <?= navActive('/dashboard') ?> <?= $currentPath === '/' ? 'nav-active' : '' ?>">
                <span class="nav-icon">⊞</span>
                <span class="nav-label">Dashboard</span>
            </a>
        </li>
        <li>
            <a href="/cases" class="nav-item <?= navActive('/cases') ?>">
                <span class="nav-icon">📁</span>
                <span class="nav-label">Cases</span>
            </a>
        </li>
        <li>
            <a href="/jobs" class="nav-item <?= navActive('/jobs') ?>">
                <span class="nav-icon">⚙️</span>
                <span class="nav-label">Processing Queue</span>
            </a>
        </li>
    </ul>

    <div class="sidebar-footer">
        <?php if ($user): ?>
            <div class="user-card">
                <div class="user-avatar"><?= strtoupper(substr($user['name'], 0, 1)) ?></div>
                <div class="user-info">
                    <div class="user-name"><?= htmlspecialchars($user['name']) ?></div>
                    <div class="user-role"><?= htmlspecialchars(ucfirst($user['role'])) ?></div>
                </div>
            </div>
            <a href="/auth/logout" class="btn-logout">Sign out</a>
        <?php endif; ?>
    </div>
</nav>

<!-- ================================================================== -->
<!-- MAIN CONTENT                                                          -->
<!-- ================================================================== -->
<main class="main-content">
    <header class="top-bar">
        <button class="sidebar-toggle" id="sidebarToggle" aria-label="Toggle navigation">☰</button>
        <h1 class="page-title"><?= htmlspecialchars($pageTitle) ?></h1>
    </header>

    <div class="content-body">
        <?php if ($flashError): ?>
            <div class="alert alert-error"><?= htmlspecialchars($flashError) ?></div>
        <?php endif; ?>
        <?php if ($flashOk): ?>
            <div class="alert alert-ok"><?= htmlspecialchars($flashOk) ?></div>
        <?php endif; ?>

        <?= $content ?>
    </div>
</main>

<script src="/assets/js/app.js"></script>
<script>
window.MXA_CSRF_TOKEN = <?= json_encode($csrfToken, JSON_THROW_ON_ERROR) ?>;
</script>
</body>
</html>
