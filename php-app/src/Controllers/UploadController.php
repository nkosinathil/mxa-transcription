<?php
/**
 * Upload Controller
 */

class UploadController
{
    private $auth;
    private $db;
    private $api;
    private $config;

    public function __construct($auth, $db, $api, $config)
    {
        $this->auth = $auth;
        $this->db = $db;
        $this->api = $api;
        $this->config = $config;
    }

    /**
     * Handle file upload
     */
    public function upload()
    {
        // Verify CSRF token
        CsrfService::check();

        // Check authentication
        if (!$this->auth->isAuthenticated()) {
            http_response_code(401);
            die('Unauthorized');
        }

        // Validate file upload
        if (!isset($_FILES['audio_file']) || $_FILES['audio_file']['error'] !== UPLOAD_ERR_OK) {
            $this->redirectWithError('File upload failed');
            return;
        }

        $file = $_FILES['audio_file'];
        $filename = basename($file['name']);
        $tmpPath = $file['tmp_name'];
        $fileSize = $file['size'];

        // Validate file size
        if ($fileSize > $this->config['upload']['max_size']) {
            $this->redirectWithError('File too large. Maximum size: ' . ($this->config['upload']['max_size'] / (1024*1024)) . 'MB');
            return;
        }

        // Validate file extension
        $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
        if (!in_array($ext, $this->config['upload']['allowed_extensions'])) {
            $this->redirectWithError('Invalid file type. Allowed: ' . implode(', ', $this->config['upload']['allowed_extensions']));
            return;
        }

        try {
            $userId = $_SESSION['user_id'];

            // Generate job ID
            $jobId = $this->generateUuid();

            // Create job in database
            $this->db->query(
                'INSERT INTO jobs (id, user_id, status, filename, file_size, file_hash) VALUES (?, ?, ?, ?, ?, ?)',
                [$jobId, $userId, 'pending', $filename, $fileSize, hash_file('sha256', $tmpPath)]
            );

            // Upload to Python API
            $result = $this->api->uploadAudio($tmpPath, $jobId);

            // Update job status
            $this->db->query(
                'UPDATE jobs SET status = ? WHERE id = ?',
                ['queued', $jobId]
            );

            // Log audit event
            $this->db->query(
                'INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address) VALUES (?, ?, ?, ?, ?)',
                [$userId, 'upload', 'job', $jobId, $_SERVER['REMOTE_ADDR']]
            );

            // Redirect to job page
            header('Location: /jobs/' . $jobId);
            exit;

        } catch (Exception $e) {
            error_log('Upload error: ' . $e->getMessage());
            $this->redirectWithError('Upload failed: ' . $e->getMessage());
        }
    }

    private function redirectWithError($message)
    {
        $_SESSION['error'] = $message;
        header('Location: /upload');
        exit;
    }

    private function generateUuid()
    {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
}
