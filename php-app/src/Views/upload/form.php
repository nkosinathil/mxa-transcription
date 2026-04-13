<?php
/** Upload form – $case is set by UploadController */
$pageTitle = 'Upload Audio – ' . ($case['name'] ?? '');
ob_start();
?>

<div class="form-container">
    <div class="form-card">
        <h2>Upload Audio File</h2>
        <p class="form-help">
            Upload an audio file to case: <strong><?= htmlspecialchars($case['name']) ?></strong>.<br>
            Supported formats: WAV, MP3, M4A, AAC, FLAC, OGG, OPUS, WMA. Max 500 MB.
        </p>

        <div id="uploadArea" class="upload-drop-zone">
            <div class="upload-icon">🎵</div>
            <p class="upload-hint">Drag and drop your audio file here, or click to browse</p>
            <input type="file" id="audioFile" name="audio_file" accept=".wav,.mp3,.m4a,.aac,.flac,.ogg,.opus,.wma"
                   class="upload-input">
            <button type="button" class="btn btn-outline" onclick="document.getElementById('audioFile').click()">
                Choose File
            </button>
        </div>

        <div id="fileInfo" class="file-info" style="display:none;">
            <span id="fileName"></span>
            <span id="fileSize" class="text-muted"></span>
        </div>

        <div id="uploadProgress" style="display:none;">
            <div class="progress-bar-wrap" style="height:8px; margin:1rem 0;">
                <div class="progress-bar" id="uploadProgressBar" style="width:0%"></div>
            </div>
            <p id="uploadStatus" class="text-muted">Uploading…</p>
        </div>

        <div id="uploadSuccess" class="alert alert-ok" style="display:none;">
            File uploaded successfully! <a href="#" id="startJobLink">Start Processing →</a>
        </div>

        <div id="uploadError" class="alert alert-error" style="display:none;"></div>

        <div class="form-actions">
            <a href="/cases/<?= (int)$case['id'] ?>" class="btn btn-outline">Cancel</a>
            <button type="button" id="uploadBtn" class="btn btn-primary" disabled>Upload File</button>
        </div>
    </div>
</div>

<script>
const caseId = <?= (int)$case['id'] ?>;
const csrfToken = window.MXA_CSRF_TOKEN || '';
let uploadedId = null;

const fileInput = document.getElementById('audioFile');
const uploadBtn = document.getElementById('uploadBtn');
const fileInfo  = document.getElementById('fileInfo');
const uploadArea = document.getElementById('uploadArea');

fileInput.addEventListener('change', () => {
    const f = fileInput.files[0];
    if (!f) return;
    document.getElementById('fileName').textContent = f.name;
    document.getElementById('fileSize').textContent = '(' + (f.size / 1024 / 1024).toFixed(2) + ' MB)';
    fileInfo.style.display = 'block';
    uploadBtn.disabled = false;
});

// Drag & drop
uploadArea.addEventListener('dragover', e => { e.preventDefault(); uploadArea.classList.add('drag-over'); });
uploadArea.addEventListener('dragleave', () => uploadArea.classList.remove('drag-over'));
uploadArea.addEventListener('drop', e => {
    e.preventDefault();
    uploadArea.classList.remove('drag-over');
    fileInput.files = e.dataTransfer.files;
    fileInput.dispatchEvent(new Event('change'));
});

uploadBtn.addEventListener('click', async () => {
    const f = fileInput.files[0];
    if (!f) return;

    uploadBtn.disabled = true;
    document.getElementById('uploadProgress').style.display = 'block';
    document.getElementById('uploadError').style.display = 'none';

    const fd = new FormData();
    fd.append('csrf_token', csrfToken);
    fd.append('audio_file', f);
    fd.append('case_id', caseId);

    try {
        const res = await fetch('/upload', { method: 'POST', body: fd });
        const data = await res.json();

        if (!data.success) throw new Error(data.error || 'Upload failed');

        uploadedId = data.upload_id;
        document.getElementById('uploadProgressBar').style.width = '100%';
        document.getElementById('uploadStatus').textContent = 'Upload complete!';
        document.getElementById('uploadSuccess').style.display = 'block';

        document.getElementById('startJobLink').href = '#';
        document.getElementById('startJobLink').addEventListener('click', e => {
            e.preventDefault();
            startJob(uploadedId);
        });
    } catch (err) {
        const errEl = document.getElementById('uploadError');
        errEl.textContent = err.message;
        errEl.style.display = 'block';
        uploadBtn.disabled = false;
    }
});

async function startJob(uploadId) {
    const fd = new FormData();
    fd.append('csrf_token', csrfToken);
    fd.append('model_size', 'base');
    fd.append('diarization', '1');
    const res = await fetch(`/jobs/${uploadId}/start`, { method: 'POST', body: fd });
    const data = await res.json();
    if (data.success) {
        window.location.href = `/results/${data.job_id}`;
    } else {
        alert('Failed to start job: ' + (data.error || 'Unknown error'));
    }
}
</script>

<?php
$content = ob_get_clean();
require __DIR__ . '/../layout.php';
