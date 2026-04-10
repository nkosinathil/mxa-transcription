<?php
/** Create case form */
$pageTitle = 'New Case';
ob_start();
?>

<div class="form-container">
    <form method="POST" action="/cases" class="form-card">
        <h2>Create New Case</h2>
        <p class="form-help">A case is a workspace for grouping related audio files and their transcriptions.</p>

        <div class="form-group">
            <label for="name">Case Name <span class="required">*</span></label>
            <input type="text" id="name" name="name" required
                   placeholder="e.g. Interview Session 2026-04-10"
                   value="<?= htmlspecialchars($_POST['name'] ?? '') ?>">
        </div>

        <div class="form-group">
            <label for="description">Description <span class="optional">(optional)</span></label>
            <textarea id="description" name="description" rows="3"
                      placeholder="Brief description of this case…"><?= htmlspecialchars($_POST['description'] ?? '') ?></textarea>
        </div>

        <div class="form-actions">
            <a href="/cases" class="btn btn-outline">Cancel</a>
            <button type="submit" class="btn btn-primary">Create Case</button>
        </div>
    </form>
</div>

<?php
$content = ob_get_clean();
require __DIR__ . '/../layout.php';
