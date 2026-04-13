<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Login Error – MXA Transcription</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body class="login-page">
<div class="login-container">
    <div class="login-card">
        <h2 style="color:#ef4444; margin-bottom:1rem;">Login Error</h2>
        <p><?= htmlspecialchars($message ?? 'An error occurred during login.') ?></p>
        <a href="/auth/login" class="btn btn-primary" style="margin-top:1.5rem;">Try again</a>
    </div>
</div>
</body>
</html>
