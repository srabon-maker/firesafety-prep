<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=60');
header('X-Content-Type-Options: nosniff');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET');
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'GET required.']);
    exit;
}

require_once __DIR__ . '/../../db.php';

try {
    if (!isset($pdo) || !$pdo instanceof PDO) {
        throw new RuntimeException('PDO database connection unavailable.');
    }
    // Never expose draft or archived jobs to the public API.
    $statement = $pdo->query(
        "SELECT id, organization, title, job_type, employment_type,
                location, salary, description, requirements,
                DATE_FORMAT(application_deadline, '%Y-%m-%d') AS application_deadline,
                DATE_FORMAT(published_at, '%Y-%m-%dT%H:%i:%s') AS published_at,
                apply_url, circular_url
         FROM job_circulars
         WHERE status = 'published'
         ORDER BY published_at DESC, id DESC
         LIMIT 200"
    );
    $items = $statement->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(
        ['success' => true, 'data' => $items],
        JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
    );
} catch (Throwable $error) {
    error_log('Jobs API failed: ' . $error->getMessage());
    header('Cache-Control: no-store');
    http_response_code(500);
    echo json_encode(
        ['success' => false, 'message' => 'Job circulars are temporarily unavailable.']
    );
}
