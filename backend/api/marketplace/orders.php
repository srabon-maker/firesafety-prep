<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
require_once __DIR__ . '/_orders.php';
$method = $_SERVER['REQUEST_METHOD'] ?? '';
if (!in_array($method, ['GET','POST'], true)) market_reply(405, ['success'=>false,'message'=>'GET or POST required']);
try {
    $userId = market_auth_user($pdo);
    if ($method === 'GET') {
        if (isset($_GET['order_id'])) {
            $id=market_positive_id($_GET['order_id']);
            $pdo->beginTransaction();
            $q=$pdo->prepare('SELECT id,order_number,subtotal,delivery_charge,total_amount,payment_method,payment_status,order_status,created_at,customer_name,mobile_number,delivery_address,customer_note FROM market_orders WHERE id=? AND user_id=?');
            $q->execute([$id,$userId]);
            $order=$q->fetch(PDO::FETCH_ASSOC);
            if (!$order) throw new OutOfBoundsException('Order not found');
            $q=$pdo->prepare('SELECT product_name,product_sku,quantity,unit_price,total_price FROM market_order_items WHERE order_id=? ORDER BY id');
            $q->execute([$id]);
            $order['items']=$q->fetchAll(PDO::FETCH_ASSOC);
            $q=$pdo->prepare('SELECT order_status,courier_name,tracking_number,created_at FROM market_order_events WHERE order_id=? ORDER BY id');
            $q->execute([$id]);
            $order['events']=$q->fetchAll(PDO::FETCH_ASSOC);
            $order['can_cancel']=market_order_can_cancel($order,market_order_managed($pdo,$id));
            $pdo->commit();
            market_reply(200,['success'=>true,'data'=>$order]);
        }
        $stmt = $pdo->prepare('SELECT id,order_number,subtotal,delivery_charge,total_amount,payment_method,payment_status,order_status,created_at FROM market_orders WHERE user_id=? ORDER BY id DESC LIMIT 100');
        $stmt->execute([$userId]);
        market_reply(200, ['success'=>true,'data'=>$stmt->fetchAll()]);
    }
    $data = market_input();
    $action=$data['action'] ?? 'place';
    if ($action==='cancel') {
        $id=market_positive_id($data['order_id'] ?? null);
        $pdo->beginTransaction();
        market_order_transition($pdo,$id,'cancelled',$userId);
        $pdo->commit();
        market_reply(200,['success'=>true,'message'=>'Order cancelled']);
    }
    if ($action!=='place') market_reply(422,['success'=>false,'message'=>'Invalid action']);
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
        $priceCents = market_order_cents($p['price']);
        if ($priceCents < 0) throw new DomainException('Invalid product price');
        $lineCents = $priceCents * $qty;
        $subtotalCents += $lineCents;
        $lines[] = [$p,$qty,$priceCents,$lineCents];
    }
    $deliveryCents=market_delivery_fee($pdo,true);
    $totalCents=$subtotalCents+$deliveryCents;
    // Compare the displayed quote; the server remains authoritative.
    if (array_key_exists('expected_total',$data)) {
        if (market_order_cents($data['expected_total'])!==$totalCents) throw new DomainException('Price or delivery charge changed. Refresh the cart and review the new total.');
    } elseif ($deliveryCents!==0) throw new DomainException('Update the app to review delivery charges before ordering.');
    $subtotal=market_order_money($subtotalCents);
    $delivery=market_order_money($deliveryCents);
    $total=market_order_money($totalCents);
    $number = 'FS-' . gmdate('Ymd') . '-' . strtoupper(bin2hex(random_bytes(6)));
    $stmt = $pdo->prepare("INSERT INTO market_orders (order_number,user_id,customer_name,mobile_number,delivery_address,subtotal,delivery_charge,total_amount,payment_method,payment_status,order_status,customer_note) VALUES (?,?,?,?,?,?,?,?,'cod','pending','pending',?)");
    $stmt->execute([$number,$userId,$name,$mobile,$address,$subtotal,$delivery,$total,$note === '' ? null : $note]);
    $orderId = (int)$pdo->lastInsertId();
    $insert = $pdo->prepare('INSERT INTO market_order_items (order_id,product_id,product_name,product_sku,quantity,unit_price,total_price) VALUES (?,?,?,?,?,?,?)');
    $stock = $pdo->prepare('UPDATE market_products SET stock_quantity=stock_quantity-? WHERE id=? AND stock_quantity>=?');
    foreach ($lines as [$p,$qty,$priceCents,$lineCents]) {
        $insert->execute([$orderId,(int)$p['id'],$p['name'],$p['sku'],$qty,market_order_money($priceCents),market_order_money($lineCents)]);
        $stock->execute([$qty,(int)$p['id'],$qty]);
        if ($stock->rowCount() !== 1) throw new DomainException('Stock changed, please try again');
    }
    market_order_event($pdo,$orderId,'pending','checkout');
    $pdo->prepare('DELETE FROM market_cart WHERE user_id=?')->execute([$userId]);
    $pdo->commit();
    market_reply(201, ['success'=>true,'message'=>'Order placed','data'=>['id'=>$orderId,'order_number'=>$number,'subtotal'=>$subtotal,'delivery_charge'=>$delivery,'total_amount'=>$total,'payment_method'=>'cod']]);
} catch (OutOfBoundsException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    market_reply(404,['success'=>false,'message'=>'Order not found']);
} catch (DomainException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    market_reply(409, ['success'=>false,'message'=>$e->getMessage()]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    market_error($e);
}
