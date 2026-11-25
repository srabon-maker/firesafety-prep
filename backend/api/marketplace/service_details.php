<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
market_method('GET');
$id = market_positive_id($_GET['id'] ?? null);
try {
    $stmt = $pdo->prepare("SELECT s.id, s.category_id, COALESCE(c.name,'') AS category_name, s.name, s.slug, s.description, s.pricing_type, s.price, s.image_url FROM market_services s LEFT JOIN market_categories c ON c.id=s.category_id WHERE s.id=? AND s.status='published' AND (c.id IS NULL OR c.is_active=1) LIMIT 1");
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    if (!$item) market_reply(404, ['success' => false, 'message' => 'Service not found']);
    market_reply(200, ['success' => true, 'data' => $item]);
} catch (Throwable $e) { market_error($e); }
