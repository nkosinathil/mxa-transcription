<?php
/** Dashboard view – variables injected by DashboardController */
$pageTitle = 'Dashboard';
ob_start();
?>

<div class="stats-grid">
    <div class="stat-card">
        <div class="stat-value"><?= (int) $stats['total_cases'] ?></div>
        <div class="stat-label">Total Cases</div>
    </div>
    <div class="stat-card stat-queued">
        <div class="stat-value"><?= (int) $stats['queued'] ?></div>
        <div class="stat-label">Queued</div>
    </div>
    <div class="stat-card stat-processing">
        <div class="stat-value"><?= (int) $stats['processing'] ?></div>
        <div class="stat-label">Processing</div>
    </div>
    <div class="stat-card stat-completed">
        <div class="stat-value"><?= (int) $stats['completed'] ?></div>
        <div class="stat-label">Completed</div>
    </div>
    <div class="stat-card stat-failed">
        <div class="stat-value"><?= (int) $stats['failed'] ?></div>
        <div class="stat-label">Failed</div>
    </div>
</div>

<div class="section">
    <div class="section-header">
        <h2>Recent Jobs</h2>
        <a href="/cases" class="btn btn-outline">View All Cases</a>
    </div>

    <?php if (empty($recentJobs)): ?>
        <div class="empty-state">
            <p>No jobs yet. <a href="/cases/create">Create your first case</a> to get started.</p>
        </div>
    <?php else: ?>
        <div class="table-wrap">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>File</th>
                        <th>Case</th>
                        <th>Status</th>
                        <th>Progress</th>
                        <th>Created</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($recentJobs as $job): ?>
                    <tr>
                        <td><?= htmlspecialchars($job['upload_filename'] ?? '—') ?></td>
                        <td><?= htmlspecialchars($job['case_name'] ?? '—') ?></td>
                        <td>
                            <span class="badge badge-<?= htmlspecialchars($job['status']) ?>">
                                <?= htmlspecialchars(ucfirst($job['status'])) ?>
                            </span>
                        </td>
                        <td>
                            <div class="progress-bar-wrap">
                                <div class="progress-bar" style="width:<?= (int)$job['progress'] ?>%"></div>
                            </div>
                            <span class="progress-text"><?= (int)$job['progress'] ?>%</span>
                        </td>
                        <td><?= htmlspecialchars(date('d M Y H:i', strtotime($job['created_at']))) ?></td>
                        <td>
                            <?php if ($job['status'] === 'completed'): ?>
                                <a href="/results/<?= (int)$job['id'] ?>" class="btn btn-sm btn-primary">View Result</a>
                            <?php elseif (in_array($job['status'], ['queued','processing'])): ?>
                                <a href="/results/<?= (int)$job['id'] ?>" class="btn btn-sm btn-outline">Monitor</a>
                            <?php endif; ?>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</div>

<?php
$content = ob_get_clean();
require __DIR__ . '/layout.php';
