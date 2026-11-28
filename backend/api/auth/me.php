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

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
    header('Allow: GET');
    respond(405, ['success' => false, 'message' => 'GET required.']);
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
        'SELECT
            u.id,
            u.full_name,
            u.email,
            u.mobile_number,
            u.current_status,
            u.company_name,
            u.designation,
            u.job_location,
            u.current_address,
            u.profile_photo
         FROM auth_sessions s
         INNER JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = :token_hash
           AND s.expires_at > NOW()
         LIMIT 1'
    );
    $stmt->execute([':token_hash' => $tokenHash]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        respond(401, [
            'success' => false,
            'message' => 'Session expired or invalid. Please log in again.'
        ]);
    }

    // Keep the existing response shape expected by the Flutter client.
    respond(200, [
        'success' => true,
        'user' => $user
    ]);

} catch (Throwable $e) {
    error_log(
        'Session validation failure: ' . get_class($e) .
        ' at ' . basename($e->getFile()) . ':' . $e->getLine()
    );

    respond(500, [
        'success' => false,
        'message' => 'Could not validate session.'
    ]);
}
