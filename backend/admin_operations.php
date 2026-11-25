<?php
declare(strict_types=1);
require_once __DIR__ . '/admin_helpers.php';
require_admin();
require_once __DIR__ . '/db.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$tabs = ['analytics'=>'Analytics','notifications'=>'Notifications','settings'=>'Settings'];
$tab = is_string($_GET['tab'] ?? null) && isset($tabs[$_GET['tab']]) ? $_GET['tab'] : 'analytics';
$types = ['general'=>'General','study'=>'Study','app_update'=>'App update','community'=>'Community','marketplace'=>'Marketplace'];
$audiences = ['single'=>'One registered user','all'=>'All registered users','Employed'=>'Employed','Job Seeker'=>'Job seekers','Student'=>'Students','Other'=>'Other'];
function ao_text(string $key, int $max): string {
    $v = $_POST[$key] ?? '';
    if (!is_string($v)) throw new DomainException('Invalid text.');
    $v = trim($v);
    if ($v === '' || (function_exists('mb_strlen') ? mb_strlen($v,'UTF-8') : strlen($v)) > $max) throw new DomainException('Text is missing or too long.');
    return $v;
}
function ao_integer(string $key,int $min,int $max): int {
    $v = filter_var($_POST[$key] ?? null,FILTER_VALIDATE_INT,['options'=>['min_range'=>$min,'max_range'=>$max]]);
    if ($v === false) throw new DomainException('Invalid number.');
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
            if (!in_array($days,[7,30,90],true)) throw new DomainException('Choose 7, 30 or 90 days.');
            $pdo->beginTransaction();
            ao_settings($pdo,true);
            $q=$pdo->prepare('UPDATE admin_operation_settings SET broadcast_enabled=?,broadcast_limit=?,analytics_days=? WHERE id=1');
            $q->execute([$enabled,$limit,$days]);
            $pdo->commit();
            ao_redirect('settings','Settings saved.');
        }
        if ($action !== 'publish') throw new DomainException('Unknown action.');
        $title=ao_text('title',200); $message=ao_text('message',2000);
        $type=ao_text('notification_type',60); $audience=ao_text('audience',40);
        if (!isset($types[$type],$audiences[$audience])) throw new DomainException('Invalid audience or category.');
        if (($_POST['confirm_publish'] ?? '') !== '1') throw new DomainException('Confirm publishing first.');
        $request=ao_text('request_key',64);
        if (!preg_match('/^[a-f0-9]{64}$/D',$request)) throw new DomainException('Invalid request key.');
        $target=$audience==='single'?ao_integer('target_user_id',1,PHP_INT_MAX):null;
        $pdo->beginTransaction();
        $s=ao_settings($pdo,true);
        $cap=$audience==='single'?1:(int)$s['broadcast_limit'];
        if ($cap<1 || $cap>5000) throw new RuntimeException('Invalid configured limit');
        if ($audience!=='single' && !(int)$s['broadcast_enabled']) throw new DomainException('Broadcasts are disabled in Settings.');
        $q=$pdo->prepare('SELECT id FROM admin_notification_campaigns WHERE request_key=?');
        $q->execute([$request]);
        if ($q->fetchColumn()!==false) throw new DomainException('This request was already published.');
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
        if ($count<1) throw new DomainException('No registered recipients matched.');
        if ($count>$cap) throw new DomainException('Audience exceeds the configured limit. No notifications were created.');
        $q=$pdo->prepare('UPDATE admin_notification_campaigns SET recipient_count=? WHERE id=?');
        $q->execute([$count,$campaign]);
        $pdo->commit();
        ao_redirect('notifications',"Published $count in-app database records. No device push was sent.");
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if (!($e instanceof DomainException)) error_log('Admin operations: '.$e->getMessage());
        ao_redirect($action==='save_settings'?'settings':'notifications',$e instanceof DomainException?$e->getMessage():'Request could not be completed. Check migration and server logs.');
    }
}
$flash = $_SESSION['admin_ops_flash'] ?? '';
unset($_SESSION['admin_ops_flash']);
$settings=null; $migrationError='';
try { $settings=ao_settings($pdo); } catch (Throwable $e) { $migrationError='Apply the admin operations migration before using notification publishing or settings.'; }
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
        'New registered users'=>"SELECT COUNT(*) FROM users WHERE is_registered=1 AND created_at >= $since",
        'Job circulars published'=>"SELECT COUNT(*) FROM job_circulars WHERE status='published' AND published_at >= $since",
        'Model tests submitted'=>"SELECT COUNT(*) FROM model_test_attempts WHERE status='submitted' AND submitted_at >= $since",
        'Practice sessions'=>"SELECT COUNT(*) FROM student_practice_sessions WHERE completed_at >= $since",
        'Community posts created'=>"SELECT COUNT(*) FROM community_posts WHERE created_at >= $since",
        'Community comments created'=>"SELECT COUNT(*) FROM community_comments WHERE created_at >= $since",
        'Marketplace orders placed'=>"SELECT COUNT(*) FROM market_orders WHERE created_at >= $since",
        'Paid delivered order value (BDT)'=>"SELECT COALESCE(SUM(total_amount),0) FROM market_orders WHERE created_at >= $since AND payment_status='paid' AND order_status='delivered'",
        'Service requests'=>"SELECT COUNT(*) FROM market_service_requests WHERE created_at >= $since",
        'Notifications created'=>"SELECT COUNT(*) FROM notifications WHERE created_at >= $since",
    ];
    foreach($queries as $label=>$sql) $metrics[$label]=ao_metric($pdo,$sql);
    foreach(['Registrations'=>['users','created_at',' AND is_registered=1'],'Community posts'=>['community_posts','created_at',''],'Orders'=>['market_orders','created_at',''],'Practice sessions'=>['student_practice_sessions','completed_at','']] as $label=>[$table,$column,$extra]) {
        $series[$label]=ao_rows($pdo,"SELECT DATE($column) AS day, COUNT(*) AS total FROM $table WHERE $column >= $since $extra GROUP BY DATE($column) ORDER BY day");
    }
    $groups['Order status (orders placed in period)']=ao_rows($pdo,"SELECT order_status AS label,COUNT(*) AS total FROM market_orders WHERE created_at >= $since GROUP BY order_status ORDER BY total DESC");
    $groups['Post moderation (posts created in period)']=ao_rows($pdo,"SELECT status AS label,COUNT(*) AS total FROM community_posts WHERE created_at >= $since GROUP BY status ORDER BY total DESC");
    $groups['New users by current status']=ao_rows($pdo,"SELECT current_status AS label,COUNT(*) AS total FROM users WHERE is_registered=1 AND created_at >= $since GROUP BY current_status ORDER BY total DESC");
    $groups['Service request status']=ao_rows($pdo,"SELECT status AS label,COUNT(*) AS total FROM market_service_requests WHERE created_at >= $since GROUP BY status ORDER BY total DESC");
}
if($tab==='notifications'){
    $page=max(1,min(10000,(int)($_GET['page']??1)));
    try {
        $offset=($page-1)*25;
        $history=$pdo->query("SELECT c.id,c.title,c.notification_type,c.audience,c.recipient_count,c.created_at,(SELECT COUNT(*) FROM notifications n WHERE n.reference_type='admin_campaign' AND n.reference_id=c.id AND n.is_read=1) AS read_count FROM admin_notification_campaigns c ORDER BY c.id DESC LIMIT 26 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
        $hasNext=count($history)>25; if($hasNext) array_pop($history);
    } catch(Throwable $e){$historyError='Campaign history unavailable. Check migration.';}
}
?>
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Admin operations | Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;font:15px/1.5 system-ui,sans-serif;background:#f6f5f7;color:#30212a}header{background:#500b19;color:white;padding:18px 5vw}header a{color:white}main{max-width:1250px;margin:auto;padding:20px}nav{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}nav a,.btn,button{display:inline-block;border:1px solid #762637;padding:10px 15px;border-radius:9px;text-decoration:none;color:#650d18;background:white;font:inherit;cursor:pointer}nav a[aria-current],button{background:#650d18;color:white}button:disabled{opacity:.5;cursor:not-allowed}.panel,.metric{background:white;border:1px solid #eadfe3;border-radius:14px;padding:18px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}.metric strong{display:block;font-size:26px;color:#650d18}.muted{color:#71626b}.notice{padding:12px;border-left:4px solid #a66a12;background:#fff4db;margin:12px 0}.fields{display:grid;gap:12px;max-width:740px}label{display:block;font-weight:600}input:not([type=checkbox]),select,textarea{width:100%;padding:10px;border:1px solid #cfbec6;border-radius:8px;font:inherit;margin-top:5px}table{width:100%;border-collapse:collapse}th,td{padding:10px;text-align:left;border-bottom:1px solid #eee4e8;overflow-wrap:anywhere}.scroll{overflow:auto}progress{width:100%;accent-color:#650d18}h1,h2{margin-top:0}h2{font-size:19px}.day{display:grid;grid-template-columns:105px 1fr 45px;align-items:center;gap:8px;margin:5px 0}.trend{max-height:350px;overflow:auto}a{color:#650d18}button:focus-visible,a:focus-visible,input:focus-visible{outline:3px solid #e99ca7;outline-offset:2px}
</style></head><body><header><strong>Fire Safety BD · Admin Operations</strong> · <a href="fire_safety_job_prep_dashboard.php">Dashboard</a> · <a href="logout.php">Logout</a></header>
<main><nav aria-label="Admin operations"><?php foreach($tabs as $key=>$label): ?><a href="?tab=<?= h($key) ?>" <?= $key===$tab?'aria-current="page"':'' ?>><?= h($label) ?></a><?php endforeach; ?></nav>
<h1><?= h($tabs[$tab]) ?></h1>
<?php if($flash!==''): ?><p class="notice" role="status"><?= h((string)$flash) ?></p><?php endif; ?>
<?php if($migrationError!=='' && $tab!=='analytics'): ?><p class="notice"><?= h($migrationError) ?></p><?php endif; ?>
<?php if($tab==='analytics'): ?>
<form method="get" class="panel"><input type="hidden" name="tab" value="analytics"><label>Reporting period<select name="days"><?php foreach([7,30,90] as $d): ?><option value="<?= $d ?>" <?= $d===$days?'selected':'' ?>>Last <?= $d ?> calendar days</option><?php endforeach; ?></select></label><button>Apply</button><p class="muted">Includes today; database server time. Counts reflect currently stored records. Paid delivered value is the current value of orders placed in this period, not cash-flow or profit.</p></form>
<div class="grid"><?php foreach($metrics as $label=>$value): ?><div class="metric"><small><?= h($label) ?></small><strong><?= h($value??'Unavailable') ?></strong></div><?php endforeach; ?></div>
<div class="grid"><?php foreach($series as $label=>$rows): ?><section class="panel"><h2><?= h($label) ?> · daily</h2><?php if($rows===null): ?><p>Unavailable</p><?php elseif(!$rows): ?><p>No records in period.</p><?php else: $max=max(1,...array_map(fn($x)=>(int)$x['total'],$rows)); ?><div class="trend"><?php foreach($rows as $row): ?><div class="day"><span><?= h($row['day']) ?></span><progress value="<?= (int)$row['total'] ?>" max="<?= $max ?>" aria-label="<?= h($row['day']) ?>"></progress><span><?= (int)$row['total'] ?></span></div><?php endforeach; ?></div><small>Days with records only; omitted days have zero events.</small><?php endif; ?></section><?php endforeach; ?></div>
<div class="grid"><?php foreach($groups as $label=>$rows): ?><section class="panel"><h2><?= h($label) ?></h2><?php if($rows===null): ?><p>Unavailable</p><?php elseif(!$rows): ?><p>No records.</p><?php else: ?><table><thead><tr><th>Status</th><th>Count</th></tr></thead><tbody><?php foreach($rows as $row): ?><tr><td><?= h($row['label']) ?></td><td><?= (int)$row['total'] ?></td></tr><?php endforeach; ?></tbody></table><?php endif; ?></section><?php endforeach; ?></div>
<?php elseif($tab==='notifications'): ?>
<section class="panel"><h2>Publish notification</h2><p class="muted">Creates database inbox records only. No Firebase/device push, scheduling, or guaranteed delivery to the current app. Broadcasts are disabled by default; use a test user first. Local app preferences are not synchronized.</p>
<form method="post" class="fields"><input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>"><input type="hidden" name="action" value="publish"><input type="hidden" name="request_key" value="<?= bin2hex(random_bytes(32)) ?>">
<label>Title<input name="title" maxlength="200" required></label><label>Message<textarea name="message" maxlength="2000" rows="4" required></textarea></label>
<label>Category<select name="notification_type"><?php foreach($types as $key=>$label): ?><option value="<?= h($key) ?>"><?= h($label) ?></option><?php endforeach; ?></select></label>
<label>Audience<select name="audience"><?php foreach($audiences as $key=>$label): ?><option value="<?= h($key) ?>" <?= $key!=='single' && !($settings['broadcast_enabled']??0)?'disabled':'' ?>><?= h($label) ?></option><?php endforeach; ?></select></label>
<label>Registered user ID (single-user only)<input type="number" min="1" name="target_user_id"></label>
<p>Broadcast limit: <?= (int)($settings['broadcast_limit']??0) ?> recipients. Above-limit requests are rejected entirely.</p>
<label><input type="checkbox" name="confirm_publish" value="1" required> Confirm creating notification records for the selected audience.</label><button <?= !$settings?'disabled':'' ?>>Publish</button></form></section>
<section class="panel"><h2>Campaign history</h2><p class="muted">Original recipient count and current read flags, not device delivery metrics.</p><?php if($historyError!==''): ?><p><?= h($historyError) ?></p><?php else: ?><div class="scroll"><table><thead><tr><th>ID</th><th>Title</th><th>Type</th><th>Audience</th><th>Recipients</th><th>Read</th><th>Created</th></tr></thead><tbody><?php foreach($history as $row): ?><tr><td><?= (int)$row['id'] ?></td><td><?= h($row['title']) ?></td><td><?= h($row['notification_type']) ?></td><td><?= h($row['audience']) ?></td><td><?= (int)$row['recipient_count'] ?></td><td><?= (int)$row['read_count'] ?></td><td><?= h($row['created_at']) ?></td></tr><?php endforeach; ?><?php if(!$history): ?><tr><td colspan="7">No campaigns on this page.</td></tr><?php endif; ?></tbody></table></div><?php if($page>1): ?><a class="btn" href="?tab=notifications&amp;page=<?= $page-1 ?>">Previous</a><?php endif; ?> <?php if($hasNext): ?><a class="btn" href="?tab=notifications&amp;page=<?= $page+1 ?>">Next</a><?php endif; ?><?php endif; ?></section>
<?php else: ?>
<section class="panel"><h2>Operational settings</h2><p class="muted">These settings control the admin notification publisher and analytics defaults only. They do not change the app's local theme, language, authentication or payment configuration.</p><form method="post" class="fields"><input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>"><input type="hidden" name="action" value="save_settings"><label><input type="checkbox" name="broadcast_enabled" value="1" <?= ($settings['broadcast_enabled']??0)?'checked':'' ?>> Enable multi-user broadcasts</label><label>Maximum recipients per broadcast (1–5000)<input name="broadcast_limit" type="number" min="1" max="5000" value="<?= (int)($settings['broadcast_limit']??500) ?>" required></label><label>Default analytics period<select name="analytics_days"><?php foreach([7,30,90] as $d): ?><option value="<?= $d ?>" <?= $d===(int)($settings['analytics_days']??30)?'selected':'' ?>><?= $d ?> days</option><?php endforeach; ?></select></label><button <?= !$settings?'disabled':'' ?>>Save settings</button></form></section>
<?php endif; ?>
</main></body></html>
