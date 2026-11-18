<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=60');
header('X-Content-Type-Options: nosniff');

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
    header('Allow: GET');
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'GET required.']);
    exit;
}

try {
    require_once __DIR__ . '/../../db.php';
    if (!isset($pdo) || !$pdo instanceof PDO) {
        throw new RuntimeException('PDO database connection unavailable.');
    }
    // Uses the existing manobiki_firesafetyjobprep.sql schema unchanged.
    // Do not invent government/private classifications or circular URLs.
    $statement = $pdo->query(
        "SELECT j.id, j.organization, j.title, j.employment_type,
                j.location, j.salary, j.vacancies, j.description,
                j.requirements,
                DATE_FORMAT(j.application_deadline, '%Y-%m-%d') AS application_deadline,
                DATE_FORMAT(COALESCE(j.published_at, j.created_at),
                    '%Y-%m-%dT%H:%i:%s') AS published_at,
                j.application_url AS apply_url,
                j.category_id, c.name AS category,
                j.is_pinned
         FROM job_circulars j
         LEFT JOIN categories c ON c.id = j.category_id
         WHERE j.status = 'published'
         ORDER BY j.is_pinned DESC,
                  COALESCE(j.published_at, j.created_at) DESC, j.id DESC
         LIMIT 200"
    );
    echo json_encode(
        ['success' => true, 'data' => $statement->fetchAll(PDO::FETCH_ASSOC)],
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
