<?php

if (!function_exists('start_secure_session')) {
    function start_secure_session(): void {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            $https = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';

            session_set_cookie_params([
                'httponly' => true,
                'secure' => $https,
                'samesite' => 'Strict',
            ]);

            session_start();
        }
    }
}

if (!function_exists('require_admin')) {
    function require_admin(): void {
        start_secure_session();

        if (empty($_SESSION['admin_logged_in'])) {
            header('Location: index.php');
            exit;
        }
    }
}

if (!function_exists('csrf_token')) {
    function csrf_token(): string {
        start_secure_session();

        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }

        return $_SESSION['csrf_token'];
    }
}

if (!function_exists('verify_csrf')) {
    function verify_csrf(): void {
        start_secure_session();

        $sent = $_POST['csrf_token'] ?? '';

        if (
            !is_string($sent) ||
            empty($_SESSION['csrf_token']) ||
            !hash_equals($_SESSION['csrf_token'], $sent)
        ) {
            http_response_code(403);
            exit('Invalid request token. Go back and try again.');
        }
    }
}

if (!function_exists('h')) {
    function h(?string $value): string {
        return htmlspecialchars(
            (string)$value,
            ENT_QUOTES | ENT_SUBSTITUTE,
            'UTF-8'
        );
    }
}