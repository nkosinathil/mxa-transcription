<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - MXA Transcription</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 1rem 2rem; }
        .header h1 { display: inline-block; }
        .header nav { float: right; margin-top: 0.5rem; }
        .header nav a { color: white; text-decoration: none; margin-left: 1.5rem; }
        .container { max-width: 1200px; margin: 2rem auto; padding: 0 2rem; }
        .card { background: white; border-radius: 8px; padding: 2rem; margin-bottom: 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .btn { display: inline-block; background: #3498db; color: white; padding: 0.75rem 1.5rem; text-decoration: none; border-radius: 4px; border: none; cursor: pointer; }
        .btn:hover { background: #2980b9; }
        .btn-success { background: #27ae60; }
        .btn-success:hover { background: #229954; }
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
            <h2>Welcome, <?php echo htmlspecialchars($auth->getCurrentUser()['username']); ?>!</h2>
            <p>Upload audio files for transcription with speaker diarization.</p>
            <br>
            <a href="/upload" class="btn btn-success">Upload New File</a>
            <a href="/jobs" class="btn">View My Jobs</a>
        </div>
        
        <div class="card">
            <h3>Recent Jobs</h3>
            <?php
            $recentJobs = $db->fetchAll(
                'SELECT * FROM jobs WHERE user_id = ? ORDER BY created_at DESC LIMIT 5',
                [$_SESSION['user_id']]
            );
            
            if (empty($recentJobs)): ?>
                <p>No jobs yet. <a href="/upload">Upload your first file</a></p>
            <?php else: ?>
                <table style="width: 100%; border-collapse: collapse; margin-top: 1rem;">
                    <thead>
                        <tr style="border-bottom: 2px solid #ddd; text-align: left;">
                            <th style="padding: 0.5rem;">Filename</th>
                            <th style="padding: 0.5rem;">Status</th>
                            <th style="padding: 0.5rem;">Language</th>
                            <th style="padding: 0.5rem;">Created</th>
                            <th style="padding: 0.5rem;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($recentJobs as $job): ?>
                            <tr style="border-bottom: 1px solid #eee;">
                                <td style="padding: 0.5rem;"><?php echo htmlspecialchars($job['filename']); ?></td>
                                <td style="padding: 0.5rem;">
                                    <span style="background: <?php 
                                        echo $job['status'] === 'completed' ? '#27ae60' : 
                                             ($job['status'] === 'failed' ? '#e74c3c' : '#f39c12');
                                    ?>; color: white; padding: 0.25rem 0.5rem; border-radius: 3px; font-size: 0.85rem;">
                                        <?php echo htmlspecialchars($job['status']); ?>
                                    </span>
                                </td>
                                <td style="padding: 0.5rem;"><?php echo htmlspecialchars($job['language'] ?? 'N/A'); ?></td>
                                <td style="padding: 0.5rem;"><?php echo date('Y-m-d H:i', strtotime($job['created_at'])); ?></td>
                                <td style="padding: 0.5rem;">
                                    <a href="/jobs/<?php echo $job['id']; ?>" style="color: #3498db;">View</a>
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
