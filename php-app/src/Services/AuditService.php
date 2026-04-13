<?php
/**
 * php-app/src/Services/AuditService.php
 * ----------------------------------------
 * Records audit log entries.
 *
 * Plain-language:
 *   Every important action (login, upload, start processing, download) is
 *   recorded in the audit_logs table.  This is important for security
 *   compliance – you can look back and see exactly who did what and when.
 *
 *   Call AuditService::log() anywhere in the application to record an event.
 */

declare(strict_types=1);

namespace App\Services;

use App\Repositories\Database;

class AuditService
{
    /**
     * Record an audit event.
     *
     * @param  string               $action        e.g. 'login', 'upload', 'process', 'download'
     * @param  int|null             $userId        The logged-in user's ID (null for pre-login events)
     * @param  string|null          $resourceType  e.g. 'upload', 'job', 'case'
     * @param  int|null             $resourceId    The ID of the affected row
     * @param  array<string,mixed>  $extra         Any extra context to log
     */
    public static function log(
        string  $action,
        ?int    $userId       = null,
        ?string $resourceType = null,
        ?int    $resourceId   = null,
        array   $extra        = []
    ): void {
        try {
            $db = Database::connection();
            $stmt = $db->prepare(
                <<<SQL
                INSERT INTO audit_logs
                    (user_id, action, resource_type, resource_id, ip_address, user_agent, extra)
                VALUES
                    (:user_id, :action, :rtype, :rid, :ip::inet, :ua, :extra)
                SQL
            );
            $stmt->execute([
                ':user_id' => $userId,
                ':action'  => $action,
                ':rtype'   => $resourceType,
                ':rid'     => $resourceId,
                ':ip'      => $_SERVER['REMOTE_ADDR'] ?? null,
                ':ua'      => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 512),
                ':extra'   => empty($extra) ? null : json_encode($extra, JSON_UNESCAPED_UNICODE),
            ]);
        } catch (\Throwable $e) {
            // Audit logging failure must not break the main flow; just log it.
            error_log('AuditService::log failed: ' . $e->getMessage());
        }
    }
}
