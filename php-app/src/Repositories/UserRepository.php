<?php
/**
 * php-app/src/Repositories/UserRepository.php
 * ----------------------------------------------
 * Database access for the users table.
 *
 * Plain-language:
 *   When a user logs in through Keycloak, we receive their profile (email,
 *   name, roles).  This class either creates a new row in the users table
 *   or updates the existing one, and returns the user array.
 */

declare(strict_types=1);

namespace App\Repositories;

class UserRepository
{
    private \PDO $db;

    public function __construct()
    {
        $this->db = Database::connection();
    }

    /**
     * Upsert a user from their Keycloak profile.
     * Creates the row on first login, updates name/role on subsequent logins.
     *
     * @param  array<string,mixed> $keycloakProfile  Decoded from the Keycloak token
     * @return array<string,mixed>
     */
    public function upsertFromKeycloak(array $keycloakProfile): array
    {
        $keycloakId = $keycloakProfile['sub'];
        $email      = strtolower(trim($keycloakProfile['email'] ?? ''));
        $name       = trim($keycloakProfile['name'] ?? ($keycloakProfile['preferred_username'] ?? 'Unknown'));
        $role       = $this->mapRole($keycloakProfile['roles'] ?? []);

        $sql = <<<SQL
            INSERT INTO users (keycloak_id, email, name, role, last_login)
            VALUES (:keycloak_id, :email, :name, :role, NOW())
            ON CONFLICT (keycloak_id) DO UPDATE SET
                email      = EXCLUDED.email,
                name       = EXCLUDED.name,
                role       = EXCLUDED.role,
                last_login = NOW()
            RETURNING *
        SQL;

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':keycloak_id' => $keycloakId,
            ':email'       => $email,
            ':name'        => $name,
            ':role'        => $role,
        ]);

        return $stmt->fetch();
    }

    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM users WHERE id = :id');
        $stmt->execute([':id' => $id]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public function findByKeycloakId(string $keycloakId): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM users WHERE keycloak_id = :kid');
        $stmt->execute([':kid' => $keycloakId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /**
     * Maps Keycloak roles to one of our three application roles.
     *
     * Keycloak may return many roles; we pick the most permissive one.
     * Adjust role names to match what your Keycloak realm actually sends.
     *
     * @param  string[] $roles
     */
    private function mapRole(array $roles): string
    {
        if (in_array('admin', $roles, true) || in_array('transcription-admin', $roles, true)) {
            return 'admin';
        }
        if (in_array('analyst', $roles, true) || in_array('transcription-analyst', $roles, true)) {
            return 'analyst';
        }
        return 'viewer';
    }
}
