<?php
/**
 * php-app/src/Controllers/DashboardController.php
 */

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Repositories\JobRepository;
use App\Repositories\CaseRepository;

class DashboardController
{
    public function index(): void
    {
        AuthMiddleware::require();
        $user = AuthMiddleware::user();

        $jobRepo  = new JobRepository();
        $caseRepo = new CaseRepository();

        $recentJobs  = $jobRepo->findByUser($user['id'], 10);
        $cases       = $caseRepo->findByUser($user['id']);

        $stats = [
            'total_cases'     => count($cases),
            'queued'          => 0,
            'processing'      => 0,
            'completed'       => 0,
            'failed'          => 0,
        ];
        foreach ($recentJobs as $job) {
            $status = $job['status'] ?? 'queued';
            if (isset($stats[$status])) {
                $stats[$status]++;
            }
        }

        require __DIR__ . '/../Views/dashboard.php';
    }
}
