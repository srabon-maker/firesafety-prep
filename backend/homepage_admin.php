<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';
require_admin();
require_once __DIR__.'/homepage_image_upload.php';
require_once __DIR__.'/db.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$sections=['banners'=>'ব্যানার','progress'=>'দৈনিক প্রস্তুতি','jobs'=>'চাকরি','topics'=>'বিষয়ভিত্তিক প্রস্তুতি','notes'=>'নতুন নোট','marketplace'=>'মার্কেটপ্লেস','community'=>'কমিউনিটি','tips'=>'সেফটি টিপস'];
// Only the interview entry point may select interview mode; never trust request parameters.
$isInterview=defined('FSBD_INTERVIEW_ADMIN') && FSBD_INTERVIEW_ADMIN===true;
$pageTitle=$isInterview?'ইন্টারভিউ ব্যবস্থাপনা':'হোমপেজ ব্যবস্থাপনা';
$pageUrl=$isInterview?'interview_admin.php':'homepage_admin.php';
$flashKey=$isInterview?'interview_admin_flash':'homepage_flash';
$kinds=$isInterview?['interview'=>'ইন্টারভিউ']:['banner'=>'ব্যানার / ঘোষণা','tip'=>'সেফটি টিপস'];
$scope=$isInterview?"kind='interview'":"kind IN ('banner','tip')";
$targets=['none','jobs','notes','questions','tests','interview','progress','shop','community'];
function hp_field(string $key,int $max,bool $required=false): string {
    $v=$_POST[$key]??'';
    if (!is_string($v)||!preg_match('//u',$v)) throw new DomainException('সঠিক লেখা দিন।');
    $v=trim($v);
    if (($required&&$v==='')||mb_strlen($v,'UTF-8')>$max) throw new DomainException('লেখার দৈর্ঘ্য সঠিক নয়।');
    return $v;
}
function hp_id(mixed $v,int $min=0): int {
    $n=filter_var($v,FILTER_VALIDATE_INT,['options'=>['min_range'=>$min]]);
    if ($n===false) throw new DomainException('আইডি সঠিক নয়।');
    return $n;
}
if (($_SERVER['REQUEST_METHOD']??'GET')==='POST') {
    verify_csrf();
    $newUpload=null;
    try {
        if (($_POST['action']??'')==='settings' && !$isInterview) {
            $raw=hp_field('section_order',180);
            $order=$raw===''?[]:array_map('trim',explode(',',$raw));
            if (array_diff($order,array_keys($sections))||count($order)!==count(array_unique($order))) throw new DomainException('সেকশনের নাম বা ক্রম সঠিক নয়।');
            $q=$pdo->prepare('UPDATE homepage_settings SET section_order=? WHERE id=1');
            $q->execute([implode(',',$order)]);
        } elseif (($_POST['action']??'')==='save') {
            $id=hp_id($_POST['id']??0);
            $kind=hp_field('kind',20,true); if(!isset($kinds[$kind])) throw new DomainException('কনটেন্টের ধরন সঠিক নয়।');
            if ($id>0) {
                $existing=$pdo->prepare("SELECT id FROM homepage_content WHERE id=? AND $scope");
                $existing->execute([$id]);
                if ($existing->fetchColumn()===false) throw new DomainException('এই বিভাগে সম্পাদনার কনটেন্ট পাওয়া যায়নি।');
            }
            $title=hp_field('title',240,true); $body=hp_field('body',4000,true);
            $titleEn=hp_field('title_en',240); $bodyEn=hp_field('body_en',4000);
            if (($titleEn==='')!==($bodyEn==='')) throw new DomainException('ইংরেজি শিরোনাম ও বিস্তারিত একসঙ্গে দিন।');
            $role=$kind==='interview'?hp_field('role_name',100,true):'';
            $industry=$kind==='interview'?hp_field('industry',100):'';
            $difficulty=$isInterview?hp_field('difficulty',20,true):'basic';
            if(!in_array($difficulty,['basic','intermediate','advanced'],true)) throw new DomainException('লেভেল সঠিক নয়।');
            $target=$kind==='interview'?'none':hp_field('target',20,true);
            if(!in_array($target,$targets,true)) throw new DomainException('লিংক সঠিক নয়।');
            $image=$kind==='banner'?hp_field('image_url',500):'';
            if($image!==''&&!preg_match('~^https://fire\.manobikishwarganj\.com/uploads/[A-Za-z0-9/_-]+\.(?:png|jpe?g|webp)$~D',$image)) throw new DomainException('শুধু নিজের সাইটের uploads ফোল্ডারের PNG/JPG/WebP URL দিন।');
            $sort=hp_id($_POST['sort_order']??100); if($sort>10000) throw new DomainException('ক্রম ০–১০০০০ দিন।');
            $published=($_POST['is_published']??'')==='1'?1:0;
            if (isset($_FILES['banner_image']) && !is_array($_FILES['banner_image'])) throw new DomainException('ছবির তথ্য সঠিক নয়।');
            $upload=$_FILES['banner_image']??[];
            if ($kind!=='banner' && ($upload['error']??UPLOAD_ERR_NO_FILE)!==UPLOAD_ERR_NO_FILE) throw new DomainException('ছবি শুধু ব্যানারের জন্য দেওয়া যাবে।');
            if ($kind==='banner') {
                $newUpload=hp_store_banner_image($upload,__DIR__.'/uploads/homepage');
                if ($newUpload!==null) $image=$newUpload['url'];
            }
            $args=[$kind,$title,$body,$titleEn,$bodyEn,$role,$industry,$difficulty,$target,$image,$sort,$published];
            if ($id>0) {
                $q=$pdo->prepare("UPDATE homepage_content SET kind=?,title=?,body=?,title_en=?,body_en=?,role_name=?,industry=?,difficulty=?,target=?,image_url=?,sort_order=?,is_published=? WHERE id=? AND $scope");
                $q->execute([...$args,$id]);
                if ($newUpload!==null && $q->rowCount()!==1) throw new DomainException('সম্পাদনার ব্যানার পাওয়া যায়নি।');
            } else {
                $q=$pdo->prepare('INSERT INTO homepage_content (kind,title,body,title_en,body_en,role_name,industry,difficulty,target,image_url,sort_order,is_published) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)');
                $q->execute($args);
            }
        } else throw new DomainException('অনুরোধ সঠিক নয়।');
        $newUpload=null; // Database now references the new image.
        $_SESSION[$flashKey]='সংরক্ষণ হয়েছে।';
    } catch(DomainException $e) {if($newUpload!==null) @unlink($newUpload['path']); $_SESSION[$flashKey]=$e->getMessage();}
    catch(Throwable $e) {if($newUpload!==null) @unlink($newUpload['path']); error_log('Homepage admin: '.$e->getMessage());$_SESSION[$flashKey]='সংরক্ষণ করা যায়নি। মাইগ্রেশন বা আপলোড সেটিংস পরীক্ষা করুন।';}
    header('Location: '.$pageUrl,true,303); exit;
}
$flash=$_SESSION[$flashKey]??''; unset($_SESSION[$flashKey]);
$ready=true; $rows=[]; $order=''; $edit=[];
$page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;
try {
    if (!$isInterview) {
        $order=$pdo->query('SELECT section_order FROM homepage_settings WHERE id=1')->fetchColumn();
        if($order===false) throw new RuntimeException('Migration missing');
    }
    $offset=($page-1)*30;
    $rows=$pdo->query("SELECT * FROM homepage_content WHERE $scope ORDER BY id DESC LIMIT 31 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
    $id=hp_id($_GET['edit']??0);
    if($id>0){$q=$pdo->prepare("SELECT * FROM homepage_content WHERE id=? AND $scope");$q->execute([$id]);$edit=$q->fetch(PDO::FETCH_ASSOC)?:[];}
} catch(Throwable $e) {$ready=false;error_log('Homepage admin: '.$e->getMessage());}
function hp_val(array $row,string $key,string $default=''): string {return h((string)($row[$key]??$default));}
?><!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title><?=h($pageTitle)?> | Fire Safety BD</title>
<link rel="stylesheet" href="assets/admin-unified.css"><style>
:root{--hp-paper:#fff8f5;--hp-ink:#30191b;--hp-muted:#776468;--hp-line:#eadbd5;--hp-maroon:#650d18;--hp-orange:#ffa400;--hp-surface:#fff}
*{box-sizing:border-box}
body{margin:0;background:var(--hp-paper);color:var(--hp-ink);font:15px/1.6 system-ui,-apple-system,"Noto Sans Bengali","SolaimanLipi",Arial,sans-serif}
a{color:var(--hp-maroon);text-decoration:none}
.layout{display:grid;grid-template-columns:260px minmax(0,1fr);align-items:start;min-height:100vh;min-height:100dvh}
.hp-nav{position:sticky;top:0;height:100vh;height:100dvh;overflow-y:auto;background:linear-gradient(180deg,#450b15,#6a111f);padding:22px 14px;color:#fff}
.hp-brand{display:flex;align-items:center;gap:12px;padding:4px 8px 22px;color:#fff}
.hp-brand img{width:54px;height:54px;object-fit:contain;border:2px solid #fff;border-radius:12px;background:#510d18;flex:none}
.hp-brand strong,.hp-brand small{display:block}.hp-brand strong{font-size:19px;line-height:1.3}.hp-brand small{font-size:12px;color:#e8c6cb}
.hp-links{display:grid;gap:4px}.hp-links a{display:flex;align-items:center;gap:10px;padding:11px 12px;border-radius:11px;color:#f7e7e8;font-size:14px;font-weight:600}
.hp-links a:hover{background:#ffffff18}.hp-links a.active{background:var(--hp-orange);color:#29170b;font-weight:800}.hp-links .ico{width:22px;flex:none;text-align:center;font-size:17px}
.hp-links a.logout{border:1px solid #ffffff40;margin-top:12px}
.hp-main{min-width:0;width:100%;max-width:1320px;align-self:start;margin:0 auto;padding:26px clamp(16px,3vw,42px) 48px}
.hp-top{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap;margin-bottom:14px;color:var(--hp-muted);font-size:13px}.hp-top a{font-weight:700}
.hp-tag{border:1px solid #f4dba7;border-radius:30px;padding:5px 12px;background:#fff4d9;color:#84500a;font-size:12px;font-weight:700}
h1{font-size:clamp(24px,3vw,32px);line-height:1.35;color:#3b1520;margin:0 0 6px}
h2{font-size:19px;line-height:1.4;color:#4d1722;margin:0 0 14px}
.hp-description{color:var(--hp-muted);margin:0 0 20px}
.panel{min-width:0;background:var(--hp-surface);border:1px solid var(--hp-line);border-radius:18px;padding:20px;margin:0 0 18px;box-shadow:0 7px 25px #4419230d}
.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));align-items:start;gap:14px 16px}
.fields label{display:grid;gap:6px;min-width:0}.wide{grid-column:1/-1}.fields>input[type=hidden]{display:none}
label{font-size:14px;font-weight:650}
input:not([type=checkbox]),textarea,select{display:block;width:100%;min-width:0;max-width:100%;padding:10px 12px;border:1px solid #e2d4d0;border-radius:10px;background:#fdfaf9;color:var(--hp-ink);font:inherit}
textarea{resize:vertical;min-height:100px}input[type=file]{font-size:14px;overflow:hidden}input[type=checkbox]{width:18px;height:18px;accent-color:var(--hp-maroon);vertical-align:middle;margin:0 6px 0 0}
button,.btn{display:inline-flex;align-items:center;justify-content:center;border:1px solid var(--hp-maroon);border-radius:10px;background:var(--hp-maroon);color:#fff;padding:10px 18px;font:inherit;font-weight:700;cursor:pointer;text-decoration:none}
.muted{color:var(--hp-muted);font-size:13px;font-weight:400}
.hp-publish{padding:12px;border:1px solid var(--hp-line);background:#fff8f3;border-radius:10px}
.hp-actions{display:flex;align-items:center;flex-wrap:wrap;gap:14px;grid-column:1/-1}
.scroll{overflow-x:auto;max-width:100%;margin-bottom:8px}
table{width:100%;border-collapse:collapse;font-size:14px;min-width:540px}
th,td{text-align:left;padding:11px 12px;border-bottom:1px solid #eadbd5;overflow-wrap:anywhere;vertical-align:top}th{background:#fcf6f1;color:#705059;font-size:13px;white-space:nowrap}
td a{font-weight:700;text-decoration:underline;text-underline-offset:3px}
.hp-empty{padding:14px;background:#fff8f5;border-radius:10px;color:var(--hp-muted)}
.hp-mobile{display:none}
a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible,summary:focus-visible{outline:3px solid #d47c8d;outline-offset:2px}
@media(max-width:1150px){.layout{grid-template-columns:225px minmax(0,1fr)}.hp-nav{padding:18px 10px}.hp-brand img{width:44px;height:44px}.hp-brand strong{font-size:17px}.hp-main{padding:22px 20px 40px}}
@media(max-width:900px){.layout{display:block}.hp-nav{display:none}.hp-mobile{display:block;margin:0 0 16px;border-radius:12px;background:linear-gradient(180deg,#450b15,#6a111f);color:white;overflow:hidden}.hp-mobile summary{cursor:pointer;padding:12px 15px;font-weight:750}.hp-mobile .hp-links{padding:0 10px 12px}.hp-main{padding:14px 14px 35px}.panel{padding:17px}.hp-top{margin-bottom:12px}}
@media(max-width:560px){.fields{grid-template-columns:minmax(0,1fr);gap:12px}.hp-main{padding:12px 10px 30px}.panel{padding:14px;border-radius:14px}.hp-actions button{flex:1}.hp-top{font-size:12px}.hp-tag{font-size:11px}.hp-description{font-size:14px}.hp-brand strong{font-size:17px}input:not([type=checkbox]),textarea,select{font-size:16px}}
</style></head><body>
<?php
$hpNav=[
 ['fire_safety_job_prep_dashboard.php','▦','ড্যাশবোর্ড'],
 ['homepage_admin.php','⌂','হোমপেজ ব্যবস্থাপনা'],
 ['interview_admin.php','▤','ইন্টারভিউ ব্যবস্থাপনা'],
 ['questions.php','ⓘ','প্রশ্ন ব্যাংক'],
 ['model_tests.php','☑','মডেল টেস্ট'],
 ['notes.php','◫','স্টাডি নোট'],
 ['job_circulars.php','▣','চাকরির সার্কুলার'],
 ['fire_safety_job_prep_dashboard.php?section=marketplace','🛒','মার্কেটপ্লেস'],
 ['category_management.php','⊞','ক্যাটাগরি'],
 ['users.php','♙','ব্যবহারকারী'],
 ['notifications_admin.php','♧','নোটিফিকেশন'],
 ['fire_safety_job_prep_dashboard.php?section=community','▱','কমিউনিটি'],
 ['settings_admin.php','☼','সেটিংস'],
 ['analytics_admin.php','▥','অ্যানালিটিক্স'],
 ['premium_admin.php','♛','প্রিমিয়াম ব্যবস্থাপনা'],
 ['ads_admin.php','▧','বিজ্ঞাপন ব্যবস্থাপনা'],
 ['logout.php','↪','লগ আউট'],
];
function hp_nav(array $links,string $active): void { ?>
<nav class="hp-links" aria-label="অ্যাডমিন মেনু">
<?php foreach($links as [$url,$icon,$label]): ?>
<a href="<?=h($url)?>" class="<?=$url===$active?'active':($url==='logout.php'?'logout':'')?>" <?=$url===$active?'aria-current="page"':''?>><span class="ico" aria-hidden="true"><?=h($icon)?></span><?=h($label)?></a>
<?php endforeach; ?>
</nav>
<?php } ?>
<div class="layout">
<aside class="hp-nav"><a class="hp-brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD"><span><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></span></a><?php hp_nav($hpNav,$pageUrl); ?></aside>
<main class="hp-main">
<details class="hp-mobile"><summary>☰ Fire Safety BD · অ্যাডমিন মেনু</summary><?php hp_nav($hpNav,$pageUrl); ?></details>
<div class="hp-top"><span><a href="fire_safety_job_prep_dashboard.php">ড্যাশবোর্ড</a> / <?=h($pageTitle)?></span><span class="hp-tag">● শুধু অ্যাডমিন</span></div>
<h1><?=h($pageTitle)?></h1>
<p class="hp-description"><?=$isInterview?'পদ ও শিল্পভিত্তিক প্রশ্নোত্তর তৈরি, সম্পাদনা এবং প্রকাশ করুন।':'হিরো ব্যানার, ঘোষণা, সেফটি টিপস ও হোমপেজ সেকশন নিয়ন্ত্রণ করুন।'?></p>
<?php if($flash!==''): ?><p class="panel"><?=h($flash)?></p><?php endif; ?>
<?php if(!$ready): ?><p class="panel">হোমপেজ মাইগ্রেশন চালিয়ে আবার চেষ্টা করুন।</p><?php else: ?>
<?php if(!$isInterview): ?>
<section class="panel"><h2>হোমপেজ সেকশনের ক্রম ও দৃশ্যমানতা</h2><p class="muted">কমা দিয়ে সেকশনের নাম সাজান। বাদ দিলে ঐ ঐচ্ছিক সেকশন লুকাবে; মূল সেবার মেনু ও নেভিগেশন সবসময় থাকবে।</p><p><?php foreach($sections as $key=>$label): ?><code><?=h($key)?></code> = <?=h($label)?> · <?php endforeach; ?></p><form method="post"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="action" value="settings"><label>সেকশনের ক্রম<input name="section_order" maxlength="180" value="<?=h($order)?>"></label><p><button>সেটিংস সংরক্ষণ</button></p></form></section>
<?php endif; ?>
<section class="panel"><h2><?= $isInterview?($edit?'ইন্টারভিউ প্রশ্ন সম্পাদনা':'নতুন ইন্টারভিউ প্রশ্ন'):($edit?'কনটেন্ট সম্পাদনা':'নতুন কনটেন্ট') ?></h2><form method="post" enctype="multipart/form-data" class="fields"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<?=(int)($edit['id']??0)?>">
<?php if($isInterview): ?><input type="hidden" name="kind" value="interview"><?php else: ?><label>ধরন<select name="kind"><?php foreach($kinds as $k=>$v): ?><option value="<?=h($k)?>" <?=($edit['kind']??'banner')===$k?'selected':''?>><?=h($v)?></option><?php endforeach; ?></select></label><?php endif; ?>
<label>ক্রম (কম সংখ্যা আগে)<input type="number" min="0" max="10000" name="sort_order" value="<?=hp_val($edit,'sort_order','100')?>" required></label>
<?php if($isInterview): ?>
<label>পদ / বিভাগ (আবশ্যক)<input name="role_name" maxlength="100" required value="<?=hp_val($edit,'role_name')?>" placeholder="Fire Safety Officer"></label><label>ইন্ডাস্ট্রি (ইন্টারভিউ)<input name="industry" maxlength="100" value="<?=hp_val($edit,'industry')?>"></label>
<label>লেভেল<select name="difficulty"><?php foreach(['basic','intermediate','advanced'] as $v): ?><option <?=($edit['difficulty']??'basic')===$v?'selected':''?>><?=h($v)?></option><?php endforeach; ?></select></label>
<?php endif; ?>
<label class="wide"><?=$isInterview?'বাংলা প্রশ্ন':'বাংলা শিরোনাম'?><input name="title" maxlength="240" required value="<?=hp_val($edit,'title')?>"></label><label class="wide"><?=$isInterview?'বাংলা উত্তর':'বাংলা বিস্তারিত'?><textarea name="body" rows="5" maxlength="4000" required><?=hp_val($edit,'body')?></textarea></label>
<label class="wide"><?=$isInterview?'English question':'English title'?><input name="title_en" maxlength="240" value="<?=hp_val($edit,'title_en')?>"></label><label class="wide"><?=$isInterview?'English answer':'English details'?><textarea name="body_en" rows="4" maxlength="4000"><?=hp_val($edit,'body_en')?></textarea></label>
<?php if(!$isInterview): ?>
<label>ব্যানার/টিপসের গন্তব্য<select name="target"><?php foreach($targets as $v): ?><option <?=($edit['target']??'none')===$v?'selected':''?>><?=h($v)?></option><?php endforeach; ?></select></label>
<label class="wide">ব্যানার ছবির URL (ঐচ্ছিক, নিজস্ব uploads-এর বিদ্যমান ছবি)<input name="image_url" maxlength="500" value="<?=hp_val($edit,'image_url')?>"></label>
<label class="wide">সরাসরি ব্যানারের ছবি আপলোড করুন (JPG, PNG, WebP; সর্বোচ্চ ৪ MB)<input type="file" name="banner_image" accept="image/jpeg,image/png,image/webp"><span class="muted">প্রস্তাবিত মাপ ১২০০ × ৬০০ পিক্সেল। নতুন ছবি দিলে পুরোনো URL-এর পরিবর্তে সেটি ব্যবহার হবে। প্রকাশ না করলেও আপলোড করা ছবি সরাসরি URL-এ পাওয়া যেতে পারে; ব্যক্তিগত ছবি দেবেন না।</span></label>
<?php if(($edit['kind']??'')==='banner' && preg_match('~^https://fire\.manobikishwarganj\.com/uploads/[A-Za-z0-9/_-]+\.(?:png|jpe?g|webp)$~D',(string)($edit['image_url']??''))): ?><div class="wide"><p>বর্তমান ছবি</p><img src="<?=hp_val($edit,'image_url')?>" alt="বর্তমান ব্যানার" style="max-width:100%;max-height:220px;border-radius:12px;object-fit:contain"></div><?php endif; ?>
<?php endif; ?>
<label class="wide hp-publish"><span><input type="checkbox" name="is_published" value="1" <?=!empty($edit['is_published'])?'checked':''?>> প্রকাশ করুন (টিক সরালে ড্রাফট হবে)</span></label><div class="hp-actions"><button>সংরক্ষণ</button> <?php if($edit): ?><a href="<?=h($pageUrl)?>">বাতিল</a><?php endif; ?></div></form></section>
<section class="panel"><h2><?=$isInterview?'সংরক্ষিত ইন্টারভিউ প্রশ্ন':'সংরক্ষিত কনটেন্ট'?></h2><div class="scroll"><table><thead><tr><?php if($isInterview): ?><th>পদ</th><th>ইন্ডাস্ট্রি</th><th>প্রশ্ন</th><?php else: ?><th>ধরন</th><th>শিরোনাম</th><?php endif; ?><th>ক্রম</th><th>অবস্থা</th><th>সম্পাদনা</th></tr></thead><tbody><?php foreach(array_slice($rows,0,30) as $row): ?><tr><?php if($isInterview): ?><td><?=h($row['role_name'])?></td><td><?=h($row['industry'])?></td><?php else: ?><td><?=h($kinds[$row['kind']]??'')?></td><?php endif; ?><td><?=h($row['title'])?></td><td><?=(int)$row['sort_order']?></td><td><?=$row['is_published']?'প্রকাশিত':'ড্রাফট'?></td><td><a href="?edit=<?=(int)$row['id']?>">এডিট</a></td></tr><?php endforeach; ?></tbody></table></div><?php if(!$rows): ?><p class="hp-empty">কোনো কনটেন্ট নেই।</p><?php endif; ?><?php if($page>1): ?><a href="?page=<?=$page-1?>">আগের পেজ</a> <?php endif; ?><?php if(count($rows)>30): ?><a href="?page=<?=$page+1?>">পরের পেজ</a><?php endif; ?></section>
<?php endif; ?></main></div></body></html>
