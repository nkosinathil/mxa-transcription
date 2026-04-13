<?php
/** Results view – $job, $result, $events set by ResultController */
$jobStatus = $job['status'] ?? 'queued';
$pageTitle = 'Result – Job #' . ($job['id'] ?? '');
ob_start();
?>

<!-- Job status header -->
<div class="result-header">
    <div class="result-meta">
        <span class="badge badge-<?= htmlspecialchars($jobStatus) ?>" id="statusBadge">
            <?= htmlspecialchars(ucfirst($jobStatus)) ?>
        </span>
        <span class="text-muted" style="margin-left:1rem;">
            Job #<?= (int)$job['id'] ?>
        </span>
    </div>

    <?php if ($jobStatus === 'completed' && $result): ?>
        <a href="/results/<?= (int)$job['id'] ?>/download" class="btn btn-primary">
            ⬇ Download Transcript
        </a>
    <?php endif; ?>
</div>

<!-- Progress bar (shown while running) -->
<?php if (in_array($jobStatus, ['queued','processing'])): ?>
<div class="section" id="progressSection">
    <div class="progress-bar-wrap" style="height:12px; margin-bottom:.5rem;">
        <div class="progress-bar" id="progressBar" style="width:<?= (int)$job['progress'] ?>%"></div>
    </div>
    <p id="progressPct" class="text-muted"><?= (int)$job['progress'] ?>% complete…</p>

    <div class="log-box" id="eventLog">
        <?php foreach ($events as $event): ?>
            <div class="log-line log-<?= htmlspecialchars($event['event_type']) ?>">
                <span class="log-time"><?= htmlspecialchars(date('H:i:s', strtotime($event['created_at']))) ?></span>
                <?= htmlspecialchars($event['message']) ?>
            </div>
        <?php endforeach; ?>
    </div>
</div>
<?php endif; ?>

<!-- Result detail (shown when complete) -->
<?php if ($jobStatus === 'completed' && $result): ?>
<div class="section result-meta-grid">
    <?php $metaItems = [
        'Language'         => strtoupper($result['language'] ?? '—'),
        'Confidence'       => isset($result['language_probability']) ? number_format((float)$result['language_probability'] * 100, 1).'%' : '—',
        'Duration'         => isset($result['duration_seconds']) ? gmdate('H:i:s', (int)$result['duration_seconds']) : '—',
        'Speakers'         => $result['speaker_count'] ?? '—',
        'Segments'         => $result['segment_count'] ?? '—',
        'Diarization'      => ($result['diarization_available'] ?? false) ? 'Enabled' : 'Disabled',
    ]; ?>
    <?php foreach ($metaItems as $label => $value): ?>
        <div class="meta-card">
            <div class="meta-label"><?= htmlspecialchars($label) ?></div>
            <div class="meta-value"><?= htmlspecialchars((string)$value) ?></div>
        </div>
    <?php endforeach; ?>
</div>

<!-- Transcript -->
<?php if (!empty($result['segments']) && is_array($result['segments'])): ?>
<div class="section">
    <h3>Transcript</h3>
    <div class="transcript-box">
        <?php foreach ($result['segments'] as $seg): ?>
            <div class="transcript-segment">
                <div class="segment-meta">
                    <span class="speaker-label"><?= htmlspecialchars($seg['speaker'] ?? 'Speaker 1') ?></span>
                    <span class="segment-time text-muted">
                        <?= gmdate('H:i:s', (int)($seg['start'] ?? 0)) ?> –
                        <?= gmdate('H:i:s', (int)($seg['end']   ?? 0)) ?>
                    </span>
                </div>
                <p class="segment-text"><?= htmlspecialchars($seg['text'] ?? '') ?></p>
            </div>
        <?php endforeach; ?>
    </div>
</div>
<?php endif; ?>

<?php elseif ($jobStatus === 'failed'): ?>
<div class="alert alert-error" style="margin-top:1rem;">
    <strong>Processing failed.</strong>
    <?= htmlspecialchars($job['error_message'] ?? 'An unknown error occurred.') ?>
</div>
<?php endif; ?>

<?php if (in_array($jobStatus, ['queued','processing'])): ?>
<script>
const jobId = <?= (int)$job['id'] ?>;
let lastEventCount = <?= count($events) ?>;
const csrfToken = window.MXA_CSRF_TOKEN || '';

function poll() {
    setTimeout(async () => {
        try {
            const res  = await fetch(`/jobs/${jobId}/status`, {
                headers: { 'X-CSRF-Token': csrfToken }
            });
            const data = await res.json();

            document.getElementById('statusBadge').className = `badge badge-${data.status}`;
            document.getElementById('statusBadge').textContent = data.status.charAt(0).toUpperCase()+data.status.slice(1);
            document.getElementById('progressBar').style.width = (data.progress || 0) + '%';
            document.getElementById('progressPct').textContent = (data.progress || 0) + '% complete…';

            // Append new events
            const log    = document.getElementById('eventLog');
            const events = data.events || [];
            for (let i = lastEventCount; i < events.length; i++) {
                const e  = events[i];
                const d  = document.createElement('div');
                d.className = `log-line log-${e.event_type}`;
                d.innerHTML = `<span class="log-time">${new Date(e.created_at).toLocaleTimeString()}</span> ${e.message}`;
                log.appendChild(d);
                log.scrollTop = log.scrollHeight;
            }
            lastEventCount = events.length;

            if (['queued','processing'].includes(data.status)) {
                poll();
            } else {
                location.reload();
            }
        } catch(err) {
            setTimeout(poll, 5000);
        }
    }, 3000);
}
poll();
</script>
<?php endif; ?>

<?php
$content = ob_get_clean();
require __DIR__ . '/../layout.php';
