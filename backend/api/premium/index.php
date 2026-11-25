<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
function premium_reply(int $status,array $data): never{
    http_response_code($status);
    echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);exit;
}
try {
    if(($_SERVER['REQUEST_METHOD']??'GET')!=='GET'){header('Allow: GET');premium_reply(405,['success'=>false,'message'=>'GET required']);}
    require_once __DIR__.'/../../db.php';
    require_once __DIR__.'/../../premium_access.php';
    $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
    $uid=premium_bearer_user($pdo);
    if($uid===null)premium_reply(401,['success'=>false,'message'=>'Login required']);
    $expiry=premium_active($pdo,$uid);
    $plans=$pdo->query("SELECT code,months,proposed_price_bdt FROM premium_plans ORDER BY months")->fetchAll(PDO::FETCH_ASSOC);
    foreach($plans as &$p){$p['months']=(int)$p['months'];$p['proposed_price_bdt']=(int)$p['proposed_price_bdt'];}unset($p);
    // Until Play verification and AdMob SDK are implemented, neither can be activated.
    premium_reply(200,['success'=>true,'premium'=>$expiry!==null,'expires_at'=>$expiry,
        'plans'=>$plans,'purchase_available'=>false,'ads_active'=>false,'features'=>['premium_interviews'=>$expiry!==null]]);
}catch(Throwable $e){error_log('Premium API: '.$e->getMessage());premium_reply(503,['success'=>false,'message'=>'Membership temporarily unavailable']);}
