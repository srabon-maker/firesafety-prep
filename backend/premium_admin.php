<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';
require_admin();
require_once __DIR__.'/db.php';
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
    try{
        $action=$_POST['action']??'';
        if($isAds&&$action==='ads'){
            $flags=[];foreach(['ads_requested','home_native','question_native','results_interstitial','rewarded'] as $k)$flags[]=($_POST[$k]??'')==='1'?1:0;
            $limit=pm_id($_POST['daily_fullscreen_limit']??null,0,2);
            $q=$pdo->prepare('UPDATE premium_ads_settings SET ads_requested=?,home_native=?,question_native=?,results_interstitial=?,rewarded=?,daily_fullscreen_limit=? WHERE id=1');
            $q->execute([...$flags,$limit]);
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
        if($pdo->inTransaction())$pdo->rollBack();
        if(!($e instanceof DomainException))error_log('Premium admin: '.$e->getMessage());
        $_SESSION[$flashKey]=$e instanceof DomainException?$e->getMessage():'সংরক্ষণ হয়নি। মাইগ্রেশন ও সার্ভার লগ পরীক্ষা করুন।';
    }
    header('Location: '.$url,true,303);exit;
}
$flash=$_SESSION[$flashKey]??'';unset($_SESSION[$flashKey]);$ready=true;$plans=[];$members=[];$events=[];$items=[];$ads=[];$more=false;
$page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;
try{
    if($isAds){$ads=$pdo->query('SELECT * FROM premium_ads_settings WHERE id=1')->fetch(PDO::FETCH_ASSOC);if(!$ads)throw new RuntimeException('Missing settings');}
    else{
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
 ['notifications_admin.php','♧','নোটিফিকেশন'],['fire_safety_job_prep_dashboard.php?section=community','▱','কমিউনিটি'],['settings_admin.php','☼','সেটিংস'],['analytics_admin.php','▥','অ্যানালিটিক্স'],['premium_admin.php','♛','প্রিমিয়াম ব্যবস্থাপনা'],['ads_admin.php','▧','বিজ্ঞাপন ব্যবস্থাপনা'],['logout.php','↪','লগ আউট']
];
function pm_nav(array $nav,string $url):void{?><nav class="pm-nav" aria-label="অ্যাডমিন মেনু"><?php foreach($nav as [$link,$icon,$name]):?><a href="<?=h($link)?>" class="<?=$link===$url?'active':''?>" <?=$link===$url?'aria-current="page"':''?>><span aria-hidden="true"><?=h($icon)?></span> <?=h($name)?></a><?php endforeach;?></nav><?php }
?><!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title><?=h($title)?> | Fire Safety BD</title>
<link rel="stylesheet" href="assets/admin-unified.css"><style>
*{box-sizing:border-box}body{margin:0;background:#fff8f5;color:#30191b;font:15px/1.65 system-ui,"Noto Sans Bengali",Arial,sans-serif}a{text-decoration:none;color:inherit}.pm-layout{display:grid;grid-template-columns:260px minmax(0,1fr);min-height:100vh;align-items:start}.pm-side{background:linear-gradient(#450b15,#6a111f);color:white;min-height:100vh;padding:20px 13px}.pm-brand{display:flex;gap:12px;align-items:center;padding:8px 4px 22px}.pm-brand img{width:52px;height:52px;border:2px solid white;border-radius:12px;object-fit:contain}.pm-brand strong{font-size:19px}.pm-brand small{display:block;color:#e0bfc2}.pm-nav{display:grid;gap:4px}.pm-nav a{padding:11px 13px;border-radius:12px;display:flex;gap:11px;align-items:center}.pm-nav a:hover{background:#ffffff20}.pm-nav a.active{background:#ffa400;color:#30191b;font-weight:800}.pm-main{min-width:0;width:100%;max-width:1400px;margin:0 auto;padding:26px clamp(14px,3vw,40px)}.pm-main h1{margin:0;color:#510d18;font-size:clamp(24px,3vw,34px)}.pm-main h2{font-size:20px;color:#510d18;margin:0 0 12px}.pm-panel{padding:20px;border:1px solid #eadbd5;border-radius:18px;background:white;margin:18px 0;box-shadow:0 5px 20px #450b1509}.pm-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.pm-fields{display:grid;gap:12px}.pm-fields label{display:block;font-weight:650}.pm-fields input:not([type=checkbox]),.pm-fields select{display:block;width:100%;padding:11px;border:1px solid #e5d2cc;border-radius:10px;background:#fdfaf9;font:inherit}.pm-fields input[type=checkbox]{accent-color:#650d18}.pm-main button{border:0;border-radius:10px;background:#650d18;color:white;padding:10px 16px;font:inherit;font-weight:700;cursor:pointer}.pm-main button.danger{background:#a12635}.pm-muted{color:#776468}.pm-note{background:#fff4db;padding:12px;border-radius:12px;border:1px solid #ead4aa}.pm-scroll{overflow-x:auto}.pm-scroll table{border-collapse:collapse;width:100%;font-size:14px}.pm-scroll th,.pm-scroll td{padding:10px;border-bottom:1px solid #eee1dc;text-align:left;vertical-align:top;overflow-wrap:anywhere}.pm-scroll th{background:#faf1ec}.pm-mobile{display:none}.pm-crumb{font-size:13px;color:#776468}@media(max-width:900px){.pm-layout{display:block}.pm-side{display:none}.pm-mobile{display:block;background:#510d18;color:white;border-radius:12px;padding:12px;margin-bottom:14px}.pm-mobile summary{cursor:pointer}.pm-mobile .pm-nav{margin-top:10px}}@media(max-width:600px){.pm-grid{grid-template-columns:1fr}.pm-panel{padding:14px}}
</style></head><body><div class="pm-layout"><aside class="pm-side"><a class="pm-brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD"><span><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></span></a><?php pm_nav($nav,$url);?></aside>
<main class="pm-main"><details class="pm-mobile"><summary>☰ Fire Safety BD · অ্যাডমিন মেনু</summary><?php pm_nav($nav,$url);?></details><p class="pm-crumb"><a href="fire_safety_job_prep_dashboard.php">ড্যাশবোর্ড</a> / <?=h($title)?></p><h1><?=h($title)?></h1>
<?php if($flash!==''):?><p class="pm-note" role="status"><?=h($flash)?></p><?php endif;?>
<?php if(!$ready):?><p class="pm-note">প্রিমিয়াম মাইগ্রেশন সম্পন্ন করুন।</p><?php elseif($isAds):?>
<section class="pm-panel"><h2>বিজ্ঞাপনের পরিকল্পিত নিয়ন্ত্রণ</h2><p class="pm-note">AdMob SDK এখনো সংযুক্ত হয়নি। নিচের সেটিংস সংরক্ষিত হবে, কিন্তু কোনো বিজ্ঞাপন এখন প্রদর্শিত হবে না। প্রিমিয়াম সদস্যদের বিজ্ঞাপন দেখানো হবে না।</p>
<form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="ads">
<?php foreach(['ads_requested'=>'বিজ্ঞাপন চালুর অনুরোধ','home_native'=>'হোমপেজ Native Ad','question_native'=>'প্রশ্ন তালিকা Native Ad','results_interstitial'=>'ফলাফলের পর Interstitial','rewarded'=>'ঐচ্ছিক Rewarded Ad'] as $k=>$label):?><label><input type="checkbox" name="<?=h($k)?>" value="1" <?=!empty($ads[$k])?'checked':''?>> <?=h($label)?></label><?php endforeach;?>
<label>দৈনিক Full-screen বিজ্ঞাপনের সীমা (০–২)<input type="number" name="daily_fullscreen_limit" min="0" max="2" value="<?=(int)$ads['daily_fullscreen_limit']?>" required></label><button>পরিকল্পনা সংরক্ষণ করুন</button></form></section>
<?php else:?>
<p class="pm-note">এই ধাপে শুধু পরীক্ষামূলক/সৌজন্যমূলক সদস্যপদ। Google Play Billing যাচাই না হওয়া পর্যন্ত কেনাকাটা বন্ধ। কোনো টাকা গ্রহণ বা বিক্রয় রেকর্ড করা হচ্ছে না।</p>
<div class="pm-grid"><section class="pm-panel"><h2>সদস্যপদ প্রদান / বাতিল</h2><form method="post" class="pm-fields"><?php pm_csrf();?>
<label>নিবন্ধিত ব্যবহারকারীর আইডি<input name="user_id" type="number" min="1" required></label><label>মেয়াদ (আজ থেকে ১–৩৬৫ দিন)<input name="days" type="number" min="1" max="365" value="30"></label>
<label>কারণ<input name="reason" maxlength="240" required></label><label><input type="checkbox" name="confirm" value="1" required> মেয়াদ নতুন করে নির্ধারণ বা বাতিল করার অনুমোদন দিচ্ছি।</label>
<div><button name="action" value="grant">সদস্যপদ দিন</button> <button class="danger" name="action" value="revoke">বাতিল করুন</button></div></form></section>
<section class="pm-panel"><h2>প্রস্তাবিত প্যাকেজ মূল্য</h2><p class="pm-muted">মূল্য শুধু পরিকল্পনার জন্য; Play Store মূল্য নয়।</p><?php foreach($plans as $p):?><form class="pm-fields" method="post"><?php pm_csrf();?><input type="hidden" name="action" value="plan"><input type="hidden" name="code" value="<?=h($p['code'])?>"><label><?=(int)$p['months']?> মাস (টাকা)<input name="price" type="number" min="1" max="100000" value="<?=(int)$p['proposed_price_bdt']?>" required></label><button>মূল্য সংরক্ষণ</button></form><br><?php endforeach;?></section></div>
<section class="pm-panel"><h2>ইন্টারভিউ: Free / Premium</h2><p class="pm-muted">চিহ্নিত প্রশ্নের উত্তর শুধু সক্রিয় Premium সদস্য পাবেন। পুরোনো অ্যাপ শুধু Free প্রশ্ন দেখাবে।</p><div class="pm-scroll"><table><thead><tr><th>আইডি</th><th>প্রশ্ন</th><th>অবস্থা</th><th>অ্যাক্সেস</th></tr></thead><tbody><?php foreach($items as $p):?><tr><td><?=(int)$p['id']?></td><td><?=h($p['title'])?></td><td><?=$p['is_published']?'প্রকাশিত':'ড্রাফট'?></td><td><form method="post" class="pm-fields"><?php pm_csrf();?><input type="hidden" name="action" value="interview"><input type="hidden" name="content_id" value="<?=(int)$p['id']?>"><select name="locked"><option value="0" <?=$p['locked']?'':'selected'?>>Free</option><option value="1" <?=$p['locked']?'selected':''?>>Premium</option></select><button>সংরক্ষণ</button></form></td></tr><?php endforeach;?></tbody></table></div><?php if(!$items):?><p>কোনো ইন্টারভিউ প্রশ্ন নেই।</p><?php endif;?><?php if($page>1):?><a href="?page=<?=$page-1?>">আগের পেজ</a> <?php endif;?><?php if($more):?><a href="?page=<?=$page+1?>">পরের পেজ</a><?php endif;?></section>
<section class="pm-panel"><h2>সাম্প্রতিক সদস্যপদ (৫০)</h2><div class="pm-scroll"><table><thead><tr><th>আইডি</th><th>নাম</th><th>মেয়াদ (UTC)</th><th>অবস্থা</th></tr></thead><tbody><?php foreach($members as $m):?><tr><td><?=(int)$m['user_id']?></td><td><?=h($m['full_name'])?></td><td><?=h($m['expires_at'])?></td><td><?=$m['active']?'সক্রিয়':'মেয়াদ শেষ'?></td></tr><?php endforeach;?></tbody></table></div><?php if(!$members):?><p>কোনো সদস্য নেই।</p><?php endif;?></section>
<section class="pm-panel"><h2>সাম্প্রতিক সদস্যপদ কার্যক্রম (৫০)</h2><div class="pm-scroll"><table><thead><tr><th>ব্যবহারকারী</th><th>কাজ</th><th>কারণ</th><th>সময় (UTC)</th></tr></thead><tbody><?php foreach($events as $e):?><tr><td><?=(int)$e['user_id']?></td><td><?=h($e['action'])?></td><td><?=h($e['reason'])?></td><td><?=h($e['created_at'])?></td></tr><?php endforeach;?></tbody></table></div><?php if(!$events):?><p>কোনো কার্যক্রম নেই।</p><?php endif;?></section>
<?php endif;?></main></div></body></html>
