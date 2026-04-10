<?php
/**
 * php-app/src/Controllers/JobController.php
 * --------------------------------------------
 * Starts processing jobs and returns their status.
 */

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Middleware\RoleMiddleware;
use App\Repositories\JobRepository;
use App\Repositories\UploadRepository;
use App\Services\AuditService;
use App\Services\PythonApiClient;

class JobController
{
    public function index(): void
    {
        AuthMiddleware::require();
        $user     = AuthMiddleware::user();
        $jobRepo  = new JobRepository();
        $jobs     = $jobRepo->findByUser($user['id']);
        require __DIR__ . '/../Views/jobs/index.php';
    }

    /**
     * Queue a transcription job for an uploaded file.
     * Called by AJAX POST /jobs/{upload_id}/start
     */
    public function start(int $uploadId): void
    {
        RoleMiddleware::require('analyst');
        $user = AuthMiddleware::user();

        $uploadRepo = new UploadRepository();
        $upload     = $uploadRepo->findById($uploadId);

        if (!$upload || $upload['user_id'] !== $user['id']) {
            $this->jsonError('Upload not found or not yours.', 404);
            return;
        }

        // Create processing_jobs row
        $jobRepo = new JobRepository();
        $job     = $jobRepo->create(
            uploadId:    $uploadId,
            caseId:      $upload['case_id'],
            userId:      $user['id'],
            modelSize:   $_POST['model_size']  ?? 'base',
            device:      $_POST['device']      ?? 'auto',
            computeType: $_POST['compute_type']?? null,
            diarization: ($_POST['diarization'] ?? '1') === '1',
        );

        // Call Python API to queue Celery task
        try {
            $api    = new PythonApiClient();
            $result = $api->startProcessing([
                'job_id'              => $job['id'],
                'minio_bucket'        => $upload['minio_bucket'],
                'minio_path'          => $upload['minio_path'],
                'original_filename'   => $upload['filename'],
                'model_size'          => $job['model_size'],
                'device'              => $job['device'],
                'compute_type'        => $job['compute_type'],
                'diarization_enabled' => (bool) $job['diarization'],
            ]);
        } catch (\Throwable $e) {
            error_log('Failed to start job: ' . $e->getMessage());
            $this->jsonError('Failed to start processing: ' . $e->getMessage(), 500);
            return;
        }

        // Store Celery task ID
        $jobRepo->updateCeleryTaskId($job['id'], $result['celery_task_id']);

        AuditService::log('start_job', $user['id'], 'job', $job['id'], [
            'upload_id' => $uploadId,
        ]);

        header('Content-Type: application/json');
        echo json_encode([
            'success'        => true,
            'job_id'         => $job['id'],
            'celery_task_id' => $result['celery_task_id'],
            'status'         => 'queued',
        ]);
    }

    /**
     * Return job status as JSON.  Called by JavaScript polling.
     */
    public function status(int $id): void
    {
        AuthMiddleware::require();
        $user = AuthMiddleware::user();

        $jobRepo = new JobRepository();
        $job     = $jobRepo->findById($id);

        if (!$job || $job['user_id'] !== $user['id']) {
            $this->jsonError('Job not found.', 404);
            return;
        }

        // Fetch fresh status from Python API
        try {
            $api    = new PythonApiClient();
            $status = $api->getJobStatus($id);

            // Sync status back to PostgreSQL
            $jobRepo->updateStatus($id, $status['status'], $status['progress']);
        } catch (\Throwable $e) {
            // Fall back to local database status
            $status = [
                'job_id'   => $id,
                'status'   => $job['status'],
                'progress' => $job['progress'],
                'events'   => $jobRepo->findEvents($id),
            ];
        }

        header('Content-Type: application/json');
        echo json_encode($status);
    }

    private function jsonError(string $message, int $code = 400): void
    {
        http_response_code($code);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => $message]);
    }
}
