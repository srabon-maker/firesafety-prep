<?php
declare(strict_types=1);
require_once __DIR__ . '/submission_common.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
    header('Allow: GET');
    submission_response(405, ['success' => false, 'message' => 'GET required.']);
}
try {
    if (!isset($pdo) || !($pdo instanceof PDO)) throw new RuntimeException('PDO missing');
    $userId = submission_auth_user($pdo);
    $stmt = $pdo->prepare(
        'SELECT id, title, organization, status, admin_note,
                DATE_FORMAT(created_at, "%Y-%m-%dT%H:%i:%s") AS created_at,
                published_job_id
         FROM job_submissions WHERE user_id = ? ORDER BY id DESC LIMIT 100'
    );
    $stmt->execute([$userId]);
    submission_response(200, ['success' => true, 'data' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
} catch (Throwable $error) {
    error_log('My job submissions failed: ' . $error->getMessage());
    submission_response(500, ['success' => false, 'message' => 'জমা দেওয়া সার্কুলার দেখা যাচ্ছে না।']);
}
