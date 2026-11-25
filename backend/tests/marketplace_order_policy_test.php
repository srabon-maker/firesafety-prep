<?php
declare(strict_types=1);
require_once __DIR__ . '/../api/marketplace/_orders.php';
function check(bool $ok,string $message): void { if (!$ok) throw new RuntimeException($message); }
check(market_order_cents('125.05')===12505,'exact cents');
check(market_order_money(12505)==='125.05','exact money');
check(market_order_cents('12.5')===1250,'one decimal');
foreach (['-1','1.001','1e2','NaN',''] as $invalid) {
    try { market_order_cents($invalid); throw new RuntimeException('accepted invalid money'); }
    catch (DomainException $expected) {}
}
$order=['order_status'=>'pending','payment_method'=>'cod','payment_status'=>'pending'];
check(market_order_can_cancel($order,true),'pending managed COD');
check(!market_order_can_cancel($order,false),'legacy order');
$order['order_status']='confirmed';
check(!market_order_can_cancel($order,true),'confirmed customer cancellation disallowed');
$order['order_status']='pending';$order['payment_status']='paid';
check(!market_order_can_cancel($order,true),'paid order');
check(market_order_next('cancelled')===[],'cancelled terminal');
check(market_order_next('delivered')===[],'delivered terminal');
check(market_order_next('shipped')===['delivered'],'no shipped cancellation');
check(market_order_next('pending')===['confirmed','cancelled'],'pending transitions');
echo "Marketplace order policy tests passed\n";
