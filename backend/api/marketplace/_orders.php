<?php
declare(strict_types=1);

// Output-free shared order policy for API and admin.
function market_order_cents(mixed $value): int {
    if (!is_string($value) && !is_int($value) && !is_float($value)) throw new DomainException('Invalid monetary amount');
    if (!preg_match('/^(\\d{1,10})(?:\\.(\\d{1,2}))?$/D', (string)$value, $m)) throw new DomainException('Invalid monetary amount');
    return (int)$m[1] * 100 + (int)str_pad($m[2] ?? '',2,'0');
}
function market_order_money(int $cents): string {
    if ($cents < 0 || $cents > 999999999999) throw new DomainException('Invalid order amount');
    return intdiv($cents,100) . '.' . str_pad((string)($cents % 100),2,'0',STR_PAD_LEFT);
}
function market_delivery_fee(PDO $pdo, bool $lock = false): int {
    $fee = $pdo->query('SELECT flat_fee FROM market_delivery_settings WHERE id=1' . ($lock ? ' FOR UPDATE' : ''))->fetchColumn();
    if ($fee === false) throw new RuntimeException('Delivery settings missing');
    return market_order_cents($fee);
}
function market_order_event(PDO $pdo,int $id,string $status,string $source,?string $courier=null,?string $tracking=null): void {
    $q=$pdo->prepare('INSERT INTO market_order_events (order_id,order_status,source,courier_name,tracking_number) VALUES (?,?,?,?,?)');
    $q->execute([$id,$status,$source,$courier,$tracking]);
}
function market_order_managed(PDO $pdo,int $id): bool {
    $q=$pdo->prepare("SELECT id FROM market_order_events WHERE order_id=? AND source='checkout' AND order_status='pending' LIMIT 1");
    $q->execute([$id]);
    return (bool)$q->fetchColumn();
}
function market_order_can_cancel(array $order,bool $managed): bool {
    return $managed && $order['order_status']==='pending' && $order['payment_method']==='cod' && $order['payment_status']==='pending';
}
function market_order_next(string $current): array {
    return match($current) {
        'pending'=>['confirmed','cancelled'],
        'confirmed'=>['processing','cancelled'],
        'processing'=>['shipped','cancelled'],
        'shipped'=>['delivered'],
        default=>[],
    };
}
// Caller must own a transaction. Lock order before status/stock changes.
// Only new checkout events prove stock was reserved by this implementation.
function market_order_transition(PDO $pdo,int $id,string $next,?int $userId=null,?string $courier=null,?string $tracking=null,bool $legacyAcknowledged=false): void {
    if (!$pdo->inTransaction()) throw new LogicException('Transaction required');
    $sql='SELECT id,user_id,order_status,payment_method,payment_status FROM market_orders WHERE id=?';
    if ($userId!==null) $sql.=' AND user_id=?';
    $q=$pdo->prepare($sql.' FOR UPDATE');
    $q->execute($userId===null?[$id]:[$id,$userId]);
    $order=$q->fetch(PDO::FETCH_ASSOC);
    if (!$order) throw new OutOfBoundsException('Order not found');
    $managed=market_order_managed($pdo,$id);
    if ($userId!==null && ($next!=='cancelled' || !market_order_can_cancel($order,$managed))) throw new DomainException('Only your pending unpaid COD orders placed after the upgrade can be cancelled here');
    $current=(string)$order['order_status'];
    if (!in_array($next,market_order_next($current),true)) throw new DomainException('Order status changed or transition not allowed');
    if ($next==='cancelled') {
        if ($order['payment_method']!=='cod' || $order['payment_status']!=='pending') throw new DomainException('Paid orders require manual payment reconciliation');
        if ($managed) {
            $q=$pdo->prepare('SELECT product_id,quantity FROM market_order_items WHERE order_id=? ORDER BY product_id,id FOR UPDATE');
            $q->execute([$id]);
            $lines=$q->fetchAll(PDO::FETCH_ASSOC);
            if (!$lines) throw new DomainException('No order items; contact administrator');
            $stock=$pdo->prepare('UPDATE market_products SET stock_quantity=stock_quantity+? WHERE id=?');
            foreach ($lines as $line) {
                $productId=(int)$line['product_id']; $qty=(int)$line['quantity'];
                if ($productId<1 || $qty<1 || $qty>99) throw new DomainException('Order stock needs manual reconciliation');
                $stock->execute([$qty,$productId]);
                if ($stock->rowCount()!==1) throw new DomainException('Order product missing; stock needs manual reconciliation');
            }
        } elseif (!$legacyAcknowledged) throw new DomainException('Legacy order: confirm manual stock reconciliation');
    }
    if ($next!=='shipped') { $courier=null; $tracking=null; }
    $q=$pdo->prepare('UPDATE market_orders SET order_status=? WHERE id=? AND order_status=?');
    $q->execute([$next,$id,$current]);
    if ($q->rowCount()!==1) throw new DomainException('Order status changed');
    market_order_event($pdo,$id,$next,$userId===null?'admin':'customer',$courier,$tracking);
}
