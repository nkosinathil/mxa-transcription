<?php
/**
 * Job Controller
 */

class JobController
{
    private $auth;
    private $db;
    private $api;

    public function __construct($auth, $db, $api)
    {
        $this->auth = $auth;
        $this->db = $db;
        $this->api = $api;
    }

    /**
     * List user's jobs
     */
    public function list()
    {
        $user = $this->auth->getCurrentUser();
        
        // Get jobs for current user
        $jobs = $this->db->fetchAll(
            'SELECT * FROM jobs WHERE user_id = ? ORDER BY created_at DESC LIMIT 50',
            [$user['id']]
        );

        require __DIR__ . '/../Views/jobs.php';
    }

    /**
     * View job details
     */
    public function view($jobId)
    {
        $user = $this->auth->getCurrentUser();

        // Get job from database
        $job = $this->db->fetchOne(
            'SELECT * FROM jobs WHERE id = ?',
            [$jobId]
        );

        if (!$job) {
            http_response_code(404);
            die('Job not found');
        }

        // Check ownership (or admin role)
        if ($job['user_id'] !== $user['id'] && !$this->auth->hasRole('admin')) {
            http_response_code(403);
            die('Access denied');
        }

        // Get transcript if completed
        $transcript = null;
        if ($job['status'] === 'completed') {
            try {
                $transcript = $this->api->getTranscriptJson($jobId);
            } catch (Exception $e) {
                error_log('Failed to fetch transcript: ' . $e->getMessage());
            }
        }

        require __DIR__ . '/../Views/job.php';
    }
}
