<?php
/**
 * php-app/src/Repositories/CaseRepository.php
 * ----------------------------------------------
 * Database access for the cases table.
 */

declare(strict_types=1);

namespace App\Repositories;

class CaseRepository
{
    private \PDO $db;

    public function __construct()
    {
        $this->db = Database::connection();
    }

    /** @return array<int,array<string,mixed>> */
    public function findByUser(int $userId): array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM cases WHERE user_id = :uid ORDER BY created_at DESC'
        );
        $stmt->execute([':uid' => $userId]);
        return $stmt->fetchAll();
    }

    /** @return array<string,mixed>|null */
    public function findById(int $id, int $userId): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM cases WHERE id = :id AND user_id = :uid'
        );
        $stmt->execute([':id' => $id, ':uid' => $userId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /** @return array<string,mixed> */
    public function create(int $userId, string $name, string $description): array
    {
        $stmt = $this->db->prepare(
            'INSERT INTO cases (user_id, name, description) VALUES (:uid, :name, :desc) RETURNING *'
        );
        $stmt->execute([':uid' => $userId, ':name' => $name, ':desc' => $description]);
        return $stmt->fetch();
    }

    public function updateStatus(int $id, string $status): void
    {
        $this->db->prepare(
            "UPDATE cases SET status = :s, updated_at = NOW() WHERE id = :id"
        )->execute([':s' => $status, ':id' => $id]);
    }
}
