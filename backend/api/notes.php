<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

function notes_api_public_url(?string $url): ?string {
    $url = trim((string)$url);
    if ($url === '') return null;
    if (filter_var($url, FILTER_VALIDATE_URL)) {
        $scheme = strtolower((string)parse_url($url, PHP_URL_SCHEME));
        return in_array($scheme, ['http', 'https'], true) ? $url : null;
    }
    if (preg_match('~^/?uploads/notes/(?:files|images)/[a-f0-9]{32}\\.(?:pdf|doc|docx|jpg|jpeg|png|webp|gif)$~i', $url)) {
        return 'https://fire.manobikishwarganj.com/' . ltrim($url, '/');
    }
    return null;
}

function notes_api_content_urls(?string $html): ?string {
    if ($html === null || $html === '') return $html;
    return preg_replace_callback(
        "~((?:src|href)\\s*=\\s*)([\"'])(/?uploads/notes/(?:files|images)/[a-f0-9]{32}\\.(?:pdf|doc|docx|jpg|jpeg|png|webp|gif))\\2~i",
        static function (array $match): string {
            return $match[1] . $match[2] . 'https://fire.manobikishwarganj.com/' . ltrim($match[3], '/') . $match[2];
        },
        $html
    );
}

function notes_api_reply(int $status, array $body): never {
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
    header('Allow: GET');
    notes_api_reply(405, ['success'=>false, 'message'=>'শুধু GET request গ্রহণযোগ্য।']);
}
try {
    require_once __DIR__ . '/../db.php';
    if (!isset($pdo) || !$pdo instanceof PDO) throw new RuntimeException('Database unavailable.');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    require_once __DIR__.'/../premium_learning.php';
    $active=premium_has_access($pdo);
    $marked=premium_note_marked();
    $locked=$active?'0':$marked;
    $preview=($_GET['premium_preview']??'')==='1';
    $action = (string)($_GET['action'] ?? 'list');
    $select = "SELECT n.id,n.category_id,n.title,CASE WHEN $locked THEN NULL ELSE n.summary END AS summary,CASE WHEN $locked THEN NULL ELSE n.content END AS content,CASE WHEN $locked THEN NULL ELSE n.file_url END AS file_url,CASE WHEN $locked THEN 'none' ELSE n.file_type END AS file_type,$marked AS premium_only,$locked AS locked,
        DATE_FORMAT(n.published_at,'%Y-%m-%d %H:%i:%s') AS published_at,
        c.name AS category_name
        FROM notes n LEFT JOIN categories c ON c.id=n.category_id AND c.category_type='note'";
    if ($action === 'detail') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT, ['options'=>['min_range'=>1]]);
        if ($id === false) notes_api_reply(422,['success'=>false,'message'=>'সঠিক Note ID দিন।']);
        $stmt=$pdo->prepare($select." WHERE n.id=? AND n.status='published' LIMIT 1");
        $stmt->execute([(int)$id]);
        $note=$stmt->fetch(PDO::FETCH_ASSOC);
        if (!$note) notes_api_reply(404,['success'=>false,'message'=>'প্রকাশিত নোটটি পাওয়া যায়নি।']);
        if(!$preview&&!$active&&!empty($note['locked']))notes_api_reply(403,['success'=>false,'message'=>'এই নোটটি Premium সদস্যদের জন্য।']);
        $note['locked']=(bool)$note['locked'];$note['premium_only']=(bool)$note['premium_only'];
        $note['id']=(int)$note['id'];
        $note['category_id']=$note['category_id']===null?null:(int)$note['category_id'];
        $note['file_url'] = notes_api_public_url(is_string($note['file_url']) ? $note['file_url'] : null);
        $note['content'] = notes_api_content_urls(is_string($note['content']) ? $note['content'] : null);
        notes_api_reply(200,['success'=>true,'data'=>$note]);
    }
    if ($action !== 'list') notes_api_reply(404,['success'=>false,'message'=>'অনুরোধটি পাওয়া যায়নি।']);
    $search=trim((string)($_GET['search']??''));
    $search=function_exists('mb_substr')?mb_substr($search,0,100,'UTF-8'):substr($search,0,100);
    $categoryId=filter_var($_GET['category']??null,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    $page=max(1,min(100000,(int)($_GET['page']??1)));
    $perPage=20;
    $where=["n.status='published'"];
    if(!$active&&!$preview)$where[]="NOT ($marked)";
    $params=[];
    if($search!==''){$where[]="(n.title LIKE ? OR (NOT ($locked) AND (n.summary LIKE ? OR n.content LIKE ?)))";$term='%'.$search.'%';array_push($params,$term,$term,$term);}
    if($categoryId!==false){$where[]='n.category_id=?';$params[]=(int)$categoryId;}
    $whereSql=' WHERE '.implode(' AND ',$where);
    $count=$pdo->prepare('SELECT COUNT(*) FROM notes n'.$whereSql);
    $count->execute($params);
    $total=(int)$count->fetchColumn();
    $totalPages=max(1,(int)ceil($total/$perPage));
    $page=min($page,$totalPages);
    $offset=($page-1)*$perPage;
    $stmt=$pdo->prepare($select.$whereSql.' ORDER BY n.published_at DESC,n.id DESC LIMIT '.$perPage.' OFFSET '.$offset);
    $stmt->execute($params);
    $rows=$stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach($rows as &$row){
        $row['locked']=(bool)$row['locked'];$row['premium_only']=(bool)$row['premium_only'];
        $row['id']=(int)$row['id'];
        $row['category_id']=$row['category_id']===null?null:(int)$row['category_id'];
        $row['file_url'] = notes_api_public_url(is_string($row['file_url']) ? $row['file_url'] : null);
        $row['content'] = notes_api_content_urls(is_string($row['content']) ? $row['content'] : null);
    }
    unset($row);
    $categoryStmt=$pdo->query("SELECT id,name FROM categories WHERE category_type='note' AND is_active=1 ORDER BY sort_order ASC,name ASC");
    $categories=$categoryStmt->fetchAll(PDO::FETCH_ASSOC);
    foreach($categories as &$category)$category['id']=(int)$category['id'];
    unset($category);
    notes_api_reply(200,['success'=>true,'data'=>$rows,'categories'=>$categories,'pagination'=>['page'=>$page,'per_page'=>$perPage,'total'=>$total,'total_pages'=>$totalPages]]);
} catch(Throwable $error) {
    error_log('Notes API failed: '.$error->getMessage());
    header('Cache-Control: no-store');
    notes_api_reply(500,['success'=>false,'message'=>'নোট লোড করা যাচ্ছে না। পরে আবার চেষ্টা করুন।']);
}
