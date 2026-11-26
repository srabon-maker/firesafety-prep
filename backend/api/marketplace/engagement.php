<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';

try {
    $method = $_SERVER['REQUEST_METHOD'] ?? '';
    if ($method === 'GET') {
        $action = $_GET['action'] ?? 'overview';
        if ($action === 'overview') {
            $ratings = $pdo->query("SELECT r.product_id, ROUND(AVG(r.rating),1) AS average_rating, COUNT(*) AS review_count
                FROM market_product_reviews r JOIN market_products p ON p.id=r.product_id
                LEFT JOIN market_categories c ON c.id=p.category_id
                WHERE r.status='approved' AND p.status='published' AND (c.id IS NULL OR c.is_active=1)
                GROUP BY r.product_id")->fetchAll(PDO::FETCH_ASSOC);
            $banners = $pdo->query("SELECT b.id,b.product_id,b.title,b.subtitle,b.image_url
                FROM market_product_banners b JOIN market_products p ON p.id=b.product_id
                LEFT JOIN market_categories c ON c.id=p.category_id
                WHERE b.is_active=1 AND p.status='published' AND (c.id IS NULL OR c.is_active=1)
                ORDER BY b.sort_order,b.id DESC LIMIT 10")->fetchAll(PDO::FETCH_ASSOC);
            market_reply(200,['success'=>true,'data'=>['ratings'=>$ratings,'banners'=>$banners]]);
        }
        if ($action !== 'reviews') market_reply(404,['success'=>false,'message'=>'Unknown action']);
        $id = market_positive_id($_GET['product_id'] ?? null);
        $q = $pdo->prepare("SELECT p.id FROM market_products p LEFT JOIN market_categories c ON c.id=p.category_id
            WHERE p.id=? AND p.status='published' AND (c.id IS NULL OR c.is_active=1)");
        $q->execute([$id]);
        if (!$q->fetchColumn()) market_reply(404,['success'=>false,'message'=>'Product not found']);
        $q = $pdo->prepare("SELECT ROUND(AVG(rating),1) AS average_rating,COUNT(*) AS review_count
            FROM market_product_reviews WHERE product_id=? AND status='approved'");
        $q->execute([$id]);
        $summary = $q->fetch(PDO::FETCH_ASSOC);
        // Public reviews contain no customer identity or order details.
        $q = $pdo->prepare("SELECT id,rating,review_text,updated_at FROM market_product_reviews
            WHERE product_id=? AND status='approved' ORDER BY id DESC LIMIT 50");
        $q->execute([$id]);
        market_reply(200,['success'=>true,'data'=>['summary'=>$summary,'reviews'=>$q->fetchAll(PDO::FETCH_ASSOC)]]);
    }
    market_method('POST');
    $uid = market_auth_user($pdo);
    $data = market_input();
    $id = market_positive_id($data['product_id'] ?? null);
    $rating = market_positive_id($data['rating'] ?? null);
    if ($rating > 5) market_reply(422,['success'=>false,'message'=>'রেটিং ১ থেকে ৫ হতে হবে।']);
    $review = $data['review_text'] ?? '';
    if (!is_string($review) || market_strlen($review)>1000) market_reply(422,['success'=>false,'message'=>'রিভিউ সর্বোচ্চ ১০০০ অক্ষর।']);
    // Ownership and delivered status are checked on the server, not from client flags.
    $q = $pdo->prepare("SELECT 1 FROM market_orders o JOIN market_order_items i ON i.order_id=o.id
        JOIN market_products p ON p.id=i.product_id LEFT JOIN market_categories c ON c.id=p.category_id
        WHERE o.user_id=? AND i.product_id=? AND o.order_status='delivered' AND p.status='published'
        AND (c.id IS NULL OR c.is_active=1) LIMIT 1");
    $q->execute([$uid,$id]);
    if (!$q->fetchColumn()) market_reply(403,['success'=>false,'message'=>'শুধু ডেলিভারি সম্পন্ন হওয়া পণ্যের ক্রেতা রিভিউ দিতে পারবেন।']);
    // One review per buyer/product. An edited review returns to moderation.
    $q = $pdo->prepare("INSERT INTO market_product_reviews(product_id,user_id,rating,review_text,status)
        VALUES (?,?,?,?,'pending') ON DUPLICATE KEY UPDATE rating=VALUES(rating),review_text=VALUES(review_text),status='pending'");
    $q->execute([$id,$uid,$rating,trim($review)]);
    market_reply(200,['success'=>true,'message'=>'রিভিউ অনুমোদনের জন্য জমা হয়েছে।']);
} catch (Throwable $e) { market_error($e); }
