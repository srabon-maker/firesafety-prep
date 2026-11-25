<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$method = $_SERVER['REQUEST_METHOD'] ?? '';
if (!in_array($method, ['GET','POST'], true)) market_reply(405, ['success'=>false,'message'=>'GET or POST required']);
try {
    $userId = market_auth_user($pdo);
    if ($method === 'GET') {
        $stmt = $pdo->prepare('SELECT id,order_number,subtotal,delivery_charge,total_amount,payment_method,payment_status,order_status,created_at FROM market_orders WHERE user_id=? ORDER BY id DESC LIMIT 100');
        $stmt->execute([$userId]);
        market_reply(200, ['success'=>true,'data'=>$stmt->fetchAll()]);
    }
    $data = market_input();
    $name = market_text($data['customer_name'] ?? null, 150, 'customer_name');
    $mobile = market_text($data['mobile_number'] ?? null, 20, 'mobile_number');
    if (!preg_match('/^[0-9+\- ]{10,20}$/D', $mobile)) market_reply(422, ['success'=>false,'message'=>'Invalid mobile number']);
    $address = market_text($data['delivery_address'] ?? null, 2000, 'delivery_address');
    $note = isset($data['customer_note']) && is_string($data['customer_note']) ? trim($data['customer_note']) : '';
    if (market_strlen($note) > 2000) market_reply(422, ['success'=>false,'message'=>'Note too long']);
    if (isset($data['payment_method']) && $data['payment_method'] !== 'cod') market_reply(422, ['success'=>false,'message'=>'Only COD is supported']);

    $pdo->beginTransaction();
    // Lock cart rows so two checkouts for the same account cannot both consume the cart.
    $stmt = $pdo->prepare('SELECT product_id,quantity FROM market_cart WHERE user_id=? ORDER BY product_id FOR UPDATE');
    $stmt->execute([$userId]);
    $cart = $stmt->fetchAll();
    if (!$cart) {
        $pdo->rollBack();
        market_reply(409, ['success'=>false,'message'=>'Cart is empty']);
    }
    $lines = [];
    $subtotalCents = 0;
    $productStmt = $pdo->prepare("SELECT id,name,sku,price,stock_quantity FROM market_products WHERE id=? AND status='published' FOR UPDATE");
    foreach ($cart as $row) {
        $qty = (int)$row['quantity'];
        if ($qty < 1 || $qty > 99) throw new DomainException('Invalid cart quantity');
        $productStmt->execute([(int)$row['product_id']]);
        $p = $productStmt->fetch();
        if (!$p || (int)$p['stock_quantity'] < $qty) throw new DomainException('Product unavailable or insufficient stock');
        $priceCents = (int)round((float)$p['price'] * 100);
        if ($priceCents < 0) throw new DomainException('Invalid product price');
        $lineCents = $priceCents * $qty;
        $subtotalCents += $lineCents;
        $lines[] = [$p,$qty,$priceCents,$lineCents];
    }
    // Delivery charge is intentionally zero until the business configures a verified rate.
    $subtotal = number_format($subtotalCents / 100, 2, '.', '');
    $number = 'FS-' . gmdate('Ymd') . '-' . strtoupper(bin2hex(random_bytes(6)));
    $stmt = $pdo->prepare("INSERT INTO market_orders (order_number,user_id,customer_name,mobile_number,delivery_address,subtotal,delivery_charge,total_amount,payment_method,payment_status,order_status,customer_note) VALUES (?,?,?,?,?,?,0,?,'cod','pending','pending',?)");
    $stmt->execute([$number,$userId,$name,$mobile,$address,$subtotal,$subtotal,$note === '' ? null : $note]);
    $orderId = (int)$pdo->lastInsertId();
    $insert = $pdo->prepare('INSERT INTO market_order_items (order_id,product_id,product_name,product_sku,quantity,unit_price,total_price) VALUES (?,?,?,?,?,?,?)');
    $stock = $pdo->prepare('UPDATE market_products SET stock_quantity=stock_quantity-? WHERE id=? AND stock_quantity>=?');
    foreach ($lines as [$p,$qty,$priceCents,$lineCents]) {
        $insert->execute([$orderId,(int)$p['id'],$p['name'],$p['sku'],$qty,number_format($priceCents/100,2,'.',''),number_format($lineCents/100,2,'.','')]);
        $stock->execute([$qty,(int)$p['id'],$qty]);
        if ($stock->rowCount() !== 1) throw new DomainException('Stock changed, please try again');
    }
    $pdo->prepare('DELETE FROM market_cart WHERE user_id=?')->execute([$userId]);
    $pdo->commit();
    market_reply(201, ['success'=>true,'message'=>'Order placed','data'=>['id'=>$orderId,'order_number'=>$number,'total_amount'=>$subtotal,'payment_method'=>'cod']]);
} catch (DomainException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    market_reply(409, ['success'=>false,'message'=>$e->getMessage()]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    market_error($e);
}
