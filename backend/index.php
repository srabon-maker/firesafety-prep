<?php
require_once __DIR__ . '/admin_helpers.php';

start_secure_session();

$dashboard = 'fire_safety_job_prep_dashboard.php';

// Already logged in: go directly to dashboard
if (!empty($_SESSION['admin_logged_in'])) {
    header('Location: ' . $dashboard);
    exit;
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $password = (string)($_POST['password'] ?? '');
    $authFile = __DIR__ . '/admin_auth.php';

    if (!is_file($authFile)) {
        $error = 'Admin authentication file was not found.';
    } else {
        $hash = require $authFile;

        if (is_string($hash) && password_verify($password, $hash)) {

            session_regenerate_id(true);

            $_SESSION['admin_logged_in'] = true;
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));

            header('Location: ' . $dashboard);
            exit;

        } else {
            $error = 'ভুল পাসওয়ার্ড। আবার চেষ্টা করুন।';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="bn">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title>Admin Login - Fire Safety BD</title>

<style>
* {
    box-sizing: border-box;
}

body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #fff8f5;
    font-family: Arial, "Noto Sans Bengali", sans-serif;
    padding: 20px;
}

.login-box {
    width: 100%;
    max-width: 420px;
    background: #ffffff;
    padding: 35px 28px;
    border-radius: 20px;
    border: 1px solid #f1ddd6;
    box-shadow: 0 12px 35px rgba(81, 13, 24, 0.10);
}

.brand {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 13px;
    margin-bottom: 28px;
}

.brand img {
    width: 65px;
    height: 65px;
    object-fit: contain;
    border-radius: 14px;
}

.brand-name {
    color: #510d18;
    font-size: 25px;
    font-weight: 800;
    letter-spacing: 0.3px;
}

.subtitle {
    text-align: center;
    color: #8b7777;
    margin-bottom: 28px;
    font-size: 14px;
}

label {
    display: block;
    margin-bottom: 9px;
    font-weight: bold;
    color: #30191b;
}

input {
    width: 100%;
    height: 50px;
    padding: 0 14px;
    border: 1px solid #e8d5cf;
    border-radius: 11px;
    font-size: 16px;
    margin-bottom: 18px;
}

input:focus {
    outline: 2px solid #ffa400;
    border-color: #ffa400;
}

button {
    width: 100%;
    height: 50px;
    border: none;
    border-radius: 11px;
    background: #ffa400;
    color: #29170b;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
}

button:hover {
    background: #ed9700;
}

.error {
    background: #fff0f0;
    color: #a31919;
    padding: 12px;
    border-radius: 10px;
    margin-bottom: 18px;
    font-size: 14px;
}

.footer {
    text-align: center;
    color: #9b8585;
    font-size: 12px;
    margin-top: 25px;
}
</style>
</head>

<body>

<div class="login-box">

    <div class="brand">
        <img
            src="assets/fire-safety-bd-logo.png"
            alt="Fire Safety BD Logo"
        >
        <div class="brand-name">Fire Safety BD</div>
    </div>

    <div class="subtitle">অ্যাডমিন প্যানেল লগইন</div>

    <?php if ($error !== ''): ?>
        <div class="error">
            <?= h($error) ?>
        </div>
    <?php endif; ?>

    <form method="POST" action="index.php">

        <input
            type="hidden"
            name="csrf_token"
            value="<?= h(csrf_token()) ?>"
        >

        <label for="password">Admin Password</label>

        <input
            type="password"
            id="password"
            name="password"
            placeholder="আপনার পাসওয়ার্ড লিখুন"
            required
            autocomplete="current-password"
        >

        <button type="submit">Login</button>

    </form>

    <div class="footer">
        Fire Safety BD — Admin Panel
    </div>

</div>

</body>
</html>