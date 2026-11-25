<?php
declare(strict_types=1);
require_once __DIR__ . '/admin_helpers.php';
require_admin();
require_once __DIR__ . '/db.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$tabs = ['analytics'=>'অ্যানালিটিক্স','notifications'=>'নোটিফিকেশন','settings'=>'সেটিংস'];
$tab = is_string($_GET['tab'] ?? null) && isset($tabs[$_GET['tab']]) ? $_GET['tab'] : 'analytics';
$types = ['general'=>'সাধারণ','study'=>'পড়াশোনা','app_update'=>'অ্যাপ আপডেট','community'=>'কমিউনিটি','marketplace'=>'মার্কেটপ্লেস'];
$audiences = ['single'=>'একজন নিবন্ধিত ব্যবহারকারী','all'=>'সব নিবন্ধিত ব্যবহারকারী','Employed'=>'চাকরিজীবী','Job Seeker'=>'চাকরিপ্রার্থী','Student'=>'শিক্ষার্থী','Other'=>'অন্যান্য'];
$statusLabels = ['pending'=>'অপেক্ষমাণ','confirmed'=>'নিশ্চিত','processing'=>'প্রক্রিয়াধীন','shipped'=>'পাঠানো হয়েছে','delivered'=>'সরবরাহ সম্পন্ন','cancelled'=>'বাতিল','approved'=>'অনুমোদিত','rejected'=>'প্রত্যাখ্যাত','hidden'=>'লুকানো','reviewing'=>'পর্যালোচনাধীন','completed'=>'সম্পন্ন','Employed'=>'চাকরিজীবী','Job Seeker'=>'চাকরিপ্রার্থী','Student'=>'শিক্ষার্থী','Other'=>'অন্যান্য'];
function ao_text(string $key, int $max): string {
    $v = $_POST[$key] ?? '';
    if (!is_string($v)) throw new DomainException('লেখা সঠিক নয়।');
    $v = trim($v);
    if ($v === '' || (function_exists('mb_strlen') ? mb_strlen($v,'UTF-8') : strlen($v)) > $max) throw new DomainException('লেখা দেওয়া হয়নি অথবা নির্ধারিত সীমার চেয়ে বড়।');
    return $v;
}
function ao_integer(string $key,int $min,int $max): int {
    $v = filter_var($_POST[$key] ?? null,FILTER_VALIDATE_INT,['options'=>['min_range'=>$min,'max_range'=>$max]]);
    if ($v === false) throw new DomainException('সংখ্যা সঠিক নয়।');
    return $v;
}
function ao_settings(PDO $pdo,bool $lock=false): array {
    $s=$pdo->query('SELECT * FROM admin_operation_settings WHERE id=1'.($lock?' FOR UPDATE':''))->fetch(PDO::FETCH_ASSOC);
    if (!$s) throw new RuntimeException('Settings migration required');
    return $s;
}
function ao_redirect(string $tab,string $message): never {
    $_SESSION['admin_ops_flash']=$message;
    header('Location: admin_operations.php?tab='.$tab, true,303);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    verify_csrf();
    $action = $_POST['action'] ?? '';
    try {
        if ($action === 'save_settings') {
            $enabled = ($_POST['broadcast_enabled'] ?? '') === '1' ? 1 : 0;
            $limit = ao_integer('broadcast_limit',1,5000);
            $days = ao_integer('analytics_days',7,90);
            if (!in_array($days,[7,30,90],true)) throw new DomainException('৭, ৩০ অথবা ৯০ দিন নির্বাচন করুন।');
            $pdo->beginTransaction();
            ao_settings($pdo,true);
            $q=$pdo->prepare('UPDATE admin_operation_settings SET broadcast_enabled=?,broadcast_limit=?,analytics_days=? WHERE id=1');
            $q->execute([$enabled,$limit,$days]);
            $pdo->commit();
            ao_redirect('settings','সেটিংস সংরক্ষণ করা হয়েছে।');
        }
        if ($action !== 'publish') throw new DomainException('অনুরোধটি সঠিক নয়।');
        $title=ao_text('title',200); $message=ao_text('message',2000);
        $type=ao_text('notification_type',60); $audience=ao_text('audience',40);
        if (!isset($types[$type],$audiences[$audience])) throw new DomainException('প্রাপক বা ক্যাটাগরি সঠিক নয়।');
        if (($_POST['confirm_publish'] ?? '') !== '1') throw new DomainException('প্রথমে প্রকাশের অনুমোদন দিন।');
        $request=ao_text('request_key',64);
        if (!preg_match('/^[a-f0-9]{64}$/D',$request)) throw new DomainException('অনুরোধের শনাক্তকরণ কোড সঠিক নয়।');
        $target=$audience==='single'?ao_integer('target_user_id',1,PHP_INT_MAX):null;
        $pdo->beginTransaction();
        $s=ao_settings($pdo,true);
        $cap=$audience==='single'?1:(int)$s['broadcast_limit'];
        if ($cap<1 || $cap>5000) throw new RuntimeException('Invalid configured limit');
        if ($audience!=='single' && !(int)$s['broadcast_enabled']) throw new DomainException('সেটিংসে একাধিক ব্যবহারকারীকে নোটিফিকেশন পাঠানো বন্ধ রয়েছে।');
        $q=$pdo->prepare('SELECT id FROM admin_notification_campaigns WHERE request_key=?');
        $q->execute([$request]);
        if ($q->fetchColumn()!==false) throw new DomainException('এই নোটিফিকেশনটি আগেই প্রকাশ করা হয়েছে।');
        $q=$pdo->prepare('INSERT INTO admin_notification_campaigns(request_key,title,message,notification_type,audience,target_user_id) VALUES(?,?,?,?,?,?)');
        $q->execute([$request,$title,$message,$type,$audience,$target]);
        $campaign=(int)$pdo->lastInsertId();
        $where='is_registered=1'; $args=[$title,$message,$type,$campaign];
        if ($audience==='single') { $where.=' AND id=?'; $args[]=$target; }
        elseif ($audience!=='all') { $where.=' AND current_status=?'; $args[]=$audience; }
        // Cap+1 lets us detect over-limit audiences and roll back all rows.
        $q=$pdo->prepare("INSERT INTO notifications(user_id,title,message,notification_type,reference_type,reference_id,is_read,sent_at) SELECT id,?,?,?,'admin_campaign',?,0,CURRENT_TIMESTAMP FROM users WHERE $where ORDER BY id LIMIT ".($cap+1));
        $q->execute($args);
        $count=$q->rowCount();
        if ($count<1) throw new DomainException('নির্বাচিত কোনো নিবন্ধিত প্রাপক পাওয়া যায়নি।');
        if ($count>$cap) throw new DomainException('প্রাপকের সংখ্যা নির্ধারিত সীমা অতিক্রম করেছে। কোনো নোটিফিকেশন তৈরি হয়নি।');
        $q=$pdo->prepare('UPDATE admin_notification_campaigns SET recipient_count=? WHERE id=?');
        $q->execute([$count,$campaign]);
        $pdo->commit();
        ao_redirect('notifications',"ডাটাবেজে $count টি নোটিফিকেশন সংরক্ষিত হয়েছে। মোবাইলে পুশ নোটিফিকেশন পাঠানো হয়নি।");
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if (!($e instanceof DomainException)) error_log('Admin operations: '.$e->getMessage());
        ao_redirect($action==='save_settings'?'settings':'notifications',$e instanceof DomainException?$e->getMessage():'অনুরোধ সম্পন্ন করা যায়নি। ডাটাবেজ মাইগ্রেশন ও সার্ভার লগ পরীক্ষা করুন।');
    }
}
$flash = $_SESSION['admin_ops_flash'] ?? '';
unset($_SESSION['admin_ops_flash']);
$settings=null; $migrationError='';
try { $settings=ao_settings($pdo); } catch (Throwable $e) { $migrationError='নোটিফিকেশন প্রকাশ বা সেটিংস ব্যবহারের আগে অ্যাডমিন মাইগ্রেশন সম্পন্ন করুন।'; }
$days = filter_var($_GET['days'] ?? ($settings['analytics_days']??30),FILTER_VALIDATE_INT);
if (!in_array($days,[7,30,90],true)) $days=30;
$since='CURDATE() - INTERVAL '.($days-1).' DAY';
$metrics=[]; $series=[]; $groups=[]; $history=[]; $historyError=''; $page=1; $hasNext=false;
function ao_metric(PDO $pdo,string $sql): ?string {
    try { $v=$pdo->query($sql)->fetchColumn(); return $v===false?null:(string)$v; }
    catch(Throwable $e) { error_log('Admin analytics metric unavailable: '.$e->getMessage()); return null; }
}
function ao_rows(PDO $pdo,string $sql): ?array {
    try { return $pdo->query($sql)->fetchAll(PDO::FETCH_ASSOC); }
    catch(Throwable $e) { error_log('Admin analytics group unavailable: '.$e->getMessage()); return null; }
}
if ($tab==='analytics') {
    $queries=[
        'নতুন নিবন্ধিত ব্যবহারকারী'=>"SELECT COUNT(*) FROM users WHERE is_registered=1 AND created_at >= $since",
        'প্রকাশিত চাকরির বিজ্ঞপ্তি'=>"SELECT COUNT(*) FROM job_circulars WHERE status='published' AND published_at >= $since",
        'জমা দেওয়া মডেল টেস্ট'=>"SELECT COUNT(*) FROM model_test_attempts WHERE status='submitted' AND submitted_at >= $since",
        'অনুশীলন সেশন'=>"SELECT COUNT(*) FROM student_practice_sessions WHERE completed_at >= $since",
        'তৈরি হওয়া কমিউনিটি পোস্ট'=>"SELECT COUNT(*) FROM community_posts WHERE created_at >= $since",
        'তৈরি হওয়া কমিউনিটি মন্তব্য'=>"SELECT COUNT(*) FROM community_comments WHERE created_at >= $since",
        'মার্কেটপ্লেস অর্ডার'=>"SELECT COUNT(*) FROM market_orders WHERE created_at >= $since",
        'মূল্য পরিশোধিত ও সরবরাহকৃত অর্ডারের মূল্য (টাকা)'=>"SELECT COALESCE(SUM(total_amount),0) FROM market_orders WHERE created_at >= $since AND payment_status='paid' AND order_status='delivered'",
        'সেবা অনুরোধ'=>"SELECT COUNT(*) FROM market_service_requests WHERE created_at >= $since",
        'তৈরি হওয়া নোটিফিকেশন'=>"SELECT COUNT(*) FROM notifications WHERE created_at >= $since",
    ];
    foreach($queries as $label=>$sql) $metrics[$label]=ao_metric($pdo,$sql);
    foreach(['নিবন্ধন'=>['users','created_at',' AND is_registered=1'],'কমিউনিটি পোস্ট'=>['community_posts','created_at',''],'অর্ডার'=>['market_orders','created_at',''],'অনুশীলন সেশন'=>['student_practice_sessions','completed_at','']] as $label=>[$table,$column,$extra]) {
        $series[$label]=ao_rows($pdo,"SELECT DATE($column) AS day, COUNT(*) AS total FROM $table WHERE $column >= $since $extra GROUP BY DATE($column) ORDER BY day");
    }
    $groups['নির্বাচিত সময়ে করা অর্ডারের বর্তমান অবস্থা']=ao_rows($pdo,"SELECT order_status AS label,COUNT(*) AS total FROM market_orders WHERE created_at >= $since GROUP BY order_status ORDER BY total DESC");
    $groups['নির্বাচিত সময়ে তৈরি পোস্টের মডারেশন অবস্থা']=ao_rows($pdo,"SELECT status AS label,COUNT(*) AS total FROM community_posts WHERE created_at >= $since GROUP BY status ORDER BY total DESC");
    $groups['নতুন ব্যবহারকারীদের বর্তমান পেশাগত অবস্থা']=ao_rows($pdo,"SELECT current_status AS label,COUNT(*) AS total FROM users WHERE is_registered=1 AND created_at >= $since GROUP BY current_status ORDER BY total DESC");
    $groups['সেবা অনুরোধের অবস্থা']=ao_rows($pdo,"SELECT status AS label,COUNT(*) AS total FROM market_service_requests WHERE created_at >= $since GROUP BY status ORDER BY total DESC");
}
if($tab==='notifications'){
    $page=max(1,min(10000,(int)($_GET['page']??1)));
    try {
        $offset=($page-1)*25;
        $history=$pdo->query("SELECT c.id,c.title,c.notification_type,c.audience,c.recipient_count,c.created_at,(SELECT COUNT(*) FROM notifications n WHERE n.reference_type='admin_campaign' AND n.reference_id=c.id AND n.is_read=1) AS read_count FROM admin_notification_campaigns c ORDER BY c.id DESC LIMIT 26 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
        $hasNext=count($history)>25; if($hasNext) array_pop($history);
    } catch(Throwable $e){$historyError='প্রকাশের ইতিহাস পাওয়া যাচ্ছে না। মাইগ্রেশন পরীক্ষা করুন।';}
}
?>
<!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>অ্যাডমিন ব্যবস্থাপনা | Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;font:15px/1.5 system-ui,'Noto Sans Bengali',sans-serif;background:#f6f5f7;color:#30212a}header{background:#500b19;color:white;padding:18px 5vw}header a{color:white}main{max-width:1250px;margin:auto;padding:20px}nav{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}nav a,.btn,button{display:inline-block;border:1px solid #762637;padding:10px 15px;border-radius:9px;text-decoration:none;color:#650d18;background:white;font:inherit;cursor:pointer}nav a[aria-current],button{background:#650d18;color:white}button:disabled{opacity:.5;cursor:not-allowed}.panel,.metric{background:white;border:1px solid #eadfe3;border-radius:14px;padding:18px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}.metric strong{display:block;font-size:26px;color:#650d18}.muted{color:#71626b}.notice{padding:12px;border-left:4px solid #a66a12;background:#fff4db;margin:12px 0}.fields{display:grid;gap:12px;max-width:740px}label{display:block;font-weight:600}input:not([type=checkbox]),select,textarea{width:100%;padding:10px;border:1px solid #cfbec6;border-radius:8px;font:inherit;margin-top:5px}table{width:100%;border-collapse:collapse}th,td{padding:10px;text-align:left;border-bottom:1px solid #eee4e8;overflow-wrap:anywhere}.scroll{overflow:auto}progress{width:100%;accent-color:#650d18}h1,h2{margin-top:0}h2{font-size:19px}.day{display:grid;grid-template-columns:105px 1fr 45px;align-items:center;gap:8px;margin:5px 0}.trend{max-height:350px;overflow:auto}a{color:#650d18}button:focus-visible,a:focus-visible,input:focus-visible{outline:3px solid #e99ca7;outline-offset:2px}
</style></head><body><header><strong>Fire Safety BD · অ্যাডমিন ব্যবস্থাপনা</strong> · <a href="fire_safety_job_prep_dashboard.php">ড্যাশবোর্ড</a> · <a href="logout.php">লগ আউট</a></header>
<main><nav aria-label="অ্যাডমিন ব্যবস্থাপনা"><?php foreach($tabs as $key=>$label): ?><a href="?tab=<?= h($key) ?>" <?= $key===$tab?'aria-current="page"':'' ?>><?= h($label) ?></a><?php endforeach; ?></nav>
<h1><?= h($tabs[$tab]) ?></h1>
<?php if($flash!==''): ?><p class="notice" role="status"><?= h((string)$flash) ?></p><?php endif; ?>
<?php if($migrationError!=='' && $tab!=='analytics'): ?><p class="notice"><?= h($migrationError) ?></p><?php endif; ?>
<?php if($tab==='analytics'): ?>
<form method="get" class="panel"><input type="hidden" name="tab" value="analytics"><label>রিপোর্টের সময়সীমা<select name="days"><?php foreach([7,30,90] as $d): ?><option value="<?= $d ?>" <?= $d===$days?'selected':'' ?>>গত <?= $d ?> দিন</option><?php endforeach; ?></select></label><button>প্রয়োগ করুন</button><p class="muted">আজসহ ডাটাবেজ সার্ভারের সময় অনুযায়ী হিসাব করা হয়েছে। বর্তমানে সংরক্ষিত তথ্য দেখানো হচ্ছে। পরিশোধিত ও সরবরাহকৃত অর্ডারের মূল্য নির্বাচিত সময়ে করা অর্ডারের বর্তমান মূল্য; এটি নগদ প্রবাহ বা লাভ নয়।</p></form>
<div class="grid"><?php foreach($metrics as $label=>$value): ?><div class="metric"><small><?= h($label) ?></small><strong><?= h($value??'তথ্য পাওয়া যাচ্ছে না') ?></strong></div><?php endforeach; ?></div>
<div class="grid"><?php foreach($series as $label=>$rows): ?><section class="panel"><h2><?= h($label) ?> · দৈনিক</h2><?php if($rows===null): ?><p>তথ্য পাওয়া যাচ্ছে না</p><?php elseif(!$rows): ?><p>নির্বাচিত সময়ে কোনো তথ্য নেই।</p><?php else: $max=max(1,...array_map(fn($x)=>(int)$x['total'],$rows)); ?><div class="trend"><?php foreach($rows as $row): ?><div class="day"><span><?= h($row['day']) ?></span><progress value="<?= (int)$row['total'] ?>" max="<?= $max ?>" aria-label="<?= h($row['day']) ?>"></progress><span><?= (int)$row['total'] ?></span></div><?php endforeach; ?></div><small>শুধু তথ্য থাকা দিনগুলো দেখানো হয়েছে; বাদ পড়া দিনগুলোতে কোনো কার্যক্রম নেই।</small><?php endif; ?></section><?php endforeach; ?></div>
<div class="grid"><?php foreach($groups as $label=>$rows): ?><section class="panel"><h2><?= h($label) ?></h2><?php if($rows===null): ?><p>তথ্য পাওয়া যাচ্ছে না</p><?php elseif(!$rows): ?><p>কোনো তথ্য নেই।</p><?php else: ?><table><thead><tr><th>অবস্থা</th><th>সংখ্যা</th></tr></thead><tbody><?php foreach($rows as $row): ?><tr><td><?= h($statusLabels[$row['label']] ?? $row['label']) ?></td><td><?= (int)$row['total'] ?></td></tr><?php endforeach; ?></tbody></table><?php endif; ?></section><?php endforeach; ?></div>
<?php elseif($tab==='notifications'): ?>
<section class="panel"><h2>নোটিফিকেশন প্রকাশ করুন</h2><p class="muted">শুধু ডাটাবেজে ইনবক্সের তথ্য তৈরি হয়। এখনো ফায়ারবেস/মোবাইল পুশ, নির্ধারিত সময়ে পাঠানো বা বর্তমান অ্যাপে পৌঁছানোর নিশ্চয়তা নেই। একাধিক প্রাপককে পাঠানোর সুবিধা শুরুতে বন্ধ; প্রথমে পরীক্ষামূলক ব্যবহারকারী নির্বাচন করুন। অ্যাপের স্থানীয় পছন্দ এখনো সমন্বিত নয়।</p>
<form method="post" class="fields"><input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>"><input type="hidden" name="action" value="publish"><input type="hidden" name="request_key" value="<?= bin2hex(random_bytes(32)) ?>">
<label>শিরোনাম<input name="title" maxlength="200" required></label><label>বার্তা<textarea name="message" maxlength="2000" rows="4" required></textarea></label>
<label>ক্যাটাগরি<select name="notification_type"><?php foreach($types as $key=>$label): ?><option value="<?= h($key) ?>"><?= h($label) ?></option><?php endforeach; ?></select></label>
<label>প্রাপক নির্বাচন<select name="audience"><?php foreach($audiences as $key=>$label): ?><option value="<?= h($key) ?>" <?= $key!=='single' && !($settings['broadcast_enabled']??0)?'disabled':'' ?>><?= h($label) ?></option><?php endforeach; ?></select></label>
<label>নিবন্ধিত ব্যবহারকারীর আইডি (শুধু একজন প্রাপকের জন্য)<input type="number" min="1" name="target_user_id"></label>
<p>প্রাপকের সর্বোচ্চ সীমা: <?= (int)($settings['broadcast_limit']??0) ?> জন। সীমা অতিক্রম করলে সম্পূর্ণ অনুরোধ বাতিল হবে।</p>
<label><input type="checkbox" name="confirm_publish" value="1" required> নির্বাচিত প্রাপকদের জন্য নোটিফিকেশন তৈরির অনুমোদন দিচ্ছি।</label><button <?= !$settings?'disabled':'' ?>>প্রকাশ করুন</button></form></section>
<section class="panel"><h2>নোটিফিকেশন প্রকাশের ইতিহাস</h2><p class="muted">মূল প্রাপকের সংখ্যা ও বর্তমানে পড়া হয়েছে এমন রেকর্ডের সংখ্যা; মোবাইলে পৌঁছানোর হিসাব নয়।</p><?php if($historyError!==''): ?><p><?= h($historyError) ?></p><?php else: ?><div class="scroll"><table><thead><tr><th>আইডি</th><th>শিরোনাম</th><th>ধরন</th><th>প্রাপক শ্রেণি</th><th>প্রাপক</th><th>পড়েছেন</th><th>তৈরির সময়</th></tr></thead><tbody><?php foreach($history as $row): ?><tr><td><?= (int)$row['id'] ?></td><td><?= h($row['title']) ?></td><td><?= h($types[$row['notification_type']] ?? $row['notification_type']) ?></td><td><?= h($audiences[$row['audience']] ?? $row['audience']) ?></td><td><?= (int)$row['recipient_count'] ?></td><td><?= (int)$row['read_count'] ?></td><td><?= h($row['created_at']) ?></td></tr><?php endforeach; ?><?php if(!$history): ?><tr><td colspan="7">এই পেজে কোনো প্রকাশের ইতিহাস নেই।</td></tr><?php endif; ?></tbody></table></div><?php if($page>1): ?><a class="btn" href="?tab=notifications&amp;page=<?= $page-1 ?>">আগের পেজ</a><?php endif; ?> <?php if($hasNext): ?><a class="btn" href="?tab=notifications&amp;page=<?= $page+1 ?>">পরের পেজ</a><?php endif; ?><?php endif; ?></section>
<?php else: ?>
<section class="panel"><h2>পরিচালনাগত সেটিংস</h2><p class="muted">এই সেটিংস শুধু অ্যাডমিন নোটিফিকেশন প্রকাশ ও অ্যানালিটিক্সের ডিফল্ট সময়সীমা নিয়ন্ত্রণ করে। অ্যাপের থিম, ভাষা, লগইন বা পেমেন্ট কনফিগারেশন পরিবর্তন করে না।</p><form method="post" class="fields"><input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>"><input type="hidden" name="action" value="save_settings"><label><input type="checkbox" name="broadcast_enabled" value="1" <?= ($settings['broadcast_enabled']??0)?'checked':'' ?>> একাধিক ব্যবহারকারীকে নোটিফিকেশন পাঠানো চালু করুন</label><label>প্রতি নোটিফিকেশনে সর্বোচ্চ প্রাপক (১–৫০০০)<input name="broadcast_limit" type="number" min="1" max="5000" value="<?= (int)($settings['broadcast_limit']??500) ?>" required></label><label>অ্যানালিটিক্সের ডিফল্ট সময়সীমা<select name="analytics_days"><?php foreach([7,30,90] as $d): ?><option value="<?= $d ?>" <?= $d===(int)($settings['analytics_days']??30)?'selected':'' ?>><?= $d ?> দিন</option><?php endforeach; ?></select></label><button <?= !$settings?'disabled':'' ?>>সেটিংস সংরক্ষণ করুন</button></form></section>
<?php endif; ?>
</main></body></html>
