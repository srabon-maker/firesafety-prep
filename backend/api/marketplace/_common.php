<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

require_once __DIR__ . '/../../db.php';

function market_reply(int $code, array $data): never {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function market_method(string $method): void {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== $method) {
        header('Allow: ' . $method);
        market_reply(405, ['success' => false, 'message' => "$method required"]);
    }
}
function market_input(): array {
    if (strlen((string)file_get_contents('php://input', false, null, 0, 1048577)) > 1048576) {
        market_reply(413, ['success' => false, 'message' => 'Request too large']);
    }
    $raw = file_get_contents('php://input');
    $data = json_decode($raw === false ? '' : $raw, true);
    if (!is_array($data) || array_is_list($data)) {
        market_reply(400, ['success' => false, 'message' => 'JSON object required']);
    }
    return $data;
}
function market_positive_id(mixed $value): int {
    if (!is_scalar($value) || !preg_match('/^[1-9][0-9]*$/D', (string)$value)) {
        market_reply(422, ['success' => false, 'message' => 'Invalid ID']);
    }
    $id = filter_var((string)$value, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($id === false) market_reply(422, ['success' => false, 'message' => 'Invalid ID']);
    return $id;
}
function market_strlen(string $value): int {
    if (function_exists('mb_strlen')) return mb_strlen($value, 'UTF-8');
    return preg_match_all('/./us', $value) ?: 0;
}
function market_text(mixed $value, int $max, string $field): string {
    if (!is_string($value)) market_reply(422, ['success' => false, 'message' => "Invalid $field"]);
    $value = trim($value);
    if ($value === '' || market_strlen($value) > $max) {
        market_reply(422, ['success' => false, 'message' => "Invalid $field"]);
    }
    return $value;
}
function market_auth_user(PDO $pdo): int {
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!$authorization && function_exists('getallheaders')) {
        foreach (getallheaders() as $key => $value) {
            if (strcasecmp($key, 'Authorization') === 0) $authorization = $value;
        }
    }
    if (!is_string($authorization) || !preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $m)) {
        market_reply(401, ['success' => false, 'message' => 'Please log in']);
    }
    $stmt = $pdo->prepare('SELECT s.user_id FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at > NOW() LIMIT 1');
    $stmt->execute([hash('sha256', $m[1])]);
    $id = $stmt->fetchColumn();
    if ($id === false) market_reply(401, ['success' => false, 'message' => 'Session expired']);
    return (int)$id;
}
function market_error(Throwable $e): never {
    error_log('Marketplace API error: ' . $e->getMessage());
    market_reply(500, ['success' => false, 'message' => 'Server error. Please try again.']);
}
