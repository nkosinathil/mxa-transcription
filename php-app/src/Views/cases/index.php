<?php
/** Cases list view */
$pageTitle = 'Cases';
ob_start();
?>

<div class="section-header">
    <h2>All Cases</h2>
    <a href="/cases/create" class="btn btn-primary">+ New Case</a>
</div>

<?php if (empty($cases)): ?>
    <div class="empty-state">
        <p>You have no cases yet. Create one to start uploading and transcribing audio files.</p>
        <a href="/cases/create" class="btn btn-primary" style="margin-top:1rem;">Create Case</a>
    </div>
<?php else: ?>
    <div class="card-grid">
        <?php foreach ($cases as $case): ?>
        <div class="case-card">
            <div class="case-card-header">
                <span class="case-status-dot status-<?= htmlspecialchars($case['status']) ?>"></span>
                <span class="case-status-label"><?= htmlspecialchars(ucfirst($case['status'])) ?></span>
            </div>
            <h3 class="case-card-title"><?= htmlspecialchars($case['name']) ?></h3>
            <?php if ($case['description']): ?>
                <p class="case-card-desc"><?= htmlspecialchars($case['description']) ?></p>
            <?php endif; ?>
            <div class="case-card-footer">
                <span class="case-date"><?= htmlspecialchars(date('d M Y', strtotime($case['created_at']))) ?></span>
                <a href="/cases/<?= (int)$case['id'] ?>" class="btn btn-sm btn-outline">Open</a>
            </div>
        </div>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<?php
$content = ob_get_clean();
require __DIR__ . '/layout.php';
