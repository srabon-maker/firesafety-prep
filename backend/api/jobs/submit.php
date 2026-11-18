<?php
declare(strict_types=1);
require_once __DIR__ . '/submission_common.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    submission_response(405, ['success' => false, 'message' => 'POST required.']);
}
$body = file_get_contents('php://input');
if ($body === false || strlen($body) > 75000) {
    submission_response(413, ['success' => false, 'message' => 'বিজ্ঞপ্তির লেখা অতিরিক্ত বড়।']);
}
$data = json_decode($body, true);
if (!is_array($data) || array_is_list($data)) {
    submission_response(400, ['success' => false, 'message' => 'সঠিক JSON পাঠান।']);
}

try {
    if (!isset($pdo) || !($pdo instanceof PDO)) throw new RuntimeException('PDO missing');
    $userId = submission_auth_user($pdo);
    $title = submission_text($data, 'title', 255, true);
    $organization = submission_text($data, 'organization', 200, true);
    $description = submission_text($data, 'description', 60000, true);
    $mobile = submission_phone($data, 'mobile_number');
    $whatsapp = submission_phone($data, 'whatsapp_number');
    $publicContact = ($data['public_contact'] ?? false) === true ? 1 : 0;
    $location = submission_text($data, 'location', 200);
    $employment = submission_text($data, 'employment_type', 100);
    $salary = submission_text($data, 'salary', 120);
    $vacancies = submission_text($data, 'vacancies', 80);
    $requirements = submission_text($data, 'requirements', 60000);
    $url = submission_url($data);
    $deadline = submission_date($data);

    // 3 submissions per 24h per authenticated account. Prevents basic spam.
    $rate = $pdo->prepare(
        'SELECT COUNT(*) FROM job_submissions
         WHERE user_id = ? AND created_at >= NOW() - INTERVAL 1 DAY'
    );
    $rate->execute([$userId]);
    if ((int)$rate->fetchColumn() >= 3) {
        submission_response(429, [
            'success' => false,
            'message' => '২৪ ঘণ্টায় সর্বোচ্চ ৩টি সার্কুলার জমা দেওয়া যাবে।'
        ]);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO job_submissions
         (user_id, title, organization, location, employment_type, salary,
          vacancies, description, requirements, application_url,
          application_deadline, mobile_number, whatsapp_number, public_contact, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "pending")'
    );
    $stmt->execute([
        $userId, $title, $organization, $location, $employment, $salary,
        $vacancies, $description, $requirements, $url,
        $deadline, $mobile, $whatsapp, $publicContact
    ]);
    submission_response(201, [
        'success' => true,
        'message' => 'সার্কুলার জমা হয়েছে। অ্যাডমিন অনুমোদনের পর প্রকাশিত হবে।',
        'submission_id' => (int)$pdo->lastInsertId(),
        'status' => 'pending'
    ]);
} catch (PDOException $error) {
    error_log('Job submission failed: ' . $error->getMessage());
    submission_response(500, ['success' => false, 'message' => 'সার্কুলার জমা দেওয়া যায়নি।']);
} catch (Throwable $error) {
    error_log('Job submission error: ' . $error->getMessage());
    submission_response(500, ['success' => false, 'message' => 'সার্ভার ত্রুটি হয়েছে।']);
}
