<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function hp_reply(int $status,array $data): never {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
try {
    if (($_SERVER['REQUEST_METHOD']??'GET')!=='GET') {header('Allow: GET'); hp_reply(405,['success'=>false,'message'=>'GET required']);}
    require_once __DIR__.'/../../db.php';
    $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
    $action=$_GET['action']??'home';
    if ($action==='question_categories') {
        require_once __DIR__.'/../../premium_learning.php';
        $mode=premium_policy($pdo)['effective_mode'];
        $hasAccess=premium_has_access($pdo);$locked=$hasAccess?'0':premium_effective_question($mode);
        $scope=($_GET['premium_preview']??'')==='1'?'':' AND NOT ('.$locked.')';
        $rows=$pdo->query("SELECT category,COUNT(*) AS question_count,SUM(CASE WHEN $locked THEN 1 ELSE 0 END) AS locked_count FROM questions q WHERE status='published' AND q.is_archived=0 AND correct_answer IN ('A','B','C','D') AND category IS NOT NULL AND TRIM(category)<>'' $scope GROUP BY category ORDER BY category LIMIT 200")->fetchAll(PDO::FETCH_ASSOC);
        hp_reply(200,['success'=>true,'data'=>array_map(static fn($r)=>['category'=>$r['category'],'question_count'=>(int)$r['question_count'],'locked_count'=>(int)$r['locked_count']],$rows)]);
    }
    if ($action==='home') {
        $order=$pdo->query('SELECT section_order FROM homepage_settings WHERE id=1')->fetchColumn();
        if ($order===false) throw new RuntimeException('Homepage settings missing');
        require_once __DIR__.'/../../homepage_sections.php';
        $sections=hp_section_order((string)$order);
        $items=[];
        foreach (['banner'=>8,'tip'=>5] as $kind=>$limit) {
            $q=$pdo->prepare("SELECT id,title,body,title_en,body_en,target,image_url FROM homepage_content WHERE kind=? AND is_published=1 ORDER BY sort_order,id DESC LIMIT $limit");
            $q->execute([$kind]);
            $items[$kind]=$q->fetchAll(PDO::FETCH_ASSOC);
        }
        require_once __DIR__.'/../../premium_learning.php';
        hp_reply(200,['success'=>true,'sections'=>$sections,'career_layout'=>true,'banners'=>$items['banner'],'tips'=>$items['tip'],'access_policy'=>premium_policy_public(premium_policy($pdo))]);
    }
    if ($action==='interviews') {
        $page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]]);
        $search=$_GET['search']??''; $role=$_GET['role']??''; $industry=$_GET['industry']??'';
        if ($page===false || !is_string($search)||!is_string($role)||!is_string($industry)||strlen($search)>600||strlen($role)>400||strlen($industry)>400) hp_reply(422,['success'=>false,'message'=>'Invalid filter']);
        require_once __DIR__.'/../../premium_learning.php';
        $active=premium_active($pdo,premium_bearer_user($pdo))!==null;
        $preview=($_GET['premium_preview']??'')==='1';
        $marked=premium_effective_interview(premium_policy($pdo)['effective_mode']);
        $locked=$active?'0':$marked;
        $base="kind='interview' AND is_published=1";
        // Legacy clients only receive free or entitled rows. Preview clients receive titles, never locked answers.
        if(!$active&&!$preview)$base.=" AND NOT ($marked)";
        $where=$base;$args=[];
        if($role!==''){$where.=' AND role_name=?';$args[]=$role;}
        if($industry!==''){$where.=' AND industry=?';$args[]=$industry;}
        if(trim($search)!==''){
            $term=trim($search);
            $where.=" AND (LOCATE(?,title)>0 OR LOCATE(?,title_en)>0 OR LOCATE(?,role_name)>0 OR LOCATE(?,industry)>0 OR (NOT ($locked) AND (LOCATE(?,body)>0 OR LOCATE(?,body_en)>0)))";
            for($i=0;$i<6;$i++)$args[]=$term;
        }
        $offset=($page-1)*25;
        $q=$pdo->prepare("SELECT id,title,CASE WHEN $locked THEN '' ELSE body END AS body,title_en,CASE WHEN $locked THEN '' ELSE body_en END AS body_en,role_name,industry,difficulty,$marked AS premium_only,$locked AS locked FROM homepage_content WHERE $where ORDER BY sort_order,id DESC LIMIT 26 OFFSET $offset");
        $q->execute($args);$rows=$q->fetchAll(PDO::FETCH_ASSOC);
        $more=count($rows)>25;if($more)array_pop($rows);
        foreach($rows as &$row){$row['premium_only']=(bool)$row['premium_only'];$row['locked']=(bool)$row['locked'];}unset($row);
        $roles=$pdo->query("SELECT DISTINCT role_name FROM homepage_content WHERE $base AND role_name<>'' ORDER BY role_name LIMIT 200")->fetchAll(PDO::FETCH_COLUMN);
        $industries=$pdo->query("SELECT DISTINCT industry FROM homepage_content WHERE $base AND industry<>'' ORDER BY industry LIMIT 200")->fetchAll(PDO::FETCH_COLUMN);
        hp_reply(200,['success'=>true,'data'=>$rows,'roles'=>$roles,'industries'=>$industries,'has_more'=>$more]);
    }
    hp_reply(404,['success'=>false,'message'=>'Unknown action']);
} catch(Throwable $e) {
    error_log('Homepage API: '.$e->getMessage());
    hp_reply(503,['success'=>false,'message'=>'Content temporarily unavailable']);
}
