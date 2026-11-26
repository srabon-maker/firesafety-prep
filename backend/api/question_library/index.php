<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
function ql_reply(int $code,array $payload): never {
    http_response_code($code);
    echo json_encode($payload,JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function ql_user(PDO $pdo): int {
    $header=$_SERVER['HTTP_AUTHORIZATION']??$_SERVER['REDIRECT_HTTP_AUTHORIZATION']??'';
    if (!$header && function_exists('getallheaders')) {
        foreach(getallheaders() as $k=>$v) if(strcasecmp($k,'Authorization')===0){$header=$v;break;}
    }
    if (!is_string($header)||!preg_match('/^Bearer ([a-f0-9]{64})$/iD',trim($header),$m)) ql_reply(401,['success'=>false,'message'=>'Login required']);
    $q=$pdo->prepare('SELECT s.user_id FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>NOW() AND u.is_registered=1 LIMIT 1');
    $q->execute([hash('sha256',$m[1])]);$id=$q->fetchColumn();
    if(!$id) ql_reply(401,['success'=>false,'message'=>'Login required']);
    return (int)$id;
}
function ql_text(string $key,int $limit): string {
    $v=$_GET[$key]??'';
    if(!is_string($v)||!preg_match('//u',$v)||strlen($v)>$limit) ql_reply(422,['success'=>false,'message'=>'Invalid filter']);
    return trim($v);
}
function ql_id(mixed $v): int {
    $id=filter_var($v,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if($id===false) ql_reply(422,['success'=>false,'message'=>'Invalid ID']);
    return $id;
}
try {
    $method=$_SERVER['REQUEST_METHOD']??'GET';
    if(!in_array($method,['GET','POST'],true)){header('Allow: GET, POST');ql_reply(405,['success'=>false,'message'=>'Method not allowed']);}
    require_once __DIR__.'/../../db.php';
    $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
    require_once __DIR__.'/../../premium_learning.php';
    require_once __DIR__.'/../../category_labels.php';
    $uid=ql_user($pdo);
    $active=premium_active($pdo,$uid)!==null;
    $mode=premium_policy($pdo)['effective_mode'];
    $marked=premium_effective_question($mode);
    $locked=$active?'0':$marked;
    $eligible="q.status='published' AND q.is_archived=0 AND q.correct_answer IN ('A','B','C','D')";
    if($method==='POST'){
        if(!$active)$eligible.=" AND NOT ($marked)";
        $raw=file_get_contents('php://input',false,null,0,4097);
        if($raw===false||strlen($raw)>4096) ql_reply(413,['success'=>false,'message'=>'Request too large']);
        $data=json_decode($raw,true);
        if(!is_array($data)||($data['action']??'')!=='bookmark'||!is_bool($data['saved']??null)) ql_reply(422,['success'=>false,'message'=>'Invalid request']);
        $id=ql_id($data['id']??null);
        if($data['saved']){
            $q=$pdo->prepare("INSERT INTO student_question_bookmarks(user_id,question_id) SELECT ?,q.id FROM questions q WHERE q.id=? AND $eligible ON DUPLICATE KEY UPDATE question_id=VALUES(question_id)");
            $q->execute([$uid,$id]);
            $check=$pdo->prepare("SELECT 1 FROM student_question_bookmarks b JOIN questions q ON q.id=b.question_id WHERE b.user_id=? AND b.question_id=? AND $eligible");
            $check->execute([$uid,$id]);
            if(!$check->fetchColumn()) ql_reply(404,['success'=>false,'message'=>'Question unavailable']);
        }else{
            $q=$pdo->prepare('DELETE FROM student_question_bookmarks WHERE user_id=? AND question_id=?');
            $q->execute([$uid,$id]);
        }
        ql_reply(200,['success'=>true,'saved'=>$data['saved']]);
    }
    $search=ql_text('search',480);$category=ql_text('category',400);
    $difficulty=ql_text('difficulty',20); if($difficulty==='')$difficulty='all';
    if(!in_array($difficulty,['all','easy','medium','hard'],true)) ql_reply(422,['success'=>false,'message'=>'Invalid difficulty']);
    $saved=ql_text('saved',1);
    if(!in_array($saved,['','0','1'],true)) ql_reply(422,['success'=>false,'message'=>'Invalid bookmark filter']);
    $page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]]);
    if($page===false) ql_reply(422,['success'=>false,'message'=>'Invalid page']);
    $related=isset($_GET['note_id']);
    $matched=true;
    if($related){
        $noteId=ql_id($_GET['note_id']);
        $noteScope=$active?'':' AND NOT ('.premium_effective_note($mode).')';
        $n=$pdo->prepare("SELECT c.name FROM notes n JOIN categories c ON c.id=n.category_id AND c.category_type='note' WHERE n.id=? AND n.status='published' $noteScope");
        $n->execute([$noteId]);$name=$n->fetchColumn();
        $category=is_string($name)?trim($name):'';
        $matched=$category!=='';
        if($matched){
            $n=$pdo->prepare("SELECT 1 FROM questions q WHERE $eligible AND q.category=? LIMIT 1");
            $n->execute([$category]);$matched=(bool)$n->fetchColumn();
        }
        if(!$matched) ql_reply(200,['success'=>true,'data'=>[],'has_more'=>false,'related_match'=>false,'category'=>$category]);
    }
    $where=$eligible;$args=[$uid];
    if(!$active&&($_GET['premium_preview']??'')!=='1')$where.=" AND NOT ($marked)";
    if($category!==''){$where.=' AND q.category=?';$args[]=$category;}
    if($difficulty!=='all'){$where.=' AND q.difficulty=?';$args[]=$difficulty;}
    if($search!==''){
        $names=category_label_matches($pdo,'question',$search);
        $extra=$names?' OR q.category IN ('.implode(',',array_fill(0,count($names),'?')).')':'';
        $where.=' AND (LOCATE(?,q.question)>0 OR LOCATE(?,q.category)>0 OR (NOT ('.$locked.') AND (LOCATE(?,COALESCE(q.explanation,\'\'))>0 OR LOCATE(?,COALESCE(q.reference,\'\'))>0))'.$extra.')';
        array_push($args,$search,$search,$search,$search,...$names);
    }
    if($saved==='1')$where.=' AND b.question_id IS NOT NULL';
    $offset=($page-1)*20;
    $q=$pdo->prepare("SELECT q.id,q.category,q.question,CASE WHEN $locked THEN NULL ELSE q.option_a END AS option_a,CASE WHEN $locked THEN NULL ELSE q.option_b END AS option_b,CASE WHEN $locked THEN NULL ELSE q.option_c END AS option_c,CASE WHEN $locked THEN NULL ELSE q.option_d END AS option_d,CASE WHEN $locked THEN NULL ELSE q.correct_answer END AS correct_answer,CASE WHEN $locked THEN NULL ELSE q.explanation END AS explanation,q.difficulty,CASE WHEN $locked THEN NULL ELSE q.reference END AS reference,q.language,$marked AS premium_only,$locked AS locked,(b.question_id IS NOT NULL) AS saved
        FROM questions q LEFT JOIN student_question_bookmarks b ON b.question_id=q.id AND b.user_id=?
        WHERE $where ORDER BY q.id DESC LIMIT 21 OFFSET $offset");
    $q->execute($args);$rows=$q->fetchAll(PDO::FETCH_ASSOC);
    $more=count($rows)>20;if($more)array_pop($rows);
    foreach($rows as &$row){
        $row+=category_label_for($pdo,'question',(string)$row['category']);
        $row['id']=(string)$row['id'];$row['saved']=(bool)$row['saved'];$row['premium_only']=(bool)$row['premium_only'];$row['locked']=(bool)$row['locked'];
        $row['options']=['A'=>$row['option_a'],'B'=>$row['option_b'],'C'=>$row['option_c'],'D'=>$row['option_d']];
        unset($row['option_a'],$row['option_b'],$row['option_c'],$row['option_d']);
    }unset($row);
    ql_reply(200,['success'=>true,'data'=>$rows,'has_more'=>$more,'related_match'=>$matched,'category'=>$category]+category_label_for($pdo,'question',$category));
}catch(Throwable $e){
    error_log('Question library: '.$e->getMessage());
    ql_reply(503,['success'=>false,'message'=>'Question library temporarily unavailable']);
}
