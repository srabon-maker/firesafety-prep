<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
market_method('GET');
try {
    $stmt = $pdo->query('SELECT id, name, slug, category_type, description, image_url, parent_id FROM market_categories WHERE is_active=1 ORDER BY sort_order, name LIMIT 300');
    market_reply(200, ['success' => true, 'data' => $stmt->fetchAll()]);
} catch (Throwable $e) { market_error($e); }
