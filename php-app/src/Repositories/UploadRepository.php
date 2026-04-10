<?php
/**
 * php-app/src/Repositories/UploadRepository.php
 * ------------------------------------------------
 * Database access for the uploads table.
 */

declare(strict_types=1);

namespace App\Repositories;

class UploadRepository
{
    private \PDO $db;

    public function __construct()
    {
        $this->db = Database::connection();
    }

    /** @return array<string,mixed> */
    public function create(
        int    $caseId,
        int    $userId,
        string $filename,
        string $minioBucket,
        string $minioPath,
        int    $sizeBytes,
        string $sha256,
        string $mimeType
    ): array {
        $sql = <<<SQL
            INSERT INTO uploads
                (case_id, user_id, filename, minio_bucket, minio_path,
                 size_bytes, sha256, mime_type, upload_status)
            VALUES
                (:case_id, :user_id, :filename, :bucket, :path,
                 :size, :sha256, :mime, 'stored')
            RETURNING *
        SQL;

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':case_id'  => $caseId,
            ':user_id'  => $userId,
            ':filename' => $filename,
            ':bucket'   => $minioBucket,
            ':path'     => $minioPath,
            ':size'     => $sizeBytes,
            ':sha256'   => $sha256,
            ':mime'     => $mimeType,
        ]);
        return $stmt->fetch();
    }

    /** @return array<int,array<string,mixed>> */
    public function findByCase(int $caseId): array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM uploads WHERE case_id = :cid ORDER BY uploaded_at DESC'
        );
        $stmt->execute([':cid' => $caseId]);
        return $stmt->fetchAll();
    }

    /** @return array<string,mixed>|null */
    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM uploads WHERE id = :id');
        $stmt->execute([':id' => $id]);
        $row = $stmt->fetch();
        return $row ?: null;
    }
}
