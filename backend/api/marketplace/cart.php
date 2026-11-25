<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
require_once __DIR__ . '/_orders.php';
$method = $_SERVER['REQUEST_METHOD'] ?? '';
if (!in_array($method, ['GET','POST'], true)) market_reply(405, ['success'=>false,'message'=>'GET or POST required']);
try {
    $userId = market_auth_user($pdo);
    if ($method === 'POST') {
        $data = market_input();
        $action = $data['action'] ?? 'set';
        if (!in_array($action, ['set','remove','clear'], true)) market_reply(422, ['success'=>false,'message'=>'Invalid action']);
        if ($action === 'clear') {
            $pdo->prepare('DELETE FROM market_cart WHERE user_id=?')->execute([$userId]);
        } else {
            $productId = market_positive_id($data['product_id'] ?? null);
            if ($action === 'remove') {
                $pdo->prepare('DELETE FROM market_cart WHERE user_id=? AND product_id=?')->execute([$userId,$productId]);
            } else {
                $quantity = filter_var($data['quantity'] ?? null, FILTER_VALIDATE_INT);
                if ($quantity === false || $quantity < 0 || $quantity > 99) market_reply(422, ['success'=>false,'message'=>'Quantity must be 0–99']);
                $stmt = $pdo->prepare("SELECT stock_quantity FROM market_products WHERE id=? AND status='published'");
                $stmt->execute([$productId]);
                $stock = $stmt->fetchColumn();
                if ($stock === false) market_reply(404, ['success'=>false,'message'=>'Product unavailable']);
                if ($quantity > (int)$stock) market_reply(409, ['success'=>false,'message'=>'Insufficient stock']);
                if ($quantity === 0) {
                    $pdo->prepare('DELETE FROM market_cart WHERE user_id=? AND product_id=?')->execute([$userId,$productId]);
                } else {
                    $pdo->prepare('INSERT INTO market_cart (user_id,product_id,quantity) VALUES (?,?,?) ON DUPLICATE KEY UPDATE quantity=VALUES(quantity)')->execute([$userId,$productId,$quantity]);
                }
            }
        }
    }
    $stmt = $pdo->prepare("SELECT c.product_id, c.quantity, p.name, p.price, p.stock_quantity, p.image_url, (c.quantity*p.price) AS line_total FROM market_cart c JOIN market_products p ON p.id=c.product_id WHERE c.user_id=? AND p.status='published' ORDER BY c.id");
    $stmt->execute([$userId]);
    $items = $stmt->fetchAll();
    $sum=0;
    foreach ($items as $item) $sum+=(int)$item['quantity']*market_order_cents($item['price']);
    $fee=$items?market_delivery_fee($pdo):0;
    market_reply(200,['success'=>true,'data'=>['items'=>$items,'subtotal'=>market_order_money($sum),
        'delivery_charge'=>market_order_money($fee),'total_amount'=>market_order_money($sum+$fee)]]);
} catch (Throwable $e) { market_error($e); }
