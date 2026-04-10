<?php
/**
 * php-app/src/Controllers/CaseController.php
 */

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Middleware\RoleMiddleware;
use App\Repositories\CaseRepository;
use App\Repositories\UploadRepository;
use App\Repositories\JobRepository;
use App\Services\AuditService;

class CaseController
{
    public function index(): void
    {
        AuthMiddleware::require();
        $user  = AuthMiddleware::user();
        $repo  = new CaseRepository();
        $cases = $repo->findByUser($user['id']);
        require __DIR__ . '/../Views/cases/index.php';
    }

    public function create(): void
    {
        RoleMiddleware::require('analyst');
        require __DIR__ . '/../Views/cases/create.php';
    }

    public function store(): void
    {
        RoleMiddleware::require('analyst');
        $user = AuthMiddleware::user();

        $name        = trim($_POST['name']        ?? '');
        $description = trim($_POST['description'] ?? '');

        if (!$name) {
            $_SESSION['flash_error'] = 'Case name is required.';
            header('Location: /cases/create');
            exit;
        }

        $repo = new CaseRepository();
        $case = $repo->create($user['id'], htmlspecialchars($name, ENT_QUOTES), htmlspecialchars($description, ENT_QUOTES));

        AuditService::log('create_case', $user['id'], 'case', $case['id']);

        header("Location: /cases/{$case['id']}");
        exit;
    }

    public function show(int $id): void
    {
        AuthMiddleware::require();
        $user     = AuthMiddleware::user();
        $caseRepo = new CaseRepository();
        $case     = $caseRepo->findById($id, $user['id']);

        if (!$case) {
            http_response_code(404);
            require __DIR__ . '/../Views/errors/404.php';
            return;
        }

        $uploadRepo = new UploadRepository();
        $jobRepo    = new JobRepository();
        $uploads    = $uploadRepo->findByCase($id);
        $jobs       = $jobRepo->findByCase($id);

        require __DIR__ . '/../Views/cases/show.php';
    }
}
