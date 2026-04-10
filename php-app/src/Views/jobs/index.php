<?php
/** Jobs queue view */
$pageTitle = 'Processing Queue';
ob_start();
?>

<div class="section-header">
    <h2>All Processing Jobs</h2>
</div>

<?php if (empty($jobs)): ?>
    <div class="empty-state">
        <p>No jobs yet. Upload audio files from within a case to start processing.</p>
        <a href="/cases" class="btn btn-outline" style="margin-top:1rem;">Go to Cases</a>
    </div>
<?php else: ?>
    <div class="table-wrap">
        <table class="data-table" id="jobsTable">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>File</th>
                    <th>Case</th>
                    <th>Status</th>
                    <th>Progress</th>
                    <th>Created</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($jobs as $job): ?>
                <tr data-job-id="<?= (int)$job['id'] ?>" data-status="<?= htmlspecialchars($job['status']) ?>">
                    <td>#<?= (int)$job['id'] ?></td>
                    <td><?= htmlspecialchars($job['upload_filename'] ?? '—') ?></td>
                    <td><?= htmlspecialchars($job['case_name'] ?? '—') ?></td>
                    <td>
                        <span class="badge badge-<?= htmlspecialchars($job['status']) ?>" id="badge-<?= (int)$job['id'] ?>">
                            <?= htmlspecialchars(ucfirst($job['status'])) ?>
                        </span>
                    </td>
                    <td>
                        <div class="progress-bar-wrap">
                            <div class="progress-bar" id="progress-<?= (int)$job['id'] ?>"
                                 style="width:<?= (int)$job['progress'] ?>%"></div>
                        </div>
                        <span id="pct-<?= (int)$job['id'] ?>"><?= (int)$job['progress'] ?>%</span>
                    </td>
                    <td><?= htmlspecialchars(date('d M Y H:i', strtotime($job['created_at']))) ?></td>
                    <td>
                        <a href="/results/<?= (int)$job['id'] ?>" class="btn btn-sm btn-outline">
                            <?= $job['status'] === 'completed' ? 'View Result' : 'Monitor' ?>
                        </a>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php endif; ?>

<script>
// Poll active jobs every 4 seconds
document.querySelectorAll('[data-job-id]').forEach(row => {
    const status = row.dataset.status;
    if (['queued','processing'].includes(status)) {
        pollJob(parseInt(row.dataset.jobId));
    }
});

function pollJob(jobId) {
    setTimeout(async () => {
        try {
            const res  = await fetch(`/jobs/${jobId}/status`);
            const data = await res.json();
            const badge    = document.getElementById(`badge-${jobId}`);
            const progress = document.getElementById(`progress-${jobId}`);
            const pct      = document.getElementById(`pct-${jobId}`);
            if (badge)    { badge.className = `badge badge-${data.status}`; badge.textContent = data.status.charAt(0).toUpperCase()+data.status.slice(1); }
            if (progress) progress.style.width = (data.progress || 0) + '%';
            if (pct)      pct.textContent = (data.progress || 0) + '%';

            if (['queued','processing'].includes(data.status)) {
                pollJob(jobId);
            }
        } catch(e) {
            setTimeout(() => pollJob(jobId), 5000);
        }
    }, 4000);
}
</script>

<?php
$content = ob_get_clean();
require __DIR__ . '/../layout.php';
