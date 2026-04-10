<?php
/**
 * php-app/src/Controllers/UploadController.php
 * -----------------------------------------------
 * Handles audio file uploads.
 *
 * Plain-language:
 *   The user selects an audio file in the web browser.  PHP receives it,
 *   forwards it to the Python API (which stores it in MinIO), then records
 *   the metadata in PostgreSQL.  The actual file never ends up on the PHP
 *   server's disk for more than a fraction of a second.
 */

declare(strict_types=1);

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Middleware\RoleMiddleware;
use App\Repositories\CaseRepository;
use App\Repositories\UploadRepository;
use App\Services\AuditService;
use App\Services\PythonApiClient;

class UploadController
{
    public function form(int $caseId): void
    {
        RoleMiddleware::require('analyst');
        $user     = AuthMiddleware::user();
        $caseRepo = new CaseRepository();
        $case     = $caseRepo->findById($caseId, $user['id']);

        if (!$case) {
            http_response_code(404);
            require __DIR__ . '/../Views/errors/404.php';
            return;
        }

        require __DIR__ . '/../Views/upload/form.php';
    }

    public function store(): void
    {
        RoleMiddleware::require('analyst');
        $user = AuthMiddleware::user();

        $caseId = (int) ($_POST['case_id'] ?? 0);
        if (!$caseId) {
            $this->jsonError('Missing case_id', 422);
            return;
        }

        if (empty($_FILES['audio_file']) || $_FILES['audio_file']['error'] !== UPLOAD_ERR_OK) {
            $this->jsonError('No file uploaded or upload error.', 422);
            return;
        }

        $file      = $_FILES['audio_file'];
        $tmpPath   = $file['tmp_name'];
        $fileName  = basename($file['name']);
        $mimeType  = $file['type'] ?? 'application/octet-stream';
        $sizeBytes = $file['size'];

        // Send to Python API → MinIO
        try {
            $api      = new PythonApiClient();
            $result   = $api->uploadAudio($tmpPath, $fileName, $caseId);
        } catch (\Throwable $e) {
            error_log('Upload to Python API failed: ' . $e->getMessage());
            $this->jsonError('File upload to storage failed: ' . $e->getMessage(), 500);
            return;
        }

        // Record in PostgreSQL
        $uploadRepo = new UploadRepository();
        $upload     = $uploadRepo->create(
            caseId:      $caseId,
            userId:      $user['id'],
            filename:    $fileName,
            minioBucket: $result['minio_bucket'],
            minioPath:   $result['minio_path'],
            sizeBytes:   $result['size_bytes'] ?? $sizeBytes,
            sha256:      $result['sha256']     ?? '',
            mimeType:    $mimeType
        );

        AuditService::log('upload', $user['id'], 'upload', $upload['id'], [
            'filename' => $fileName,
            'case_id'  => $caseId,
        ]);

        header('Content-Type: application/json');
        echo json_encode([
            'success'   => true,
            'upload_id' => $upload['id'],
            'filename'  => $fileName,
        ]);
    }

    private function jsonError(string $message, int $code = 400): void
    {
        http_response_code($code);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => $message]);
    }
}
