<?php
declare(strict_types=1);

// Deploy this file together with update_profile.php and delete_account.php
// into the existing /api/auth/ directory, beside me.php.
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

require_once __DIR__ . '/../../db.php';

function profileRespond(int $status, array $data): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function profileInput(): array {
    $body = file_get_contents('php://input');
    if ($body === false || strlen($body) > 16384) {
        profileRespond(413, ['success' => false, 'message' => 'Invalid request size.']);
    }
    $data = json_decode($body, true);
    if (!is_array($data)) {
        profileRespond(400, ['success' => false, 'message' => 'Valid JSON is required.']);
    }
    return $data;
}

function authenticatedProfileUserId(PDO $pdo): int {
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authorization = $headers['Authorization']
        ?? $headers['authorization']
        ?? $_SERVER['HTTP_AUTHORIZATION']
        ?? '';

    if (!preg_match('/^Bearer\\s+([a-f0-9]{64})$/i', trim($authorization), $match)) {
        profileRespond(401, ['success' => false, 'message' => 'Session token required.']);
    }

    $stmt = $pdo->prepare(
        'SELECT u.id FROM auth_sessions s
         INNER JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = ? AND s.expires_at > NOW()
         LIMIT 1'
    );
    $stmt->execute([hash('sha256', $match[1])]);
    $userId = $stmt->fetchColumn();
    if (!$userId) {
        profileRespond(401, ['success' => false, 'message' => 'Session expired. Log in again.']);
    }
    return (int) $userId;
}
