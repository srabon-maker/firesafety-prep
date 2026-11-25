<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
market_method('GET');
try {
    $stmt = $pdo->query("SELECT p.id, p.category_id, COALESCE(c.name,'') AS category_name, p.name, p.slug, p.sku, p.description, p.price, p.compare_price, p.stock_quantity, p.image_url, p.is_featured FROM market_products p LEFT JOIN market_categories c ON c.id=p.category_id WHERE p.status='published' AND (c.id IS NULL OR c.is_active=1) ORDER BY p.is_featured DESC, p.id DESC LIMIT 500");
    market_reply(200, ['success' => true, 'data' => $stmt->fetchAll()]);
} catch (Throwable $e) { market_error($e); }
