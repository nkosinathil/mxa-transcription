<?php
/**
 * php-app/src/Repositories/JobRepository.php
 * ---------------------------------------------
 * Database access for processing_jobs, job_events, and results tables.
 */

declare(strict_types=1);

namespace App\Repositories;

class JobRepository
{
    private \PDO $db;

    public function __construct()
    {
        $this->db = Database::connection();
    }

    /** @return array<string,mixed> */
    public function create(
        int    $uploadId,
        int    $caseId,
        int    $userId,
        string $modelSize  = 'base',
        string $device     = 'auto',
        ?string $computeType = null,
        bool   $diarization  = true
    ): array {
        $sql = <<<SQL
            INSERT INTO processing_jobs
                (upload_id, case_id, user_id, model_size, device, compute_type, diarization)
            VALUES
                (:upload_id, :case_id, :user_id, :model, :device, :compute, :diarize)
            RETURNING *
        SQL;

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':upload_id' => $uploadId,
            ':case_id'   => $caseId,
            ':user_id'   => $userId,
            ':model'     => $modelSize,
            ':device'    => $device,
            ':compute'   => $computeType,
            ':diarize'   => $diarization ? 'true' : 'false',
        ]);
        return $stmt->fetch();
    }

    /** @return array<string,mixed>|null */
    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM processing_jobs WHERE id = :id');
        $stmt->execute([':id' => $id]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /** @return array<int,array<string,mixed>> */
    public function findByCase(int $caseId): array
    {
        $sql = <<<SQL
            SELECT j.*, u.filename AS upload_filename
              FROM processing_jobs j
              JOIN uploads u ON u.id = j.upload_id
             WHERE j.case_id = :cid
             ORDER BY j.created_at DESC
        SQL;
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':cid' => $caseId]);
        return $stmt->fetchAll();
    }

    /** @return array<int,array<string,mixed>> */
    public function findByUser(int $userId, int $limit = 20): array
    {
        $sql = <<<SQL
            SELECT j.*, u.filename AS upload_filename, c.name AS case_name
              FROM processing_jobs j
              JOIN uploads u ON u.id = j.upload_id
              JOIN cases   c ON c.id = j.case_id
             WHERE j.user_id = :uid
             ORDER BY j.created_at DESC
             LIMIT :lim
        SQL;
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':uid', $userId, \PDO::PARAM_INT);
        $stmt->bindValue(':lim', $limit,  \PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function updateCeleryTaskId(int $jobId, string $celeryTaskId): void
    {
        $this->db->prepare(
            'UPDATE processing_jobs SET celery_task_id = :tid WHERE id = :id'
        )->execute([':tid' => $celeryTaskId, ':id' => $jobId]);
    }

    public function updateStatus(int $jobId, string $status, int $progress = 0): void
    {
        $this->db->prepare(
            'UPDATE processing_jobs SET status = :s, progress = :p WHERE id = :id'
        )->execute([':s' => $status, ':p' => $progress, ':id' => $jobId]);
    }

    /** @return array<string,mixed>|null */
    public function findResult(int $jobId): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM results WHERE job_id = :jid');
        $stmt->execute([':jid' => $jobId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /** @return array<int,array<string,mixed>> */
    public function findEvents(int $jobId): array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM job_events WHERE job_id = :jid ORDER BY created_at ASC'
        );
        $stmt->execute([':jid' => $jobId]);
        return $stmt->fetchAll();
    }
}
