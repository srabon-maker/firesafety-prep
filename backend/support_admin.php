<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';
require_admin();
require_once __DIR__.'/db.php';
require_once __DIR__.'/support_common.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$url='support_admin.php';$title='গ্রাহক সহায়তা';
if(($_SERVER['REQUEST_METHOD']??'GET')==='POST'){
 verify_csrf();$id=null;
 try{
  $id=support_id($_POST['ticket_id']??null);$action=$_POST['action']??'';
  if(!in_array($action,['reply','close','reopen'],true))throw new DomainException('অনুরোধ সঠিক নয়।');
  $pdo->beginTransaction();
  $q=$pdo->prepare('SELECT status FROM support_tickets WHERE id=? FOR UPDATE');$q->execute([$id]);$status=$q->fetchColumn();
  if($status===false)throw new DomainException('টিকিট পাওয়া যায়নি।');
  if($action==='reply'){
   if($status==='closed')throw new DomainException('আগে টিকিটটি পুনরায় খুলুন।');
   support_add($pdo,$id,'admin',support_text($_POST['message']??null,2000));
  }else{
   if(($action==='close'&&$status==='closed')||($action==='reopen'&&$status!=='closed'))throw new DomainException('টিকিটের অবস্থা পরিবর্তিত হয়েছে।');
   $q=$pdo->prepare('UPDATE support_tickets SET status=?,updated_at=UTC_TIMESTAMP() WHERE id=?');$q->execute([$action==='close'?'closed':'open',$id]);
  }
  $pdo->commit();$_SESSION['support_flash']='সংরক্ষণ হয়েছে।';
 }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();if(!($e instanceof DomainException))error_log('Support admin: '.$e->getMessage());$_SESSION['support_flash']=$e instanceof DomainException?$e->getMessage():'সংরক্ষণ হয়নি।';}
 header('Location: '.$url.($id!==null?'?ticket_id='.$id:''),true,303);exit;
}
$flash=$_SESSION['support_flash']??'';unset($_SESSION['support_flash']);
$ready=true;$rows=[];$ticket=null;$thread=['messages'=>[],'next_before_id'=>null];$more=false;$counts=[];
$labels=['open'=>'উত্তরের অপেক্ষায়','answered'=>'উত্তর দেওয়া হয়েছে','closed'=>'বন্ধ'];
$plans=['none'=>'নির্দিষ্ট নয়','monthly'=>'মাসিক','quarterly'=>'ত্রৈমাসিক','annual'=>'বার্ষিক'];
$filter=$_GET['status']??'all';if(!is_string($filter)||!in_array($filter,['all','open','answered','closed'],true))$filter='all';
$page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;
try{
 $counts=$pdo->query('SELECT status,COUNT(*) AS total FROM support_tickets GROUP BY status')->fetchAll(PDO::FETCH_KEY_PAIR);
 $where=$filter==='all'?'':' WHERE t.status=?';$offset=($page-1)*25;
 $q=$pdo->prepare("SELECT t.*,u.full_name FROM support_tickets t JOIN users u ON u.id=t.user_id $where ORDER BY t.updated_at DESC,t.id DESC LIMIT 26 OFFSET $offset");$q->execute($filter==='all'?[]:[$filter]);$rows=$q->fetchAll(PDO::FETCH_ASSOC);
 $more=count($rows)>25;if($more)array_pop($rows);
 if(isset($_GET['ticket_id'])){
  $id=support_id($_GET['ticket_id']);$q=$pdo->prepare('SELECT t.*,u.full_name FROM support_tickets t JOIN users u ON u.id=t.user_id WHERE t.id=?');$q->execute([$id]);$ticket=$q->fetch(PDO::FETCH_ASSOC);
  if(!$ticket)throw new DomainException('টিকিট পাওয়া যায়নি।');
  $thread=support_thread($pdo,$id,isset($_GET['before_id'])?support_id($_GET['before_id']):null);
 }
}catch(DomainException $e){$flash=$e->getMessage();}catch(Throwable $e){$ready=false;error_log('Support admin: '.$e->getMessage());}
$nav=[
 ['fire_safety_job_prep_dashboard.php','▦','ড্যাশবোর্ড'],['questions.php','ⓘ','প্রশ্ন ব্যাংক'],['model_tests.php','☑','মডেল টেস্ট'],['notes.php','◫','নোট'],['job_circulars.php','▣','চাকরির সার্কুলার'],
 ['fire_safety_job_prep_dashboard.php?section=marketplace','🛒','মার্কেটপ্লেস'],['category_management.php','⊞','ক্যাটাগরি'],['users.php','♙','ব্যবহারকারী'],['homepage_admin.php','⌂','হোমপেজ ব্যবস্থাপনা'],['interview_admin.php','▤','ইন্টারভিউ ব্যবস্থাপনা'],
 ['notifications_admin.php','♧','নোটিফিকেশন'],['fire_safety_job_prep_dashboard.php?section=community','▱','কমিউনিটি'],['settings_admin.php','☼','সেটিংস'],['analytics_admin.php','▥','অ্যানালিটিক্স'],['premium_admin.php','♛','প্রিমিয়াম ব্যবস্থাপনা'],['ads_admin.php','▧','বিজ্ঞাপন ব্যবস্থাপনা'],['support_admin.php','✉','গ্রাহক সহায়তা'],['logout.php','↪','লগ আউট']
];
function pm_nav(array $nav,string $url):void{?><nav class="pm-nav" aria-label="অ্যাডমিন মেনু"><?php foreach($nav as [$link,$icon,$name]):?><a href="<?=h($link)?>" class="<?=$link===$url?'active':''?>" <?=$link===$url?'aria-current="page"':''?>><span aria-hidden="true"><?=h($icon)?></span> <?=h($name)?></a><?php endforeach;?></nav><?php }

?><!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>গ্রাহক সহায়তা | Fire Safety BD</title>
<link rel="stylesheet" href="assets/admin-unified.css"><style>
*{box-sizing:border-box}body{margin:0;background:#fff8f5;color:#30191b;font:15px/1.65 system-ui,"Noto Sans Bengali",Arial,sans-serif}a{text-decoration:none;color:inherit}.pm-layout{display:grid;grid-template-columns:260px minmax(0,1fr);min-height:100vh;align-items:start}.pm-side{background:linear-gradient(#450b15,#6a111f);color:white;min-height:100vh;padding:20px 13px}.pm-brand{display:flex;gap:12px;align-items:center;padding:8px 4px 22px}.pm-brand img{width:52px;height:52px;border:2px solid white;border-radius:12px;object-fit:contain}.pm-brand strong{font-size:19px}.pm-brand small{display:block;color:#e0bfc2}.pm-nav{display:grid;gap:4px}.pm-nav a{padding:11px 13px;border-radius:12px;display:flex;gap:11px;align-items:center}.pm-nav a:hover{background:#ffffff20}.pm-nav a.active{background:#ffa400;color:#30191b;font-weight:800}.pm-main{min-width:0;width:100%;max-width:1400px;margin:0 auto;padding:26px clamp(14px,3vw,40px)}.pm-main h1{margin:0;color:#510d18;font-size:clamp(24px,3vw,34px)}.pm-main h2{font-size:20px;color:#510d18;margin:0 0 12px}.pm-panel{padding:20px;border:1px solid #eadbd5;border-radius:18px;background:white;margin:18px 0;box-shadow:0 5px 20px #450b1509}.pm-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.pm-fields{display:grid;gap:12px}.pm-fields label{display:block;font-weight:650}.pm-fields input:not([type=checkbox]),.pm-fields select{display:block;width:100%;padding:11px;border:1px solid #e5d2cc;border-radius:10px;background:#fdfaf9;font:inherit}.pm-fields input[type=checkbox]{accent-color:#650d18}.pm-main button{border:0;border-radius:10px;background:#650d18;color:white;padding:10px 16px;font:inherit;font-weight:700;cursor:pointer}.pm-main button.danger{background:#a12635}.pm-muted{color:#776468}.pm-note{background:#fff4db;padding:12px;border-radius:12px;border:1px solid #ead4aa}.pm-scroll{overflow-x:auto}.pm-scroll table{border-collapse:collapse;width:100%;font-size:14px}.pm-scroll th,.pm-scroll td{padding:10px;border-bottom:1px solid #eee1dc;text-align:left;vertical-align:top;overflow-wrap:anywhere}.pm-scroll th{background:#faf1ec}.pm-mobile{display:none}.pm-crumb{font-size:13px;color:#776468}@media(max-width:900px){.pm-layout{display:block}.pm-side{display:none}.pm-mobile{display:block;background:#510d18;color:white;border-radius:12px;padding:12px;margin-bottom:14px}.pm-mobile summary{cursor:pointer}.pm-mobile .pm-nav{margin-top:10px}}@media(max-width:600px){.pm-grid{grid-template-columns:1fr}.pm-panel{padding:14px}}

.pm-main textarea{width:100%;padding:12px;min-height:120px;border:1px solid #e5d2cc;border-radius:10px;font:inherit}.msg{padding:14px;border-radius:12px;background:#f6eeeb;max-width:90%;margin:10px 0;overflow-wrap:anywhere;white-space:pre-wrap}.msg.admin{margin-left:auto;background:#650d18;color:white}.msg small{display:block;opacity:.8;margin-bottom:8px}.pm-scroll a{color:#650d18;text-decoration:underline}
</style></head><body><div class="pm-layout"><aside class="pm-side"><a class="pm-brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png?v=177" alt="Fire Safety BD"><span><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></span></a><?php pm_nav($nav,$url);?></aside><main class="pm-main"><details class="pm-mobile"><summary>☰ Fire Safety BD · অ্যাডমিন মেনু</summary><?php pm_nav($nav,$url);?></details><p class="pm-crumb">ড্যাশবোর্ড / গ্রাহক সহায়তা</p><h1>গ্রাহক সহায়তা</h1>
<p class="pm-muted">সদস্যপদ ও পেমেন্ট সহায়তা। PIN, OTP, কার্ডের তথ্য বা বিকল্প পেমেন্ট নির্দেশনা চাইবেন না।</p>
<?php if($flash!==''):?><p class="pm-note" role="status"><?=h($flash)?></p><?php endif;?>
<?php if(!$ready):?><p class="pm-note">সাপোর্ট ডেটাবেস প্রস্তুত নয়। মাইগ্রেশন পরীক্ষা করুন।</p><?php else:?>
<section class="pm-panel"><div class="pm-grid"><?php foreach($labels as $key=>$label):?><a href="?status=<?=h($key)?>"><strong><?=h($label)?>: <?=(int)($counts[$key]??0)?></strong></a><?php endforeach;?><a href="?">সব টিকিট</a></div></section>
<?php if($ticket):?><section class="pm-panel"><h2>#<?=h((string)$ticket['id'])?> · <?=h($ticket['subject'])?></h2><p><?=h($ticket['full_name'])?> · User #<?=h((string)$ticket['user_id'])?> · <?=h($plans[$ticket['plan_code']]??'')?> · <?=h($labels[$ticket['status']]??'')?></p>
<a href="?ticket_id=<?=h((string)$ticket['id'])?>">সর্বশেষ মেসেজ / রিফ্রেশ</a>
<?php if($thread['next_before_id']!==null):?><p><a href="?ticket_id=<?=h((string)$ticket['id'])?>&amp;before_id=<?=h($thread['next_before_id'])?>">পুরোনো মেসেজ</a></p><?php endif;?>
<?php foreach($thread['messages'] as $m):?><div class="msg <?=$m['sender']==='admin'?'admin':''?>"><small><?=$m['sender']==='admin'?'অ্যাডমিন':'ব্যবহারকারী'?> · <?=h($m['created_at'])?> UTC</small><?=h($m['body'])?></div><?php endforeach;?>
<?php if($ticket['status']!=='closed'):?><form method="post" class="pm-fields"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="ticket_id" value="<?=h((string)$ticket['id'])?>"><label>উত্তর লিখুন<textarea name="message" maxlength="2000" required></textarea></label><button name="action" value="reply">রিপ্লাই পাঠান</button></form><?php endif;?>
<form method="post" class="pm-fields" style="margin-top:14px"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="ticket_id" value="<?=h((string)$ticket['id'])?>"><button name="action" value="<?=$ticket['status']==='closed'?'reopen':'close'?>"><?=$ticket['status']==='closed'?'আবার খুলুন':'টিকিট বন্ধ করুন'?></button></form></section><?php endif;?>
<section class="pm-panel"><h2>টিকিট তালিকা</h2><div class="pm-scroll"><table><thead><tr><th>টিকিট</th><th>ব্যবহারকারী</th><th>প্যাকেজ</th><th>অবস্থা</th><th>সর্বশেষ</th></tr></thead><tbody><?php foreach($rows as $row):?><tr><td><a href="?ticket_id=<?=h((string)$row['id'])?>">#<?=h((string)$row['id'])?> <?=h($row['subject'])?></a></td><td><?=h($row['full_name'])?> · #<?=h((string)$row['user_id'])?></td><td><?=h($plans[$row['plan_code']]??'')?></td><td><?=h($labels[$row['status']]??'')?></td><td><?=h($row['updated_at'])?> UTC</td></tr><?php endforeach;?></tbody></table></div><?php if(!$rows):?><p>কোনো টিকিট নেই।</p><?php endif;?><?php if($page>1):?><a href="?status=<?=h($filter)?>&amp;page=<?=$page-1?>">আগের পেজ</a> <?php endif;?><?php if($more):?><a href="?status=<?=h($filter)?>&amp;page=<?=$page+1?>">পরের পেজ</a><?php endif;?></section>
<?php endif;?></main></div></body></html>
