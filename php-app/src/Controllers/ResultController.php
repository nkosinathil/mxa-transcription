<?php
/**
 * php-app/src/Controllers/ResultController.php
 * -----------------------------------------------
 * Displays and downloads transcription results.
 */

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Repositories\CaseRepository;
use App\Repositories\JobRepository;
use App\Services\AuditService;
use App\Services\PythonApiClient;

class ResultController
{
    public function show(int $jobId): void
    {
        AuthMiddleware::require();
        $user    = AuthMiddleware::user();
        $jobRepo = new JobRepository();
        $job     = $jobRepo->findById($jobId);

        if (!$job) {
            http_response_code(404);
            require __DIR__ . '/../Views/errors/404.php';
            return;
        }

        $caseRepo = new CaseRepository();
        $case = $caseRepo->findById((int) $job['case_id'], (int) $user['id']);
        if (!$case) {
            http_response_code(404);
            require __DIR__ . '/../Views/errors/404.php';
            return;
        }

        $result = $jobRepo->findResult($jobId);
        $events = $jobRepo->findEvents($jobId);

        // If not yet complete, fetch latest from Python API
        if ($job['status'] === 'completed' && !$result) {
            try {
                $api    = new PythonApiClient();
                $result = $api->getJobResult($jobId);
            } catch (\Throwable $e) {
                $result = null;
            }
        }

        require __DIR__ . '/../Views/results/show.php';
    }

    /**
     * Proxy the transcript text file download through PHP so we can log it.
     */
    public function download(int $jobId): void
    {
        AuthMiddleware::require();
        $user    = AuthMiddleware::user();
        $jobRepo = new JobRepository();
        $job     = $jobRepo->findById($jobId);

        if (!$job) {
            http_response_code(403);
            echo 'Access denied.';
            return;
        }

        $caseRepo = new CaseRepository();
        $case = $caseRepo->findById((int) $job['case_id'], (int) $user['id']);
        if (!$case) {
            http_response_code(403);
            echo 'Access denied.';
            return;
        }

        $result = $jobRepo->findResult($jobId);
        if (!$result || empty($result['minio_transcript_path'])) {
            http_response_code(404);
            echo 'Transcript not available.';
            return;
        }

        // Fetch transcript bytes from MinIO via Python API
        try {
            $api     = new PythonApiClient();
            $full    = $api->getJobResult($jobId);
            $segments = $full['segments'] ?? [];
            if (!is_array($segments)) {
                $segments = [];
            }
            $lines = [];
            foreach ($segments as $seg) {
                if (!is_array($seg)) {
                    continue;
                }
                $speaker = (string) ($seg['speaker'] ?? 'Speaker 1');
                $text = trim((string) ($seg['text'] ?? ''));
                if ($text === '') {
                    continue;
                }
                $lines[] = sprintf("[%s] %s", $speaker, $text);
            }
            $content = implode("\n", $lines);
        } catch (\Throwable $e) {
            http_response_code(500);
            echo 'Could not retrieve transcript.';
            return;
        }

        AuditService::log('download_transcript', $user['id'], 'job', $jobId);

        $filename = 'transcript_job_' . $jobId . '.txt';
        header('Content-Type: text/plain; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . $filename . '"');
        echo $content;
    }
}
