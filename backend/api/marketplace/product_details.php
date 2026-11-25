<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
market_method('GET');
$id = market_positive_id($_GET['id'] ?? null);
try {
    $stmt = $pdo->prepare("SELECT p.id, p.category_id, COALESCE(c.name,'') AS category_name, p.name, p.slug, p.sku, p.description, p.price, p.compare_price, p.stock_quantity, p.image_url FROM market_products p LEFT JOIN market_categories c ON c.id=p.category_id WHERE p.id=? AND p.status='published' AND (c.id IS NULL OR c.is_active=1) LIMIT 1");
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    if (!$item) market_reply(404, ['success' => false, 'message' => 'Product not found']);
    market_reply(200, ['success' => true, 'data' => $item]);
} catch (Throwable $e) { market_error($e); }
