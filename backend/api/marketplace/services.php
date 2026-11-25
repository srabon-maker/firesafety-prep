<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
market_method('GET');
try {
    $stmt = $pdo->query("SELECT s.id, s.category_id, COALESCE(c.name,'') AS category_name, s.name, s.slug, s.description, s.pricing_type, s.price, s.image_url, s.is_featured FROM market_services s LEFT JOIN market_categories c ON c.id=s.category_id WHERE s.status='published' AND (c.id IS NULL OR c.is_active=1) ORDER BY s.is_featured DESC, s.id DESC LIMIT 500");
    market_reply(200, ['success' => true, 'data' => $stmt->fetchAll()]);
} catch (Throwable $e) { market_error($e); }
