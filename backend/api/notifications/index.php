<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
function inbox_reply(int $code,array $body): never {
    http_response_code($code);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function inbox_id(mixed $value): int {
    if ((!is_int($value) && !is_string($value)) || !preg_match('/^[1-9][0-9]*$/D',(string)$value)) inbox_reply(422,['success'=>false,'message'=>'Invalid ID']);
    $id=filter_var($value,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if ($id===false) inbox_reply(422,['success'=>false,'message'=>'Invalid ID']);
    return $id;
}
try {
    $method=$_SERVER['REQUEST_METHOD']??'GET';
    if (!in_array($method,['GET','POST'],true)) { header('Allow: GET, POST'); inbox_reply(405,['success'=>false,'message'=>'GET or POST required']); }
    $auth=$_SERVER['HTTP_AUTHORIZATION']??$_SERVER['REDIRECT_HTTP_AUTHORIZATION']??'';
    if (!$auth && function_exists('getallheaders')) foreach(getallheaders() as $k=>$v) if (strcasecmp($k,'Authorization')===0) $auth=$v;
    if (!is_string($auth)||!preg_match('/^Bearer\s+([a-f0-9]{64})$/i',trim($auth),$m)) inbox_reply(401,['success'=>false,'message'=>'Login required']);
    require_once __DIR__.'/../../db.php';
    $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
    $q=$pdo->prepare('SELECT u.id FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>NOW() AND u.is_registered=1 LIMIT 1');
    $q->execute([hash('sha256',$m[1])]);
    $uid=$q->fetchColumn();
    if ($uid===false) inbox_reply(401,['success'=>false,'message'=>'Session expired']);
    // Only published notifications belonging to the bearer account are visible.
    $scope='user_id=? AND sent_at IS NOT NULL AND sent_at<=NOW()';
    if ($method==='GET') {
        $before=isset($_GET['before_id'])?inbox_id($_GET['before_id']):null;
        $args=[$uid]; $where=$scope;
        if ($before!==null) {$where.=' AND id<?';$args[]=$before;}
        $q=$pdo->prepare("SELECT id,title,message,notification_type,is_read,sent_at FROM notifications WHERE $where ORDER BY id DESC LIMIT 26");
        $q->execute($args);
        $rows=$q->fetchAll(PDO::FETCH_ASSOC);
        $more=count($rows)>25;
        if ($more) array_pop($rows);
        $items=array_map(static fn($row)=>[
            'id'=>(string)$row['id'],'title'=>$row['title'],'message'=>$row['message'],
            'notification_type'=>$row['notification_type'],'is_read'=>(bool)$row['is_read'],
            'sent_at'=>$row['sent_at'],
        ],$rows);
        $q=$pdo->prepare("SELECT COUNT(*) FROM notifications WHERE $scope AND is_read=0");
        $q->execute([$uid]);
        inbox_reply(200,['success'=>true,'data'=>$items,'unread_count'=>(int)$q->fetchColumn(),'next_before_id'=>$more?$items[count($items)-1]['id']:null]);
    }
    $raw=file_get_contents('php://input',false,null,0,8193);
    if ($raw===false||strlen($raw)>8192) inbox_reply(413,['success'=>false,'message'=>'Request too large']);
    $body=json_decode($raw,true);
    if (!is_array($body)||array_is_list($body)) inbox_reply(400,['success'=>false,'message'=>'JSON object required']);
    $action=$body['action']??null;
    if ($action==='mark_read') {
        $id=inbox_id($body['id']??null);
        $q=$pdo->prepare("UPDATE notifications SET is_read=1 WHERE $scope AND id=? AND is_read=0");
        $q->execute([$uid,$id]);
        if (!$q->rowCount()) {
            $q=$pdo->prepare("SELECT id FROM notifications WHERE $scope AND id=?");
            $q->execute([$uid,$id]);
            if ($q->fetchColumn()===false) inbox_reply(404,['success'=>false,'message'=>'Notification not found']);
        }
    } elseif ($action==='mark_all_read') {
        // Client supplies its newest seen ID; later arrivals stay unread.
        $through=inbox_id($body['through_id']??null);
        $q=$pdo->prepare("SELECT id FROM notifications WHERE $scope AND id=?");
        $q->execute([$uid,$through]);
        if ($q->fetchColumn()===false) inbox_reply(404,['success'=>false,'message'=>'Notification not found']);
        $q=$pdo->prepare("UPDATE notifications SET is_read=1 WHERE $scope AND id<=? AND is_read=0");
        $q->execute([$uid,$through]);
    } else inbox_reply(422,['success'=>false,'message'=>'Unknown action']);
    $q=$pdo->prepare("SELECT COUNT(*) FROM notifications WHERE $scope AND is_read=0");
    $q->execute([$uid]);
    inbox_reply(200,['success'=>true,'unread_count'=>(int)$q->fetchColumn()]);
} catch(Throwable $e) {
    error_log('Notification inbox: '.$e->getMessage());
    inbox_reply(500,['success'=>false,'message'=>'Notification service unavailable']);
}
