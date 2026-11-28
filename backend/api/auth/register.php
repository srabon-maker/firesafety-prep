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
        respond(422, ['success' => false, 'message' => 'A valid Google ID Token is required.']);
    }

    if (!function_exists('curl_init')) {
        respond(503, ['success' => false, 'message' => 'Google verification service is unavailable.']);
    }

    $ch = curl_init(
        'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($idToken)
    );

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
        error_log('Google registration verification transport failure: ' . $curlError);
        respond(503, ['success' => false, 'message' => 'Google verification service unavailable.']);
    }

    if ($httpCode !== 200) {
        respond(401, ['success' => false, 'message' => 'Google verification failed.']);
    }

    $google = json_decode($response, true);
    if (!is_array($google)) {
        respond(401, ['success' => false, 'message' => 'Invalid Google verification response.']);
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
        respond(401, ['success' => false, 'message' => 'Google account verification failed.']);
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
        respond(401, ['success' => false, 'message' => 'Google account information is incomplete.']);
    }

    return $google;
}

function requiredString(array $data, string $key): ?string
{
    $value = $data[$key] ?? null;
    return is_string($value) ? trim($value) : null;
}

function optionalString(array $data, string $key, int $maxLength): ?string
{
    if (!array_key_exists($key, $data) || $data[$key] === null || $data[$key] === '') {
        return null;
    }

    if (!is_string($data[$key])) {
        respond(422, ['success' => false, 'message' => 'Invalid value for ' . $key . '.']);
    }

    $value = trim($data[$key]);
    $length = function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);

    if ($value === '') {
        return null;
    }

    if ($length > $maxLength) {
        respond(422, ['success' => false, 'message' => 'The ' . $key . ' field is too long.']);
    }

    return $value;
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
        respond(400, ['success' => false, 'message' => 'Invalid request.']);
    }

    $idToken = requiredString($data, 'id_token');
    $fullName = requiredString($data, 'full_name');
    $mobile = requiredString($data, 'mobile_number');
    $status = requiredString($data, 'current_status');

    $allowedStatuses = ['Employed', 'Job Seeker', 'Student', 'Other'];

    if (
        $idToken === null || $idToken === '' ||
        $fullName === null || $fullName === '' ||
        $mobile === null || $mobile === '' ||
        $status === null || !in_array($status, $allowedStatuses, true)
    ) {
        respond(422, [
            'success' => false,
            'message' => 'Name, mobile, status and Google token are required.'
        ]);
    }

    $nameLength = function_exists('mb_strlen')
        ? mb_strlen($fullName, 'UTF-8')
        : strlen($fullName);

    if (
        $nameLength > 150 ||
        preg_match('/[\x00-\x1F\x7F]/', $fullName) ||
        !preg_match('/^[0-9+\-\s()]{7,20}$/', $mobile)
    ) {
        respond(422, ['success' => false, 'message' => 'Invalid name or mobile number.']);
    }

    $companyName = optionalString($data, 'company_name', 200);
    $designation = optionalString($data, 'designation', 150);
    $jobLocation = optionalString($data, 'job_location', 200);
    $currentAddress = optionalString($data, 'current_address', 10000);

    $google = verifyGoogleIdToken($idToken, $googleWebClientId);
    $googleId = trim((string) $google['sub']);
    $email = strtolower(trim((string) $google['email']));

    $profilePhoto = null;
    $picture = $google['picture'] ?? null;
    if (is_string($picture) && $picture !== '') {
        $pictureParts = parse_url($picture);
        if (
            is_array($pictureParts) &&
            strtolower((string) ($pictureParts['scheme'] ?? '')) === 'https' &&
            isset($pictureParts['host'])
        ) {
            $profilePhoto = $picture;
        }
    }

    $pdo->beginTransaction();

    $check = $pdo->prepare(
        'SELECT id FROM users WHERE google_id = :google_id OR email = :email LIMIT 1'
    );
    $check->execute([
        ':google_id' => $googleId,
        ':email' => $email
    ]);

    if ($check->fetch(PDO::FETCH_ASSOC)) {
        $pdo->rollBack();
        respond(409, [
            'success' => false,
            'message' => 'This account is already registered. Please log in.'
        ]);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO users (
            google_id, full_name, email, mobile_number,
            current_status, company_name, designation,
            job_location, current_address, profile_photo,
            is_registered
        ) VALUES (
            :google_id, :full_name, :email, :mobile_number,
            :current_status, :company_name, :designation,
            :job_location, :current_address, :profile_photo, 1
        )'
    );

    $stmt->execute([
        ':google_id' => $googleId,
        ':full_name' => $fullName,
        ':email' => $email,
        ':mobile_number' => $mobile,
        ':current_status' => $status,
        ':company_name' => $companyName,
        ':designation' => $designation,
        ':job_location' => $jobLocation,
        ':current_address' => $currentAddress,
        ':profile_photo' => $profilePhoto
    ]);

    $userId = (int) $pdo->lastInsertId();

    $sessionToken = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $sessionToken);
    $expiresAt = date('Y-m-d H:i:s', time() + (30 * 86400));

    $session = $pdo->prepare(
        'INSERT INTO auth_sessions (user_id, token_hash, expires_at)
         VALUES (:user_id, :token_hash, :expires_at)'
    );
    $session->execute([
        ':user_id' => $userId,
        ':token_hash' => $tokenHash,
        ':expires_at' => $expiresAt
    ]);

    $pdo->commit();

    respond(201, [
        'success' => true,
        'message' => 'Registration successful.',
        'session_token' => $sessionToken,
        'user' => [
            'id' => $userId,
            'name' => $fullName,
            'email' => $email,
            'mobile_number' => $mobile,
            'current_status' => $status,
            'company_name' => $companyName,
            'designation' => $designation,
            'job_location' => $jobLocation,
            'current_address' => $currentAddress,
            'photo' => $profilePhoto ?? ''
        ]
    ]);

} catch (PDOException $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    // Do not expose SQL details or request/token contents to the client.
    error_log(
        'Registration database failure: SQLSTATE ' .
        (string) $e->getCode()
    );

    if ((string) $e->getCode() === '23000') {
        respond(409, [
            'success' => false,
            'message' => 'This account is already registered. Please log in.'
        ]);
    }

    respond(500, [
        'success' => false,
        'message' => 'Registration failed. Please try again.'
    ]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log(
        'Registration failure: ' . get_class($e) .
        ' at ' . basename($e->getFile()) . ':' . $e->getLine()
    );

    respond(500, [
        'success' => false,
        'message' => 'Registration failed. Please try again.'
    ]);
}
