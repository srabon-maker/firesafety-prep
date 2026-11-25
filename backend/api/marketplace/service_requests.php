<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$method = $_SERVER['REQUEST_METHOD'] ?? '';
if (!in_array($method, ['GET','POST'], true)) market_reply(405, ['success'=>false,'message'=>'GET or POST required']);
try {
    $userId = market_auth_user($pdo);
    if ($method === 'GET') {
        $stmt = $pdo->prepare('SELECT r.id,r.request_number,r.service_id,s.name AS service_name,r.service_location,r.preferred_date,r.status,r.created_at FROM market_service_requests r LEFT JOIN market_services s ON s.id=r.service_id WHERE r.user_id=? ORDER BY r.id DESC LIMIT 100');
        $stmt->execute([$userId]);
        market_reply(200, ['success'=>true,'data'=>$stmt->fetchAll()]);
    }
    $data = market_input();
    $serviceId = market_positive_id($data['service_id'] ?? null);
    $name = market_text($data['customer_name'] ?? null,150,'customer_name');
    $mobile = market_text($data['mobile_number'] ?? null,20,'mobile_number');
    if (!preg_match('/^[0-9+\- ]{10,20}$/D', $mobile)) market_reply(422, ['success'=>false,'message'=>'Invalid mobile number']);
    $location = market_text($data['service_location'] ?? null,2000,'service_location');
    $company = isset($data['company_name']) && is_string($data['company_name']) ? trim($data['company_name']) : '';
    $details = isset($data['request_details']) && is_string($data['request_details']) ? trim($data['request_details']) : '';
    if (market_strlen($company) > 200 || market_strlen($details) > 10000) market_reply(422, ['success'=>false,'message'=>'Field too long']);
    $date = $data['preferred_date'] ?? null;
    if ($date !== null && $date !== '') {
        if (!is_string($date) || !preg_match('/^\d{4}-\d{2}-\d{2}$/D', $date)) market_reply(422, ['success'=>false,'message'=>'Invalid preferred date']);
        $parsed = DateTimeImmutable::createFromFormat('!Y-m-d',$date);
        if (!$parsed || $parsed->format('Y-m-d') !== $date) market_reply(422, ['success'=>false,'message'=>'Invalid preferred date']);
    } else $date = null;
    $stmt = $pdo->prepare("SELECT id FROM market_services WHERE id=? AND status='published'");
    $stmt->execute([$serviceId]);
    if (!$stmt->fetchColumn()) market_reply(404, ['success'=>false,'message'=>'Service unavailable']);
    $number = 'SR-' . gmdate('Ymd') . '-' . strtoupper(bin2hex(random_bytes(6)));
    $stmt = $pdo->prepare('INSERT INTO market_service_requests (request_number,user_id,service_id,customer_name,mobile_number,company_name,service_location,request_details,preferred_date,status) VALUES (?,?,?,?,?,?,?,?,?,\'pending\')');
    $stmt->execute([$number,$userId,$serviceId,$name,$mobile,$company === '' ? null : $company,$location,$details === '' ? null : $details,$date]);
    market_reply(201, ['success'=>true,'message'=>'Service request submitted','data'=>['request_number'=>$number,'id'=>(int)$pdo->lastInsertId()]]);
} catch (Throwable $e) { market_error($e); }
