<?php
declare(strict_types=1);

require_once __DIR__ . '/profile_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    profileRespond(405, ['success' => false, 'message' => 'POST required.']);
}

$data = profileInput();
$allowedStatuses = ['Employed', 'Job Seeker', 'Student', 'Other'];

$required = static function (string $key, int $max) use ($data): string {
    $value = $data[$key] ?? null;
    if (!is_string($value)) {
        profileRespond(422, ['success' => false, 'message' => $key . ' is required.']);
    }
    $value = trim($value);
    if ($value === '' || mb_strlen($value) > $max) {
        profileRespond(422, ['success' => false, 'message' => 'Invalid ' . $key . '.']);
    }
    return $value;
};

$optional = static function (string $key, int $max) use ($data): ?string {
    $value = $data[$key] ?? '';
    if (!is_string($value)) {
        profileRespond(422, ['success' => false, 'message' => 'Invalid ' . $key . '.']);
    }
    $value = trim($value);
    if (mb_strlen($value) > $max) {
        profileRespond(422, ['success' => false, 'message' => $key . ' is too long.']);
    }
    return $value === '' ? null : $value;
};

$fullName = $required('full_name', 150);
$mobile = $required('mobile_number', 20);
$status = $required('current_status', 20);
if (!preg_match('/^[0-9+\\-\\s()]{7,20}$/', $mobile) ||
    !in_array($status, $allowedStatuses, true)) {
    profileRespond(422, ['success' => false, 'message' => 'Invalid phone or employment status.']);
}

$company = $optional('company_name', 200);
$designation = $optional('designation', 150);
$location = $optional('job_location', 200);
$address = $optional('current_address', 2000);

try {
    $userId = authenticatedProfileUserId($pdo);
    $stmt = $pdo->prepare(
        'UPDATE users SET full_name = ?, mobile_number = ?,
            current_status = ?, company_name = ?, designation = ?,
            job_location = ?, current_address = ?
         WHERE id = ?'
    );
    $stmt->execute([
        $fullName, $mobile, $status, $company,
        $designation, $location, $address, $userId
    ]);
    profileRespond(200, [
        'success' => true,
        'message' => 'Profile updated successfully.'
    ]);
} catch (PDOException $e) {
    error_log('Profile update error: ' . $e->getMessage());
    profileRespond(500, ['success' => false, 'message' => 'Could not update profile.']);
}
