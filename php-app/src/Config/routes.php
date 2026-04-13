<?php
/**
 * php-app/src/Config/routes.php
 * --------------------------------
 * Simple route table.
 *
 * Plain-language:
 *   Maps URL paths to controller actions.  The front controller (public/index.php)
 *   reads this table and calls the correct controller.
 *
 * Format:
 *   'METHOD /path' => ['ControllerClass', 'methodName']
 */

declare(strict_types=1);

return [
    // ---- Authentication ----
    'GET /auth/login'     => [\App\Controllers\AuthController::class, 'login'],
    'GET /auth/callback'  => [\App\Controllers\AuthController::class, 'callback'],
    'GET /auth/logout'    => [\App\Controllers\AuthController::class, 'logout'],

    // ---- Dashboard ----
    'GET /'               => [\App\Controllers\DashboardController::class, 'index'],
    'GET /dashboard'      => [\App\Controllers\DashboardController::class, 'index'],

    // ---- Cases ----
    'GET /cases'          => [\App\Controllers\CaseController::class, 'index'],
    'GET /cases/create'   => [\App\Controllers\CaseController::class, 'create'],
    'POST /cases'         => [\App\Controllers\CaseController::class, 'store'],
    'GET /cases/{id}'     => [\App\Controllers\CaseController::class, 'show'],

    // ---- Uploads ----
    'GET /upload/{case_id}'  => [\App\Controllers\UploadController::class, 'form'],
    'POST /upload'           => [\App\Controllers\UploadController::class, 'store'],

    // ---- Jobs ----
    'GET /jobs'                  => [\App\Controllers\JobController::class, 'index'],
    'POST /jobs/{upload_id}/start'=> [\App\Controllers\JobController::class, 'start'],
    'GET /jobs/{id}/status'      => [\App\Controllers\JobController::class, 'status'],

    // ---- Results ----
    'GET /results/{job_id}'      => [\App\Controllers\ResultController::class, 'show'],
    'GET /results/{job_id}/download' => [\App\Controllers\ResultController::class, 'download'],
];
