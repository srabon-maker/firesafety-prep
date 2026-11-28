<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Pragma: no-cache');

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
    );
    exit;
}

function getBearerToken(): ?string
{
    $authorization = '';

    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        foreach ($headers as $name => $value) {
            if (strcasecmp((string) $name, 'Authorization') === 0 && is_string($value)) {
                $authorization = $value;
                break;
            }
        }
    }

    if ($authorization === '') {
        $authorization = (string) ($_SERVER['HTTP_AUTHORIZATION'] ?? '');
    }

    if ($authorization === '' && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $authorization = (string) $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    }

    if (!preg_match('/^Bearer[ \t]+([a-f0-9]{64})$/iD', trim($authorization), $matches)) {
        return null;
    }

    return $matches[1];
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    respond(405, ['success' => false, 'message' => 'POST required.']);
}

$token = getBearerToken();
if ($token === null) {
    respond(401, ['success' => false, 'message' => 'Session token required.']);
}

try {
    require_once __DIR__ . '/../../db.php';

    if (!isset($pdo) || !($pdo instanceof PDO)) {
        throw new RuntimeException('Database connection unavailable.');
    }

    $tokenHash = hash('sha256', $token);

    $stmt = $pdo->prepare(
        'DELETE FROM auth_sessions WHERE token_hash = :token_hash'
    );
    $stmt->execute([':token_hash' => $tokenHash]);

    // Idempotent logout: a valid-format token receives success even if already revoked.
    respond(200, [
        'success' => true,
        'message' => 'Logged out successfully.'
    ]);

} catch (Throwable $e) {
    error_log(
        'Logout failure: ' . get_class($e) .
        ' at ' . basename($e->getFile()) . ':' . $e->getLine()
    );

    respond(500, [
        'success' => false,
        'message' => 'Logout failed. Please try again.'
    ]);
}
