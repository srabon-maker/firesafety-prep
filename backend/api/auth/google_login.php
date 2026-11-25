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

function verifyGoogleIdToken(string $idToken, string $expectedClientId): array
{
    if ($idToken === '' || strlen($idToken) > 8192) {
        respond(422, [
            'success' => false,
            'message' => 'A valid Google ID Token is required.'
        ]);
    }

    if (!function_exists('curl_init')) {
        respond(503, [
            'success' => false,
            'message' => 'Google verification service is unavailable.'
        ]);
    }

    $url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($idToken);
    $ch = curl_init($url);

    if ($ch === false) {
        throw new RuntimeException('Could not initialize Google verification.');
    }

    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 12,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTPHEADER => ['Accept: application/json'],
        CURLOPT_USERAGENT => 'FireSafetyBD-Auth/1.0'
    ]);

    $response = curl_exec($ch);
    $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($response === false) {
        error_log('Google token verification transport failure: ' . $curlError);
        respond(503, [
            'success' => false,
            'message' => 'Google verification service unavailable.'
        ]);
    }

    if ($httpCode !== 200) {
        respond(401, [
            'success' => false,
            'message' => 'Google verification failed.'
        ]);
    }

    $google = json_decode($response, true);

    if (!is_array($google)) {
        respond(401, [
            'success' => false,
            'message' => 'Invalid Google verification response.'
        ]);
    }

    $issuer = (string) ($google['iss'] ?? '');
    $audience = (string) ($google['aud'] ?? '');
    $expiry = filter_var($google['exp'] ?? null, FILTER_VALIDATE_INT);
    $emailVerified = $google['email_verified'] ?? false;

    if (
        !in_array($issuer, ['accounts.google.com', 'https://accounts.google.com'], true) ||
        !hash_equals($expectedClientId, $audience) ||
        $expiry === false ||
        $expiry <= time() ||
        !in_array($emailVerified, [true, 'true', 1, '1'], true)
    ) {
        respond(401, [
            'success' => false,
            'message' => 'Google account verification failed.'
        ]);
    }

    $googleId = trim((string) ($google['sub'] ?? ''));
    $email = strtolower(trim((string) ($google['email'] ?? '')));

    if (
        $googleId === '' ||
        strlen($googleId) > 255 ||
        $email === '' ||
        !filter_var($email, FILTER_VALIDATE_EMAIL) ||
        strlen($email) > 255
    ) {
        respond(401, [
            'success' => false,
            'message' => 'Google account information is incomplete.'
        ]);
    }

    return $google;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    respond(405, ['success' => false, 'message' => 'POST required.']);
}

try {
    require_once __DIR__ . '/../../db.php';

    if (!isset($pdo) || !($pdo instanceof PDO)) {
        throw new RuntimeException('Database connection unavailable.');
    }

    // Keep this value identical to the Flutter serverClientId.
    $googleWebClientId =
        '489619291156-dmva2n4skh4snd9qbl0ne2tionpm92b9.apps.googleusercontent.com';

    $rawInput = file_get_contents('php://input');
    if ($rawInput === false || strlen($rawInput) > 16384) {
        respond(413, ['success' => false, 'message' => 'Request is too large.']);
    }

    $data = json_decode($rawInput, true);
    if (!is_array($data)) {
        respond(400, ['success' => false, 'message' => 'Invalid JSON request.']);
    }

    $idToken = $data['id_token'] ?? null;
    if (!is_string($idToken)) {
        respond(422, ['success' => false, 'message' => 'Google ID Token is required.']);
    }

    $google = verifyGoogleIdToken(trim($idToken), $googleWebClientId);
    $googleId = trim((string) $google['sub']);
    $email = strtolower(trim((string) $google['email']));

    $stmt = $pdo->prepare(
        'SELECT
            id, google_id, full_name, email, mobile_number,
            current_status, company_name, designation,
            job_location, current_address, profile_photo, is_registered
         FROM users
         WHERE google_id = :google_id OR email = :email
         LIMIT 1'
    );
    $stmt->execute([
        ':google_id' => $googleId,
        ':email' => $email
    ]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    $googleUser = [
        'name' => (string) ($google['name'] ?? ''),
        'email' => $email,
        'photo' => (string) ($google['picture'] ?? ''),
        'google_id' => $googleId
    ];

    if (!$user) {
        respond(200, [
            'success' => true,
            'needs_registration' => true,
            'google_user' => $googleUser
        ]);
    }

    $storedGoogleId = (string) ($user['google_id'] ?? '');
    if ($storedGoogleId === '' || !hash_equals($storedGoogleId, $googleId)) {
        respond(409, [
            'success' => false,
            'message' => 'This email is already associated with another account.'
        ]);
    }

    if ((int) $user['is_registered'] !== 1) {
        respond(403, [
            'success' => false,
            'message' => 'Registration is incomplete.'
        ]);
    }

    $sessionToken = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $sessionToken);
    $expiresAt = date('Y-m-d H:i:s', time() + (30 * 86400));

    $session = $pdo->prepare(
        'INSERT INTO auth_sessions (user_id, token_hash, expires_at)
         VALUES (:user_id, :token_hash, :expires_at)'
    );
    $session->execute([
        ':user_id' => (int) $user['id'],
        ':token_hash' => $tokenHash,
        ':expires_at' => $expiresAt
    ]);

    respond(200, [
        'success' => true,
        'needs_registration' => false,
        'session_token' => $sessionToken,
        'user' => [
            'id' => (int) $user['id'],
            'full_name' => $user['full_name'],
            'email' => $user['email'],
            'mobile_number' => $user['mobile_number'],
            'current_status' => $user['current_status'],
            'company_name' => $user['company_name'],
            'designation' => $user['designation'],
            'job_location' => $user['job_location'],
            'current_address' => $user['current_address'],
            'profile_photo' => $user['profile_photo']
        ]
    ]);

} catch (Throwable $e) {
    error_log(
        'Google login failure: ' . get_class($e) .
        ' at ' . basename($e->getFile()) . ':' . $e->getLine()
    );

    respond(500, [
        'success' => false,
        'message' => 'Login server error. Please try again.'
    ]);
}
