<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Upload - MXA Transcription</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 1rem 2rem; }
        .header h1 { display: inline-block; }
        .header nav { float: right; margin-top: 0.5rem; }
        .header nav a { color: white; text-decoration: none; margin-left: 1.5rem; }
        .container { max-width: 800px; margin: 2rem auto; padding: 0 2rem; }
        .card { background: white; border-radius: 8px; padding: 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .form-group { margin-bottom: 1.5rem; }
        .form-group label { display: block; margin-bottom: 0.5rem; font-weight: bold; }
        .form-group input[type="file"] { width: 100%; padding: 0.75rem; border: 2px dashed #ddd; border-radius: 4px; }
        .btn { background: #3498db; color: white; padding: 0.75rem 1.5rem; border: none; border-radius: 4px; cursor: pointer; font-size: 1rem; }
        .btn:hover { background: #2980b9; }
        .error { background: #e74c3c; color: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem; }
        .info { background: #3498db; color: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem; }
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
            <h2>Upload Audio File</h2>
            
            <?php if (isset($_SESSION['error'])): ?>
                <div class="error">
                    <?php echo htmlspecialchars($_SESSION['error']); ?>
                    <?php unset($_SESSION['error']); ?>
                </div>
            <?php endif; ?>
            
            <div class="info">
                <strong>Supported formats:</strong> WAV, MP3, M4A, AAC, FLAC, OGG, Opus, WMA<br>
                <strong>Maximum file size:</strong> <?php echo ($config['upload']['max_size'] / (1024*1024)); ?>MB<br>
                <strong>Supported languages:</strong> English, Afrikaans
            </div>
            
            <form action="/upload" method="POST" enctype="multipart/form-data">
                <?php echo CsrfService::field(); ?>
                
                <div class="form-group">
                    <label for="audio_file">Select Audio File:</label>
                    <input type="file" id="audio_file" name="audio_file" accept=".wav,.mp3,.m4a,.aac,.flac,.ogg,.opus,.wma" required>
                </div>
                
                <button type="submit" class="btn">Upload and Transcribe</button>
            </form>
        </div>
    </div>
</body>
</html>
