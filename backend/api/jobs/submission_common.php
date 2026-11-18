<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
require_once __DIR__ . '/../../db.php';

function submission_response(int $code, array $payload): void {
    http_response_code($code);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function submission_auth_user(PDO $pdo): int {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $header = $value;
                break;
            }
        }
    }
    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim((string)$header), $matches)) {
        submission_response(401, ['success' => false, 'message' => 'অনুগ্রহ করে লগইন করুন।']);
    }
    $stmt = $pdo->prepare(
        'SELECT u.id FROM auth_sessions s
         JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = ? AND s.expires_at > NOW() LIMIT 1'
    );
    $stmt->execute([hash('sha256', $matches[1])]);
    $id = $stmt->fetchColumn();
    if (!$id) {
        submission_response(401, ['success' => false, 'message' => 'সেশন শেষ হয়েছে। আবার লগইন করুন।']);
    }
    return (int)$id;
}

function submission_text(array $data, string $key, int $limit, bool $required = false): ?string {
    $raw = $data[$key] ?? '';
    if (!is_string($raw)) {
        submission_response(422, ['success' => false, 'message' => $key . ' সঠিক নয়।']);
    }
    $value = trim($raw);
    $length = function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);
    if ($length > $limit || ($required && $value === '')) {
        submission_response(422, ['success' => false, 'message' => $key . ' সঠিকভাবে পূরণ করুন।']);
    }
    return $value === '' ? null : $value;
}

function submission_phone(array $data, string $key): string {
    $phone = submission_text($data, $key, 20, true);
    if (!preg_match('/^\+?[0-9]{8,15}$/', (string)$phone)) {
        submission_response(422, ['success' => false, 'message' => $key . ' নম্বরটি সঠিক নয়।']);
    }
    return (string)$phone;
}

function submission_date(array $data): ?string {
    $date = submission_text($data, 'application_deadline', 10);
    if ($date === null) return null;
    $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', $date);
    if (!$parsed || $parsed->format('Y-m-d') !== $date) {
        submission_response(422, ['success' => false, 'message' => 'আবেদনের শেষ তারিখ সঠিক নয়।']);
    }
    return $date;
}

function submission_url(array $data): ?string {
    $url = submission_text($data, 'application_url', 2048);
    if ($url === null) return null;
    $parts = parse_url($url);
    if ($parts === false || strtolower($parts['scheme'] ?? '') !== 'https' ||
        empty($parts['host']) || isset($parts['user']) || isset($parts['pass'])) {
        submission_response(422, ['success' => false, 'message' => 'শুধু HTTPS আবেদনের লিংক দিন।']);
    }
    return $url;
}
