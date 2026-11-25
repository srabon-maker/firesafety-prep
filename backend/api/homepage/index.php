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
        $rows=$pdo->query("SELECT category,COUNT(*) AS question_count FROM questions WHERE status='published' AND correct_answer IN ('A','B','C','D') AND category IS NOT NULL AND TRIM(category)<>'' GROUP BY category ORDER BY category LIMIT 200")->fetchAll(PDO::FETCH_ASSOC);
        hp_reply(200,['success'=>true,'data'=>array_map(static fn($r)=>['category'=>$r['category'],'question_count'=>(int)$r['question_count']],$rows)]);
    }
    if ($action==='home') {
        $order=$pdo->query('SELECT section_order FROM homepage_settings WHERE id=1')->fetchColumn();
        if ($order===false) throw new RuntimeException('Homepage settings missing');
        $allowed=['banners','progress','jobs','topics','notes','marketplace','community','tips'];
        $sections=array_values(array_unique(array_intersect(explode(',',$order),$allowed)));
        $items=[];
        foreach (['banner'=>8,'tip'=>5] as $kind=>$limit) {
            $q=$pdo->prepare("SELECT id,title,body,title_en,body_en,target,image_url FROM homepage_content WHERE kind=? AND is_published=1 ORDER BY sort_order,id DESC LIMIT $limit");
            $q->execute([$kind]);
            $items[$kind]=$q->fetchAll(PDO::FETCH_ASSOC);
        }
        hp_reply(200,['success'=>true,'sections'=>$sections,'banners'=>$items['banner'],'tips'=>$items['tip']]);
    }
    if ($action==='interviews') {
        $page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]]);
        $search=$_GET['search']??''; $role=$_GET['role']??''; $industry=$_GET['industry']??'';
        if ($page===false || !is_string($search)||!is_string($role)||!is_string($industry)||strlen($search)>600||strlen($role)>400||strlen($industry)>400) hp_reply(422,['success'=>false,'message'=>'Invalid filter']);
        $where="kind='interview' AND is_published=1"; $args=[];
        if ($role!=='') {$where.=' AND role_name=?'; $args[]=$role;}
        if ($industry!=='') {$where.=' AND industry=?'; $args[]=$industry;}
        if (trim($search)!=='') {
            $where.=" AND (LOCATE(?,title)>0 OR LOCATE(?,title_en)>0 OR LOCATE(?,body)>0 OR LOCATE(?,body_en)>0 OR LOCATE(?,role_name)>0 OR LOCATE(?,industry)>0)";
            for($i=0;$i<6;$i++) $args[]=trim($search);
        }
        $offset=($page-1)*25;
        $q=$pdo->prepare("SELECT id,title,body,title_en,body_en,role_name,industry,difficulty FROM homepage_content WHERE $where ORDER BY sort_order,id DESC LIMIT 26 OFFSET $offset");
        $q->execute($args); $rows=$q->fetchAll(PDO::FETCH_ASSOC);
        $more=count($rows)>25; if ($more) array_pop($rows);
        $roles=$pdo->query("SELECT DISTINCT role_name FROM homepage_content WHERE kind='interview' AND is_published=1 AND role_name<>'' ORDER BY role_name LIMIT 200")->fetchAll(PDO::FETCH_COLUMN);
        $industries=$pdo->query("SELECT DISTINCT industry FROM homepage_content WHERE kind='interview' AND is_published=1 AND industry<>'' ORDER BY industry LIMIT 200")->fetchAll(PDO::FETCH_COLUMN);
        hp_reply(200,['success'=>true,'data'=>$rows,'roles'=>$roles,'industries'=>$industries,'has_more'=>$more]);
    }
    hp_reply(404,['success'=>false,'message'=>'Unknown action']);
} catch(Throwable $e) {
    error_log('Homepage API: '.$e->getMessage());
    hp_reply(503,['success'=>false,'message'=>'Content temporarily unavailable']);
}
