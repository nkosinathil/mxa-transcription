<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Job Details - MXA Transcription</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 1rem 2rem; }
        .header h1 { display: inline-block; }
        .header nav { float: right; margin-top: 0.5rem; }
        .header nav a { color: white; text-decoration: none; margin-left: 1.5rem; }
        .container { max-width: 1000px; margin: 2rem auto; padding: 0 2rem; }
        .card { background: white; border-radius: 8px; padding: 2rem; margin-bottom: 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .info-grid { display: grid; grid-template-columns: 200px 1fr; gap: 0.75rem; }
        .info-label { font-weight: bold; }
        .status-badge { padding: 0.5rem 1rem; border-radius: 4px; display: inline-block; color: white; }
        .status-completed { background: #27ae60; }
        .status-processing { background: #f39c12; }
        .status-failed { background: #e74c3c; }
        .status-pending { background: #95a5a6; }
        .transcript { background: #f8f9fa; padding: 1.5rem; border-radius: 4px; white-space: pre-wrap; font-family: monospace; max-height: 500px; overflow-y: auto; }
        .speaker { font-weight: bold; color: #2c3e50; }
    </style>
</head>
<body>
    <div class="header">
        <h1>MXA Transcription</h1>
        <nav>
            <a href="/">Dashboard</a>
            <a href="/upload">Upload</a>
            <a href="/jobs">My Jobs</a>
            <a href="/auth/logout">Logout</a>
        </nav>
    </div>
    
    <div class="container">
        <div class="card">
            <h2>Job Details</h2>
            
            <div class="info-grid" style="margin-top: 1.5rem;">
                <div class="info-label">Filename:</div>
                <div><?php echo htmlspecialchars($job['filename']); ?></div>
                
                <div class="info-label">Status:</div>
                <div>
                    <span class="status-badge status-<?php echo $job['status']; ?>">
                        <?php echo strtoupper($job['status']); ?>
                    </span>
                </div>
                
                <div class="info-label">File Size:</div>
                <div><?php echo number_format($job['file_size'] / 1024 / 1024, 2); ?> MB</div>
                
                <?php if ($job['language']): ?>
                    <div class="info-label">Language:</div>
                    <div><?php echo htmlspecialchars($job['language']); ?></div>
                <?php endif; ?>
                
                <?php if ($job['duration']): ?>
                    <div class="info-label">Duration:</div>
                    <div><?php echo number_format($job['duration'], 2); ?> seconds</div>
                <?php endif; ?>
                
                <?php if ($job['speaker_count']): ?>
                    <div class="info-label">Speakers:</div>
                    <div><?php echo $job['speaker_count']; ?></div>
                <?php endif; ?>
                
                <div class="info-label">Created:</div>
                <div><?php echo date('Y-m-d H:i:s', strtotime($job['created_at'])); ?></div>
                
                <?php if ($job['completed_at']): ?>
                    <div class="info-label">Completed:</div>
                    <div><?php echo date('Y-m-d H:i:s', strtotime($job['completed_at'])); ?></div>
                <?php endif; ?>
            </div>
            
            <?php if ($job['status'] === 'processing'): ?>
                <p style="margin-top: 1.5rem; color: #f39c12;">
                    <strong>Processing...</strong> This page will automatically refresh every 10 seconds.
                </p>
                <script>setTimeout(function(){ location.reload(); }, 10000);</script>
            <?php endif; ?>
            
            <?php if ($job['error_message']): ?>
                <div style="background: #e74c3c; color: white; padding: 1rem; border-radius: 4px; margin-top: 1.5rem;">
                    <strong>Error:</strong> <?php echo htmlspecialchars($job['error_message']); ?>
                </div>
            <?php endif; ?>
        </div>
        
        <?php if ($transcript && isset($transcript['segments'])): ?>
            <div class="card">
                <h3>Transcript</h3>
                <div class="transcript">
<?php foreach ($transcript['segments'] as $segment): ?>
<span class="speaker">[<?php echo htmlspecialchars($segment['speaker']); ?>]</span> <?php echo htmlspecialchars($segment['text']); ?>

<?php endforeach; ?>
                </div>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>
