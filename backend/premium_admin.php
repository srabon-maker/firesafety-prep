<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';
require_admin();
require_once __DIR__.'/db.php';
require_once __DIR__.'/premium_learning.php';
require_once __DIR__.'/premium_pdf_storage.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$isAds=defined('FSBD_ADS_ADMIN')&&FSBD_ADS_ADMIN===true;
$url=$isAds?'ads_admin.php':'premium_admin.php';
$title=$isAds?'বিজ্ঞাপন ব্যবস্থাপনা':'প্রিমিয়াম ব্যবস্থাপনা';
$flashKey=$isAds?'ads_admin_flash':'premium_admin_flash';
function pm_id(mixed $v,int $min=1,int $max=PHP_INT_MAX):int {
    $n=filter_var($v,FILTER_VALIDATE_INT,['options'=>['min_range'=>$min,'max_range'=>$max]]);
    if($n===false)throw new DomainException('সঠিক সংখ্যা দিন।');return $n;
}
if(($_SERVER['REQUEST_METHOD']??'GET')==='POST'){
    verify_csrf();
    $uploadedPdf=null;
    try{
        $action=$_POST['action']??'';
        if($isAds&&$action==='ads'){
            $flags=[];foreach(['ads_requested','home_native','question_native','results_interstitial','rewarded'] as $k)$flags[]=($_POST[$k]??'')==='1'?1:0;
            $limit=pm_id($_POST['daily_fullscreen_limit']??null,0,2);
            $q=$pdo->prepare('UPDATE premium_ads_settings SET ads_requested=?,home_native=?,question_native=?,results_interstitial=?,rewarded=?,daily_fullscreen_limit=? WHERE id=1');
            $q->execute([...$flags,$limit]);
        }elseif(!$isAds&&$action==='global_access'){
            $mode=$_POST['mode']??'';$start=$_POST['starts_at']??'';
            if(!is_string($mode)||!in_array($mode,['free','selected','all'],true)||!is_string($start))throw new DomainException('সঠিক মোড নির্বাচন করুন।');
            if($mode!=='free'&&($_POST['confirm']??'')!=='1')throw new DomainException('লক চালু করার আগে নিশ্চিত করুন।');
            $utc=null;
            if($mode!=='free'&&$start!==''){
                $dt=DateTimeImmutable::createFromFormat('!Y-m-d\\TH:i',$start,new DateTimeZone('Asia/Dhaka'));
                if(!$dt||$dt->format('Y-m-d\\TH:i')!==$start||$dt<=new DateTimeImmutable('now',new DateTimeZone('Asia/Dhaka')))throw new DomainException('ভবিষ্যতের সঠিক বাংলাদেশ সময় দিন, অথবা এখনই চালুর জন্য সময় খালি রাখুন।');
                $utc=$dt->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');
            }
            $q=$pdo->prepare('UPDATE premium_access_policy SET mode=?,starts_at=?,updated_at=UTC_TIMESTAMP() WHERE id=1');$q->execute([$mode,$utc]);
        }elseif($action==='integration'){
            // Public identifiers only; no service-account keys, no activation flag.
            $keys=$isAds?['admob_app_id','home_native_id','question_native_id','interstitial_id','rewarded_id']:['monthly_product_id','quarterly_product_id','annual_product_id'];
            $args=[];foreach($keys as $k){
                $v=$_POST[$k]??'';if(!is_string($v))throw new DomainException('আইডি সঠিক নয়।');$v=trim($v);
                $pattern=$isAds?($k==='admob_app_id'?'~^ca-app-pub-[0-9]{16}~D':'~^ca-app-pub-[0-9]{16}/[0-9]{10}$~D'):'~^[a-z0-9][a-z0-9_.]{0,149}$~D';
                if($k==='admob_app_id')$pattern='/^ca-app-pub-[0-9]{16}~[0-9]{10}$/D';
                if($v!==''&&!preg_match($pattern,$v))throw new DomainException('আইডি ফরম্যাট সঠিক নয়: '.$k);
                $args[]=$v;
            }
            $q=$pdo->prepare('UPDATE premium_integration_config SET '.implode('=?,',$keys).'=? WHERE id=1');$q->execute($args);
        }elseif(!$isAds&&$action==='private_pdf'){
            $id=pm_id($_POST['content_id']??null);
            $pdo->beginTransaction();
            $q=$pdo->prepare("SELECT n.id,n.file_url FROM notes n JOIN premium_note_items i ON i.note_id=n.id WHERE n.id=? FOR UPDATE");
            $q->execute([$id]);$note=$q->fetch(PDO::FETCH_ASSOC);
            if(!$note||trim((string)$note['file_url'])!=='')throw new DomainException('পাবলিক ফাইল ছাড়া Premium নোট নির্বাচন করুন।');
            $file=$_FILES['private_pdf']??null;if(!is_array($file))throw new DomainException('PDF নির্বাচন করুন।');
            $uploadedPdf=premium_pdf_upload($file);
            $q=$pdo->prepare('INSERT INTO premium_note_pdfs(note_id,storage_name,size_bytes,updated_at) VALUES (?,?,?,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE storage_name=VALUES(storage_name),size_bytes=VALUES(size_bytes),updated_at=VALUES(updated_at)');
            $q->execute([$id,$uploadedPdf['name'],$uploadedPdf['size']]);
            $pdo->prepare('DELETE FROM premium_pdf_downloads WHERE note_id=?')->execute([$id]);
            $pdo->commit();$uploadedPdf=null;
        }elseif(!$isAds&&$action==='learning'){
            $type=$_POST['type']??'';$id=pm_id($_POST['content_id']??null);
            $map=['question'=>['questions','premium_question_items','question_id'],'note'=>['notes','premium_note_items','note_id'],'test'=>['model_tests','premium_test_items','test_id']];
            if(!is_string($type)||!isset($map[$type]))throw new DomainException('কনটেন্টের ধরন সঠিক নয়।');
            [$source,$target,$column]=$map[$type];
            $pdo->beginTransaction();
            $q=$pdo->prepare("SELECT * FROM $source WHERE id=? FOR UPDATE");$q->execute([$id]);$row=$q->fetch(PDO::FETCH_ASSOC);
            if(!$row)throw new DomainException('কনটেন্ট পাওয়া যায়নি।');
            $lock=($_POST['locked']??'')==='1';
            if($lock&&$type==='note'&&trim((string)($row['file_url']??''))!=='')throw new DomainException('পুরোনো পাবলিক ফাইল যুক্ত নোট লক করা যাবে না। আগে নিরাপদ ফাইল ব্যবস্থায় স্থানান্তর প্রয়োজন।');
            if($lock&&$type==='note'&&preg_match('/(?:https?:|uploads\/|<\s*(?:img|iframe|object|embed|video|audio|a)\b)/i',(string)($row['content']??'')))throw new DomainException('পাবলিক লিংক বা মিডিয়া যুক্ত নোট আগে পরিষ্কার করুন।');
            $q=$pdo->prepare($lock?"INSERT IGNORE INTO $target($column) VALUES (?)":"DELETE FROM $target WHERE $column=?");$q->execute([$id]);$pdo->commit();
        }elseif(!$isAds&&in_array($action,['grant','revoke'],true)){
            $id=pm_id($_POST['user_id']??null);
            $reason=$_POST['reason']??'';
            if(!is_string($reason)||!preg_match('//u',$reason)||trim($reason)===''||mb_strlen(trim($reason),'UTF-8')>240||($_POST['confirm']??'')!=='1')throw new DomainException('কারণ এবং নিশ্চিতকরণ দিন।');
            $pdo->beginTransaction();
            $q=$pdo->prepare('SELECT id FROM users WHERE id=? AND is_registered=1 FOR UPDATE');
            $q->execute([$id]);if(!$q->fetchColumn())throw new DomainException('নিবন্ধিত ব্যবহারকারী পাওয়া যায়নি।');
            $expiry=null;
            if($action==='grant'){
                $days=pm_id($_POST['days']??null,1,365);
                $q=$pdo->prepare('INSERT INTO premium_memberships(user_id,expires_at,updated_at) VALUES (?,UTC_TIMESTAMP()+INTERVAL '.$days.' DAY,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE expires_at=VALUES(expires_at),updated_at=VALUES(updated_at)');
                $q->execute([$id]);
                $q=$pdo->prepare('SELECT expires_at FROM premium_memberships WHERE user_id=?');$q->execute([$id]);$expiry=$q->fetchColumn();
            }else{
                $q=$pdo->prepare('DELETE FROM premium_memberships WHERE user_id=?');$q->execute([$id]);
            }
            $q=$pdo->prepare('INSERT INTO premium_membership_events(user_id,action,expires_at,reason,created_at) VALUES (?,?,?,?,UTC_TIMESTAMP())');
            $q->execute([$id,$action,$expiry,trim($reason)]);$pdo->commit();
        }elseif(!$isAds&&$action==='plan'){
            $code=$_POST['code']??'';if(!in_array($code,['monthly','quarterly','annual'],true))throw new DomainException('প্যাকেজ সঠিক নয়।');
            $price=pm_id($_POST['price']??null,1,100000);
            $q=$pdo->prepare('UPDATE premium_plans SET proposed_price_bdt=? WHERE code=?');$q->execute([$price,$code]);
        }elseif(!$isAds&&$action==='interview'){
            $id=pm_id($_POST['content_id']??null);
            $pdo->beginTransaction();
            $q=$pdo->prepare("SELECT id FROM homepage_content WHERE id=? AND kind='interview' FOR UPDATE");$q->execute([$id]);if(!$q->fetchColumn())throw new DomainException('ইন্টারভিউ প্রশ্ন পাওয়া যায়নি।');
            $q=$pdo->prepare(($_POST['locked']??'')==='1'?'INSERT IGNORE INTO premium_interview_items(content_id) VALUES (?)':'DELETE FROM premium_interview_items WHERE content_id=?');$q->execute([$id]);$pdo->commit();
        }else throw new DomainException('অনুরোধ সঠিক নয়।');
        $_SESSION[$flashKey]='সংরক্ষণ হয়েছে।';
    }catch(Throwable $e){
        if($pdo->inTransaction()){$pdo->rollBack();if($uploadedPdf!==null)@unlink($uploadedPdf['path']);}
        if(!($e instanceof DomainException))error_log('Premium admin: '.$e->getMessage());
        $_SESSION[$flashKey]=$e instanceof DomainException?$e->getMessage():'সংরক্ষণ হয়নি। মাইগ্রেশন ও সার্ভার লগ পরীক্ষা করুন।';
    }
    $back=$url;
    if(!$isAds&&in_array($_POST['action']??'',['learning','private_pdf'],true)){$back.='?learning_type='.rawurlencode(($_POST['action']??'')==='private_pdf'?'note':(is_string($_POST['type']??null)?$_POST['type']:'question'));}
    header('Location: '.$back,true,303);exit;
}
$flash=$_SESSION[$flashKey]??'';unset($_SESSION[$flashKey]);$ready=true;$plans=[];$members=[];$events=[];$items=[];$ads=[];$more=false;
$policy=[];$integration=[];$memberStats=[];$learning=[];$learningMore=false;
$learningType=$_GET['learning_type']??'question';if(!is_string($learningType)||!in_array($learningType,['question','note','test'],true))$learningType='question';
$learningPage=filter_var($_GET['learning_page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;
$page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;
try{
    $integration=$pdo->query('SELECT * FROM premium_integration_config WHERE id=1')->fetch(PDO::FETCH_ASSOC);if(!$integration)throw new RuntimeException('Missing integration settings');
    if(!$isAds)$policy=premium_policy($pdo);
    if($isAds){$ads=$pdo->query('SELECT * FROM premium_ads_settings WHERE id=1')->fetch(PDO::FETCH_ASSOC);if(!$ads)throw new RuntimeException('Missing settings');}
    else{
        $memberStats=$pdo->query("SELECT COUNT(*) AS total,COALESCE(SUM(expires_at>UTC_TIMESTAMP()),0) AS active,COALESCE(SUM(expires_at<=UTC_TIMESTAMP()),0) AS expired FROM premium_memberships")->fetch(PDO::FETCH_ASSOC);
        $learningOffset=($learningPage-1)*25;
        $sql=match($learningType){
            'question'=>"SELECT q.id,q.question AS title,q.status,".premium_question_marked()." AS marked,0 AS inherited FROM questions q WHERE q.is_archived=0 ORDER BY q.id DESC",
            'note'=>"SELECT n.id,n.title,n.status,".premium_note_marked()." AS marked,0 AS inherited,EXISTS(SELECT 1 FROM premium_note_pdfs pp WHERE pp.note_id=n.id) AS private_pdf FROM notes n ORDER BY n.id DESC",
            'test'=>"SELECT mt.id,mt.title,mt.status,EXISTS(SELECT 1 FROM premium_test_items p WHERE p.test_id=mt.id) AS marked,".premium_test_marked()." AS inherited FROM model_tests mt ORDER BY mt.id DESC"
        };
        $learning=$pdo->query($sql." LIMIT 26 OFFSET ".$learningOffset)->fetchAll(PDO::FETCH_ASSOC);$learningMore=count($learning)>25;if($learningMore)array_pop($learning);
        $plans=$pdo->query('SELECT * FROM premium_plans ORDER BY months')->fetchAll(PDO::FETCH_ASSOC);
        $members=$pdo->query("SELECT m.user_id,u.full_name,m.expires_at,(m.expires_at>UTC_TIMESTAMP()) AS active FROM premium_memberships m JOIN users u ON u.id=m.user_id ORDER BY m.updated_at DESC LIMIT 50")->fetchAll(PDO::FETCH_ASSOC);
        $events=$pdo->query('SELECT user_id,action,expires_at,reason,created_at FROM premium_membership_events ORDER BY id DESC LIMIT 50')->fetchAll(PDO::FETCH_ASSOC);
        $offset=($page-1)*30;
        $items=$pdo->query("SELECT c.id,c.title,c.is_published,(p.content_id IS NOT NULL) AS locked FROM homepage_content c LEFT JOIN premium_interview_items p ON p.content_id=c.id WHERE c.kind='interview' ORDER BY c.id DESC LIMIT 31 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
        $more=count($items)>30;if($more)array_pop($items);
    }
}catch(Throwable $e){$ready=false;error_log('Premium admin: '.$e->getMessage());}
function pm_csrf():void{?><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><?php }
$nav=[
 ['fire_safety_job_prep_dashboard.php','▦','ড্যাশবোর্ড'],['questions.php','ⓘ','প্রশ্ন ব্যাংক'],['model_tests.php','☑','মডেল টেস্ট'],['notes.php','◫','নোট'],['job_circulars.php','▣','চাকরির সার্কুলার'],
 ['fire_safety_job_prep_dashboard.php?section=marketplace','🛒','মার্কেটপ্লেস'],['category_management.php','⊞','ক্যাটাগরি'],['users.php','♙','ব্যবহারকারী'],['homepage_admin.php','⌂','হোমপেজ ব্যবস্থাপনা'],['interview_admin.php','▤','ইন্টারভিউ ব্যবস্থাপনা'],
 ['notifications_admin.php','♧','নোটিফিকেশন'],['fire_safety_job_prep_dashboard.php?section=community','▱','কমিউনিটি'],['settings_admin.php','☼','সেটিংস'],['analytics_admin.php','▥','অ্যানালিটিক্স'],['premium_admin.php','♛','প্রিমিয়াম ব্যবস্থাপনা'],['ads_admin.php','▧','বিজ্ঞাপন ব্যবস্থাপনা'],['support_admin.php','✉','গ্রাহক সহায়তা'],['logout.php','↪','লগ আউট']
];
function pm_nav(array $nav,string $url):void{?><nav class="pm-nav" aria-label="অ্যাডমিন মেনু"><?php foreach($nav as [$link,$icon,$name]):?><a href="<?=h($link)?>" class="<?=$link===$url?'active':''?>" <?=$link===$url?'aria-current="page"':''?>><span aria-hidden="true"><?=h($icon)?></span> <?=h($name)?></a><?php endforeach;?></nav><?php }
?><!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title><?=h($title)?> | Fire Safety BD</title>
<link rel="stylesheet" href="assets/admin-unified.css"><style>
*{box-sizing:border-box}body{margin:0;background:#fff8f5;color:#30191b;font:15px/1.65 system-ui,"Noto Sans Bengali",Arial,sans-serif}a{text-decoration:none;color:inherit}.pm-layout{display:grid;grid-template-columns:260px minmax(0,1fr);min-height:100vh;align-items:start}.pm-side{background:linear-gradient(#450b15,#6a111f);color:white;min-height:100vh;padding:20px 13px}.pm-brand{display:flex;gap:12px;align-items:center;padding:8px 4px 22px}.pm-brand img{width:52px;height:52px;border:2px solid white;border-radius:12px;object-fit:contain}.pm-brand strong{font-size:19px}.pm-brand small{display:block;color:#e0bfc2}.pm-nav{display:grid;gap:4px}.pm-nav a{padding:11px 13px;border-radius:12px;display:flex;gap:11px;align-items:center}.pm-nav a:hover{background:#ffffff20}.pm-nav a.active{background:#ffa400;color:#30191b;font-weight:800}.pm-main{min-width:0;width:100%;max-width:1400px;margin:0 auto;padding:26px clamp(14px,3vw,40px)}.pm-main h1{margin:0;color:#510d18;font-size:clamp(24px,3vw,34px)}.pm-main h2{font-size:20px;color:#510d18;margin:0 0 12px}.pm-panel{padding:20px;border:1px solid #eadbd5;border-radius:18px;background:white;margin:18px 0;box-shadow:0 5px 20px #450b1509}.pm-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.pm-fields{display:grid;gap:12px}.pm-fields label{display:block;font-weight:650}.pm-fields input:not([type=checkbox]),.pm-fields select{display:block;width:100%;padding:11px;border:1px solid #e5d2cc;border-radius:10px;background:#fdfaf9;font:inherit}.pm-fields input[type=checkbox]{accent-color:#650d18}.pm-main button{border:0;border-radius:10px;background:#650d18;color:white;padding:10px 16px;font:inherit;font-weight:700;cursor:pointer}.pm-main button.danger{background:#a12635}.pm-muted{color:#776468}.pm-note{background:#fff4db;padding:12px;border-radius:12px;border:1px solid #ead4aa}.pm-scroll{overflow-x:auto}.pm-scroll table{border-collapse:collapse;width:100%;font-size:14px}.pm-scroll th,.pm-scroll td{padding:10px;border-bottom:1px solid #eee1dc;text-align:left;vertical-align:top;overflow-wrap:anywhere}.pm-scroll th{background:#faf1ec}.pm-mobile{display:none}.pm-crumb{font-size:13px;color:#776468}@media(max-width:900px){.pm-layout{display:block}.pm-side{display:none}.pm-mobile{display:block;background:#510d18;color:white;border-radius:12px;padding:12px;margin-bottom:14px}.pm-mobile summary{cursor:pointer}.pm-mobile .pm-nav{margin-top:10px}}@media(max-width:600px){.pm-grid{grid-template-columns:1fr}.pm-panel{padding:14px}}
</style></head><body><div class="pm-layout"><aside class="pm-side"><a class="pm-brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png?v=177" alt="Fire Safety BD"><span><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></span></a><?php pm_nav($nav,$url);?></aside>
<main class="pm-main"><details class="pm-mobile"><summary>☰ Fire Safety BD · অ্যাডমিন মেনু</summary><?php pm_nav($nav,$url);?></details><p class="pm-crumb"><a href="fire_safety_job_prep_dashboard.php">ড্যাশবোর্ড</a> / <?=h($title)?></p><h1><?=h($title)?></h1>
<?php if($flash!==''):?><p class="pm-note" role="status"><?=h($flash)?></p><?php endif;?>
<?php if(!$ready):?><p class="pm-note">প্রিমিয়াম মাইগ্রেশন সম্পন্ন করুন।</p><?php elseif($isAds):?>
<section class="pm-panel"><h2>বিজ্ঞাপনের পরিকল্পিত নিয়ন্ত্রণ</h2><p class="pm-note">AdMob SDK এখনো সংযুক্ত হয়নি। নিচের সেটিংস সংরক্ষিত হবে, কিন্তু কোনো বিজ্ঞাপন এখন প্রদর্শিত হবে না। প্রিমিয়াম সদস্যদের বিজ্ঞাপন দেখানো হবে না।</p>
<form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="ads">
<?php foreach(['ads_requested'=>'বিজ্ঞাপন চালুর অনুরোধ','home_native'=>'হোমপেজ Native Ad','question_native'=>'প্রশ্ন তালিকা Native Ad','results_interstitial'=>'ফলাফলের পর Interstitial','rewarded'=>'ঐচ্ছিক Rewarded Ad'] as $k=>$label):?><label><input type="checkbox" name="<?=h($k)?>" value="1" <?=!empty($ads[$k])?'checked':''?>> <?=h($label)?></label><?php endforeach;?>
<label>দৈনিক Full-screen বিজ্ঞাপনের সীমা (০–২)<input type="number" name="daily_fullscreen_limit" min="0" max="2" value="<?=(int)$ads['daily_fullscreen_limit']?>" required></label><button>পরিকল্পনা সংরক্ষণ করুন</button></form></section>
<section class="pm-panel"><h2>AdMob আইডি (পরবর্তীতে)</h2><p class="pm-muted">শুধু আইডি সংরক্ষণ হবে। SDK বন্ধ আছে।</p><form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="integration"><?php foreach(['admob_app_id'=>'AdMob App ID','home_native_id'=>'Home Native Ad Unit ID','question_native_id'=>'Question Native Ad Unit ID','interstitial_id'=>'Interstitial Ad Unit ID','rewarded_id'=>'Rewarded Ad Unit ID'] as $k=>$label):?><label><?=h($label)?><input name="<?=h($k)?>" maxlength="100" value="<?=h($integration[$k])?>"></label><?php endforeach;?><button>আইডি সংরক্ষণ</button></form></section>
<?php else:?>
<p class="pm-note">এই ধাপে শুধু পরীক্ষামূলক/সৌজন্যমূলক সদস্যপদ। Google Play Billing যাচাই না হওয়া পর্যন্ত কেনাকাটা বন্ধ। কোনো টাকা গ্রহণ বা বিক্রয় রেকর্ড করা হচ্ছে না।</p>
<section class="pm-panel"><h2>Global Access Control</h2><?php $policyLabels=['free'=>'সম্পূর্ণ Free','selected'=>'নির্বাচিত Premium লক','all'=>'সব সুরক্ষাযোগ্য শিক্ষামূলক কনটেন্ট লক'];$pending=$policy['mode']!==$policy['effective_mode'];$localStart=$policy['starts_at']!==null?(new DateTimeImmutable($policy['starts_at'],new DateTimeZone('UTC')))->setTimezone(new DateTimeZone('Asia/Dhaka'))->format('Y-m-d\\TH:i'):'';?><p><strong>বর্তমান মোড: <?=h($policyLabels[$policy['effective_mode']])?></strong></p><?php if($pending):?><p class="pm-note">নির্ধারিত মোড: <?=h($policyLabels[$policy['mode']])?> · <?=h(str_replace('T',' ',$localStart))?> (বাংলাদেশ সময়)</p><?php endif;?><p class="pm-muted">Free মোডে আগে চিহ্নিত Premium কনটেন্টও খোলা থাকবে। নির্বাচিত মোডে আগের মার্কিং কার্যকর হবে। All মোডে সব নতুন প্রশ্ন, নোট, ইন্টারভিউ ও মডেল টেস্ট লক হবে; পুরোনো পাবলিক ফাইল/মিডিয়া নোট, আগের ফলাফল, মৌলিক প্রস্তুতি রিপোর্ট, চাকরি, জরুরি টিপস, কমিউনিটি ও শপ ফ্রি থাকবে।</p><form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="global_access"><label>মোড<select name="mode"><?php foreach($policyLabels as $key=>$name):?><option value="<?=h($key)?>" <?=$policy['mode']===$key?'selected':''?>><?=h($name)?></option><?php endforeach;?></select></label><label>লক শুরুর সময় (বাংলাদেশ সময়, ঐচ্ছিক)<input type="datetime-local" name="starts_at" value="<?=h($pending?$localStart:'')?>"></label><small>সময় খালি রাখলে এখনই কার্যকর। ভবিষ্যতের সময় পর্যন্ত Free থাকবে।</small><label><input type="checkbox" name="confirm" value="1"> লক চালু করার প্রভাব বুঝেছি; পেমেন্ট বর্তমানে নিষ্ক্রিয়।</label><button>মোড সংরক্ষণ</button></form><form method="post" style="margin-top:14px"><?php pm_csrf();?><input type="hidden" name="action" value="global_access"><input type="hidden" name="mode" value="free"><button>এখনই সব Free করুন / শিডিউল বাতিল</button></form></section>
<section class="pm-panel"><h2>সদস্যপদের রিপোর্ট</h2><div class="pm-grid"><div>মোট সদস্যপদ: <strong><?=(int)$memberStats['total']?></strong></div><div>সক্রিয়: <strong><?=(int)$memberStats['active']?></strong></div><div>মেয়াদ শেষ: <strong><?=(int)$memberStats['expired']?></strong></div></div><p class="pm-muted">এটি সৌজন্যমূলক/পরীক্ষামূলক সদস্যপদ। যাচাইকৃত বিক্রয় বা আয়ের তথ্য এখন নেই।</p></section>
<section class="pm-panel"><h2>Google Play Billing — নিষ্ক্রিয়</h2><p class="pm-muted">শুধু Product ID সংরক্ষণ। কোনো পেমেন্ট চালু হবে না।</p><form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="integration"><?php foreach(['monthly_product_id'=>'Monthly Product ID','quarterly_product_id'=>'Quarterly Product ID','annual_product_id'=>'Annual Product ID'] as $k=>$label):?><label><?=h($label)?><input name="<?=h($k)?>" maxlength="150" value="<?=h($integration[$k])?>"></label><?php endforeach;?><button>আইডি সংরক্ষণ</button></form></section>
<section class="pm-panel"><h2>প্রশ্ন / নোট / মডেল টেস্ট — Free / Premium</h2><p class="pm-muted">সব কনটেন্ট শুরুতে Free। পুরোনো পাবলিক PDF বা লিংকসহ নোট লক করা যাবে না। জরুরি নিরাপত্তা নির্দেশনা Free রাখুন। Premium প্রশ্ন যুক্ত টেস্ট স্বয়ংক্রিয়ভাবে Premium হবে। চলমান পরীক্ষার ফলাফল অক্ষত থাকবে।</p><div class="pm-grid"><a href="?learning_type=question">প্রশ্ন ব্যাংক</a><a href="?learning_type=note">স্টাডি নোট</a><a href="?learning_type=test">মডেল টেস্ট</a></div><p>নির্বাচিত: <?=h($learningType)?></p><div class="pm-scroll"><table><thead><tr><th>ID</th><th>কনটেন্ট</th><th>অবস্থা</th><th>অ্যাক্সেস</th></tr></thead><tbody><?php foreach($learning as $item):?><tr><td><?=h((string)$item['id'])?></td><td><?=h($item['title'])?></td><td><?=h($item['status'])?></td><td><form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="learning"><input type="hidden" name="type" value="<?=h($learningType)?>"><input type="hidden" name="content_id" value="<?=h((string)$item['id'])?>"><select name="locked"><option value="0" <?=$item['marked']?'':'selected'?>>Free</option><option value="1" <?=$item['marked']?'selected':''?>>Premium</option></select><?php if($learningType==='test'&&!$item['marked']&&$item['inherited']):?><small>Premium প্রশ্ন থাকার কারণে লক</small><?php endif;?><button>সংরক্ষণ</button></form><?php if($learningType==='note'&&$item['marked']):?><form method="post" enctype="multipart/form-data" class="pm-fields" style="margin-top:12px"><?php pm_csrf();?><input type="hidden" name="action" value="private_pdf"><input type="hidden" name="content_id" value="<?=h((string)$item['id'])?>"><label><?=$item['private_pdf']?'নতুন PDF দিয়ে প্রতিস্থাপন':'Private PDF (সর্বোচ্চ ১০ MB)'?><input type="file" name="private_pdf" accept="application/pdf,.pdf" required></label><button>সুরক্ষিত PDF আপলোড</button></form><?php endif;?></td></tr><?php endforeach;?></tbody></table></div><?php if(!$learning):?><p>কোনো কনটেন্ট নেই।</p><?php endif;?><?php if($learningPage>1):?><a href="?learning_type=<?=h($learningType)?>&amp;learning_page=<?=$learningPage-1?>">আগের পেজ</a> <?php endif;?><?php if($learningMore):?><a href="?learning_type=<?=h($learningType)?>&amp;learning_page=<?=$learningPage+1?>">পরের পেজ</a><?php endif;?></section>
<div class="pm-grid"><section class="pm-panel"><h2>সদস্যপদ প্রদান / বাতিল</h2><form method="post" class="pm-fields"><?php pm_csrf();?>
<label>নিবন্ধিত ব্যবহারকারীর আইডি<input name="user_id" type="number" min="1" required></label><label>মেয়াদ (আজ থেকে ১–৩৬৫ দিন)<input name="days" type="number" min="1" max="365" value="30"></label>
<label>কারণ<input name="reason" maxlength="240" required></label><label><input type="checkbox" name="confirm" value="1" required> মেয়াদ নতুন করে নির্ধারণ বা বাতিল করার অনুমোদন দিচ্ছি।</label>
<div><button name="action" value="grant">সদস্যপদ দিন</button> <button class="danger" name="action" value="revoke">বাতিল করুন</button></div></form></section>
<section class="pm-panel"><h2>প্রস্তাবিত প্যাকেজ মূল্য</h2><p class="pm-muted">মূল্য শুধু পরিকল্পনার জন্য; Play Store মূল্য নয়।</p><?php foreach($plans as $p):?><form class="pm-fields" method="post"><?php pm_csrf();?><input type="hidden" name="action" value="plan"><input type="hidden" name="code" value="<?=h($p['code'])?>"><label><?=(int)$p['months']?> মাস (টাকা)<input name="price" type="number" min="1" max="100000" value="<?=(int)$p['proposed_price_bdt']?>" required></label><button>মূল্য সংরক্ষণ</button></form><br><?php endforeach;?></section></div>
<section class="pm-panel"><h2>ইন্টারভিউ: Free / Premium</h2><p class="pm-muted">চিহ্নিত প্রশ্নগুলো নির্বাচিত লক মোডে Premium হবে। Free মোডে সব উত্তর খোলা থাকবে।</p><div class="pm-scroll"><table><thead><tr><th>আইডি</th><th>প্রশ্ন</th><th>অবস্থা</th><th>অ্যাক্সেস</th></tr></thead><tbody><?php foreach($items as $p):?><tr><td><?=(int)$p['id']?></td><td><?=h($p['title'])?></td><td><?=$p['is_published']?'প্রকাশিত':'ড্রাফট'?></td><td><form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="interview"><input type="hidden" name="content_id" value="<?=(int)$p['id']?>"><select name="locked"><option value="0" <?=$p['locked']?'':'selected'?>>Free</option><option value="1" <?=$p['locked']?'selected':''?>>Premium</option></select><button>সংরক্ষণ</button></form></td></tr><?php endforeach;?></tbody></table></div><?php if(!$items):?><p>কোনো ইন্টারভিউ প্রশ্ন নেই।</p><?php endif;?><?php if($page>1):?><a href="?page=<?=$page-1?>">আগের পেজ</a> <?php endif;?><?php if($more):?><a href="?page=<?=$page+1?>">পরের পেজ</a><?php endif;?></section>
<section class="pm-panel"><h2>সাম্প্রতিক সদস্যপদ (৫০)</h2><div class="pm-scroll"><table><thead><tr><th>আইডি</th><th>নাম</th><th>মেয়াদ (UTC)</th><th>অবস্থা</th></tr></thead><tbody><?php foreach($members as $m):?><tr><td><?=(int)$m['user_id']?></td><td><?=h($m['full_name'])?></td><td><?=h($m['expires_at'])?></td><td><?=$m['active']?'সক্রিয়':'মেয়াদ শেষ'?></td></tr><?php endforeach;?></tbody></table></div><?php if(!$members):?><p>কোনো সদস্য নেই।</p><?php endif;?></section>
<section class="pm-panel"><h2>সাম্প্রতিক সদস্যপদ কার্যক্রম (৫০)</h2><div class="pm-scroll"><table><thead><tr><th>ব্যবহারকারী</th><th>কাজ</th><th>কারণ</th><th>সময় (UTC)</th></tr></thead><tbody><?php foreach($events as $e):?><tr><td><?=(int)$e['user_id']?></td><td><?=h($e['action'])?></td><td><?=h($e['reason'])?></td><td><?=h($e['created_at'])?></td></tr><?php endforeach;?></tbody></table></div><?php if(!$events):?><p>কোনো কার্যক্রম নেই।</p><?php endif;?></section>
<?php endif;?></main></div></body></html>
