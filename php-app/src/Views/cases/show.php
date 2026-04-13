<?php
/** Case detail view – $case, $uploads, $jobs are set by CaseController */
$pageTitle = 'Case: ' . ($case['name'] ?? '');
ob_start();
?>

<div class="section-header">
    <div>
        <h2><?= htmlspecialchars($case['name']) ?></h2>
        <?php if ($case['description']): ?>
            <p class="text-muted"><?= htmlspecialchars($case['description']) ?></p>
        <?php endif; ?>
    </div>
    <a href="/upload/<?= (int)$case['id'] ?>" class="btn btn-primary">+ Upload Audio</a>
</div>

<!-- Uploads -->
<div class="section">
    <h3>Uploaded Files</h3>
    <?php if (empty($uploads)): ?>
        <div class="empty-state">
            <p>No files uploaded yet. <a href="/upload/<?= (int)$case['id'] ?>">Upload an audio file</a> to begin.</p>
        </div>
    <?php else: ?>
        <div class="table-wrap">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Filename</th>
                        <th>Size</th>
                        <th>Uploaded</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($uploads as $upload): ?>
                    <tr>
                        <td><?= htmlspecialchars($upload['filename']) ?></td>
                        <td><?= number_format($upload['size_bytes'] / 1024 / 1024, 2) ?> MB</td>
                        <td><?= htmlspecialchars(date('d M Y H:i', strtotime($upload['uploaded_at']))) ?></td>
                        <td>
                            <form method="POST" action="/jobs/<?= (int)$upload['id'] ?>/start"
                                  class="inline-form" data-upload-id="<?= (int)$upload['id'] ?>">
                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                <input type="hidden" name="model_size" value="base">
                                <input type="hidden" name="diarization" value="1">
                                <button type="submit" class="btn btn-sm btn-primary">Start Processing</button>
                            </form>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</div>

<!-- Jobs -->
<div class="section" style="margin-top:2rem;">
    <h3>Processing Jobs</h3>
    <?php if (empty($jobs)): ?>
        <p class="text-muted">No jobs started for this case yet.</p>
    <?php else: ?>
        <div class="table-wrap">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>File</th>
                        <th>Status</th>
                        <th>Progress</th>
                        <th>Started</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($jobs as $job): ?>
                    <tr data-job-id="<?= (int)$job['id'] ?>">
                        <td><?= htmlspecialchars($job['upload_filename'] ?? '—') ?></td>
                        <td>
                            <span class="badge badge-<?= htmlspecialchars($job['status']) ?>">
                                <?= htmlspecialchars(ucfirst($job['status'])) ?>
                            </span>
                        </td>
                        <td>
                            <div class="progress-bar-wrap">
                                <div class="progress-bar" style="width:<?= (int)$job['progress'] ?>%"></div>
                            </div>
                        </td>
                        <td><?= $job['started_at'] ? htmlspecialchars(date('d M H:i', strtotime($job['started_at']))) : '—' ?></td>
                        <td>
                            <?php if ($job['status'] === 'completed'): ?>
                                <a href="/results/<?= (int)$job['id'] ?>" class="btn btn-sm btn-primary">View</a>
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

<script>
// Auto-start polling for active jobs
document.querySelectorAll('[data-job-id]').forEach(row => {
    const status = row.querySelector('.badge')?.textContent?.trim().toLowerCase();
    if (['queued','processing'].includes(status)) {
        pollJobStatus(parseInt(row.dataset.jobId), row);
    }
});

function pollJobStatus(jobId, row) {
    setTimeout(async () => {
        try {
            const res = await fetch(`/jobs/${jobId}/status`, {
                headers: { 'X-CSRF-Token': window.MXA_CSRF_TOKEN || '' }
            });
            const data = await res.json();
            const badge = row.querySelector('.badge');
            if (badge) {
                badge.className = `badge badge-${data.status}`;
                badge.textContent = data.status.charAt(0).toUpperCase() + data.status.slice(1);
            }
            const bar = row.querySelector('.progress-bar');
            if (bar) bar.style.width = (data.progress || 0) + '%';

            if (['queued','processing'].includes(data.status)) {
                pollJobStatus(jobId, row);
            } else {
                location.reload();
            }
        } catch(e) {
            setTimeout(() => pollJobStatus(jobId, row), 5000);
        }
    }, 3000);
}
</script>

<?php
$content = ob_get_clean();
require __DIR__ . '/../layout.php';
