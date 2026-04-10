<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Jobs - MXA Transcription</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 1rem 2rem; }
        .header h1 { display: inline-block; }
        .header nav { float: right; margin-top: 0.5rem; }
        .header nav a { color: white; text-decoration: none; margin-left: 1.5rem; }
        .container { max-width: 1200px; margin: 2rem auto; padding: 0 2rem; }
        .card { background: white; border-radius: 8px; padding: 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .btn { display: inline-block; background: #3498db; color: white; padding: 0.5rem 1rem; text-decoration: none; border-radius: 4px; }
        .btn:hover { background: #2980b9; }
        table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
        thead tr { border-bottom: 2px solid #ddd; text-align: left; }
        tbody tr { border-bottom: 1px solid #eee; }
        th, td { padding: 0.75rem 0.5rem; }
        .badge { padding: 0.25rem 0.6rem; border-radius: 3px; font-size: 0.8rem; color: white; }
        .badge-completed   { background: #27ae60; }
        .badge-processing  { background: #f39c12; }
        .badge-failed      { background: #e74c3c; }
        .badge-queued      { background: #3498db; }
        .badge-pending     { background: #95a5a6; }
        .badge-cancelled   { background: #7f8c8d; }
        .empty { text-align: center; padding: 3rem; color: #7f8c8d; }
        .page-actions { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
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
            <div class="page-actions">
                <h2>My Transcription Jobs</h2>
                <a href="/upload" class="btn">+ New Upload</a>
            </div>

            <?php if (empty($jobs)): ?>
                <div class="empty">
                    <p>No jobs yet.</p>
                    <br>
                    <a href="/upload" class="btn">Upload your first file</a>
                </div>
            <?php else: ?>
                <table>
                    <thead>
                        <tr>
                            <th>Filename</th>
                            <th>Status</th>
                            <th>Language</th>
                            <th>Duration</th>
                            <th>Speakers</th>
                            <th>Size</th>
                            <th>Created</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($jobs as $job): ?>
                            <tr>
                                <td><?php echo htmlspecialchars($job['filename']); ?></td>
                                <td>
                                    <span class="badge badge-<?php echo htmlspecialchars($job['status']); ?>">
                                        <?php echo strtoupper(htmlspecialchars($job['status'])); ?>
                                    </span>
                                </td>
                                <td><?php echo htmlspecialchars($job['language'] ?? '—'); ?></td>
                                <td>
                                    <?php if ($job['duration']): ?>
                                        <?php echo number_format((float)$job['duration'], 1); ?>s
                                    <?php else: ?>
                                        —
                                    <?php endif; ?>
                                </td>
                                <td><?php echo $job['speaker_count'] !== null ? (int)$job['speaker_count'] : '—'; ?></td>
                                <td><?php echo number_format($job['file_size'] / 1024 / 1024, 1); ?> MB</td>
                                <td><?php echo date('Y-m-d H:i', strtotime($job['created_at'])); ?></td>
                                <td>
                                    <a href="/jobs/<?php echo $job['id']; ?>" class="btn">View</a>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
    </div>
</body>
</html>
