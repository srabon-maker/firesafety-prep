<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
function support_reply(int $code,array $data):never{
    http_response_code($code);echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);exit;
}
try{
    $method=$_SERVER['REQUEST_METHOD']??'GET';
    if(!in_array($method,['GET','POST'],true)){header('Allow: GET, POST');support_reply(405,['success'=>false,'message'=>'Method not allowed']);}
    require_once __DIR__.'/../../db.php';
    require_once __DIR__.'/../../premium_access.php';
    require_once __DIR__.'/../../support_common.php';
    $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
    $uid=premium_bearer_user($pdo);
    if($uid===null)support_reply(401,['success'=>false,'message'=>'Login required']);
    if($method==='GET'){
        if(isset($_GET['ticket_id'])){
            $id=support_id($_GET['ticket_id']);
            $q=$pdo->prepare('SELECT id,subject,plan_code,status,created_at,updated_at FROM support_tickets WHERE id=? AND user_id=? AND NOT EXISTS (SELECT 1 FROM support_user_hidden_tickets h WHERE h.ticket_id=support_tickets.id)');$q->execute([$id,$uid]);$ticket=$q->fetch(PDO::FETCH_ASSOC);
            if(!$ticket)support_reply(404,['success'=>false,'message'=>'Ticket not found']);
            $ticket['id']=(string)$ticket['id'];
            $before=isset($_GET['before_id'])?support_id($_GET['before_id']):null;
            support_reply(200,['success'=>true,'ticket'=>$ticket,...support_thread($pdo,$id,$before,true)]);
        }
        $page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]]);
        if($page===false)throw new DomainException('Invalid page');
        $offset=($page-1)*25;
        $q=$pdo->prepare("SELECT t.id,t.subject,t.plan_code,t.status,t.updated_at,
        (SELECT m.body FROM support_messages m WHERE m.ticket_id=t.id AND NOT EXISTS (SELECT 1 FROM support_user_hidden_messages h WHERE h.message_id=m.id) ORDER BY m.id DESC LIMIT 1) AS last_message
        FROM support_tickets t WHERE t.user_id=? AND NOT EXISTS (SELECT 1 FROM support_user_hidden_tickets h WHERE h.ticket_id=t.id) ORDER BY t.updated_at DESC,t.id DESC LIMIT 26 OFFSET $offset");$q->execute([$uid]);$rows=$q->fetchAll(PDO::FETCH_ASSOC);
        $more=count($rows)>25;if($more)array_pop($rows);
        foreach($rows as &$row)$row['id']=(string)$row['id'];unset($row);
        support_reply(200,['success'=>true,'data'=>$rows,'has_more'=>$more]);
    }
    $raw=file_get_contents('php://input',false,null,0,16385);
    if($raw===false||strlen($raw)>16384)support_reply(413,['success'=>false,'message'=>'Request too large']);
    $data=json_decode($raw,true);if(!is_array($data)||array_is_list($data))throw new DomainException('Invalid request');
    $action=$data['action']??'';
    if(!in_array($action,['create','reply','hide_message','hide_thread'],true))throw new DomainException('Invalid action');
    $body=in_array($action,['create','reply'],true)?support_text($data['message']??null,2000):null;
    $pdo->beginTransaction();
    // Serialize per-user writes so parallel requests cannot evade the rate limit.
    $q=$pdo->prepare('SELECT id FROM users WHERE id=? AND is_registered=1 FOR UPDATE');$q->execute([$uid]);if(!$q->fetchColumn())throw new DomainException('Login required');
    if(in_array($action,['hide_message','hide_thread'],true)){
        $id=support_id($data['ticket_id']??null);
        $q=$pdo->prepare('SELECT id FROM support_tickets WHERE id=? AND user_id=? FOR UPDATE');
        $q->execute([$id,$uid]);
        if(!$q->fetchColumn()){$pdo->rollBack();support_reply(404,['success'=>false,'message'=>'Ticket not found']);}
        if($action==='hide_thread'){
            $q=$pdo->prepare('INSERT INTO support_user_hidden_tickets(ticket_id) VALUES (?) ON DUPLICATE KEY UPDATE ticket_id=VALUES(ticket_id)');
            $q->execute([$id]);
        }else{
            $mid=support_id($data['message_id']??null);
            $q=$pdo->prepare('SELECT id FROM support_messages WHERE id=? AND ticket_id=?');
            $q->execute([$mid,$id]);
            if(!$q->fetchColumn()){$pdo->rollBack();support_reply(404,['success'=>false,'message'=>'Message not found']);}
            $q=$pdo->prepare('INSERT INTO support_user_hidden_messages(message_id) VALUES (?) ON DUPLICATE KEY UPDATE message_id=VALUES(message_id)');
            $q->execute([$mid]);
        }
        $pdo->commit();support_reply(200,['success'=>true]);
    }
    $q=$pdo->prepare("SELECT COUNT(*) FROM support_messages m JOIN support_tickets t ON t.id=m.ticket_id WHERE t.user_id=? AND m.sender='user' AND m.created_at>=UTC_TIMESTAMP()-INTERVAL 1 DAY");$q->execute([$uid]);
    if((int)$q->fetchColumn()>=30){$pdo->rollBack();support_reply(429,['success'=>false,'message'=>'দৈনিক মেসেজ সীমা শেষ হয়েছে।']);}
    if($action==='create'){
        $subject=support_text($data['subject']??null,160);
        $plan=$data['plan_code']??'none';if(!in_array($plan,['none','monthly','quarterly','annual'],true))throw new DomainException('Invalid plan');
        $q=$pdo->prepare('SELECT COUNT(*) FROM support_tickets WHERE user_id=? AND created_at>=UTC_TIMESTAMP()-INTERVAL 1 DAY');$q->execute([$uid]);
        if((int)$q->fetchColumn()>=5){$pdo->rollBack();support_reply(429,['success'=>false,'message'=>'দৈনিক টিকিট সীমা শেষ হয়েছে।']);}
        $q=$pdo->prepare("INSERT INTO support_tickets(user_id,plan_code,subject,status,created_at,updated_at) VALUES (?,?,?,'open',UTC_TIMESTAMP(),UTC_TIMESTAMP())");$q->execute([$uid,$plan,$subject]);$id=(int)$pdo->lastInsertId();
    }else{
        $id=support_id($data['ticket_id']??null);
        $q=$pdo->prepare('SELECT status FROM support_tickets WHERE id=? AND user_id=? AND NOT EXISTS (SELECT 1 FROM support_user_hidden_tickets h WHERE h.ticket_id=support_tickets.id) FOR UPDATE');$q->execute([$id,$uid]);$status=$q->fetchColumn();
        if($status===false){$pdo->rollBack();support_reply(404,['success'=>false,'message'=>'Ticket not found']);}
        if($status==='closed'){$pdo->rollBack();support_reply(409,['success'=>false,'message'=>'এই কথোপকথন বন্ধ হয়েছে।']);}
    }
    support_add($pdo,$id,'user',$body);$pdo->commit();
    support_reply(200,['success'=>true,'ticket_id'=>(string)$id]);
}catch(DomainException $e){if(isset($pdo)&&$pdo->inTransaction())$pdo->rollBack();support_reply(422,['success'=>false,'message'=>$e->getMessage()]);}
catch(Throwable $e){if(isset($pdo)&&$pdo instanceof PDO&&$pdo->inTransaction())$pdo->rollBack();error_log('Support API: '.$e->getMessage());support_reply(503,['success'=>false,'message'=>'Support temporarily unavailable']);}
