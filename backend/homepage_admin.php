<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';
require_admin();
require_once __DIR__.'/db.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
$sections=['banners'=>'ব্যানার','progress'=>'দৈনিক প্রস্তুতি','jobs'=>'চাকরি','topics'=>'বিষয়ভিত্তিক প্রস্তুতি','notes'=>'নতুন নোট','marketplace'=>'মার্কেটপ্লেস','community'=>'কমিউনিটি','tips'=>'সেফটি টিপস'];
$kinds=['banner'=>'ব্যানার / ঘোষণা','tip'=>'সেফটি টিপস','interview'=>'ইন্টারভিউ'];
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
    try {
        if (($_POST['action']??'')==='settings') {
            $raw=hp_field('section_order',180);
            $order=$raw===''?[]:array_map('trim',explode(',',$raw));
            if (array_diff($order,array_keys($sections))||count($order)!==count(array_unique($order))) throw new DomainException('সেকশনের নাম বা ক্রম সঠিক নয়।');
            $q=$pdo->prepare('UPDATE homepage_settings SET section_order=? WHERE id=1');
            $q->execute([implode(',',$order)]);
        } elseif (($_POST['action']??'')==='save') {
            $id=hp_id($_POST['id']??0);
            $kind=hp_field('kind',20,true); if(!isset($kinds[$kind])) throw new DomainException('কনটেন্টের ধরন সঠিক নয়।');
            $title=hp_field('title',240,true); $body=hp_field('body',4000,true);
            $titleEn=hp_field('title_en',240); $bodyEn=hp_field('body_en',4000);
            if (($titleEn==='')!==($bodyEn==='')) throw new DomainException('ইংরেজি শিরোনাম ও বিস্তারিত একসঙ্গে দিন।');
            $role=$kind==='interview'?hp_field('role_name',100,true):'';
            $industry=$kind==='interview'?hp_field('industry',100):'';
            $difficulty=hp_field('difficulty',20,true);
            if(!in_array($difficulty,['basic','intermediate','advanced'],true)) throw new DomainException('লেভেল সঠিক নয়।');
            $target=$kind==='interview'?'none':hp_field('target',20,true);
            if(!in_array($target,$targets,true)) throw new DomainException('লিংক সঠিক নয়।');
            $image=$kind==='banner'?hp_field('image_url',500):'';
            if($image!==''&&!preg_match('~^https://fire\.manobikishwarganj\.com/uploads/[A-Za-z0-9/_-]+\.(?:png|jpe?g|webp)$~D',$image)) throw new DomainException('শুধু নিজের সাইটের uploads ফোল্ডারের PNG/JPG/WebP URL দিন।');
            $sort=hp_id($_POST['sort_order']??100); if($sort>10000) throw new DomainException('ক্রম ০–১০০০০ দিন।');
            $published=($_POST['is_published']??'')==='1'?1:0;
            $args=[$kind,$title,$body,$titleEn,$bodyEn,$role,$industry,$difficulty,$target,$image,$sort,$published];
            if ($id>0) {
                $q=$pdo->prepare('UPDATE homepage_content SET kind=?,title=?,body=?,title_en=?,body_en=?,role_name=?,industry=?,difficulty=?,target=?,image_url=?,sort_order=?,is_published=? WHERE id=?');
                $q->execute([...$args,$id]);
            } else {
                $q=$pdo->prepare('INSERT INTO homepage_content (kind,title,body,title_en,body_en,role_name,industry,difficulty,target,image_url,sort_order,is_published) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)');
                $q->execute($args);
            }
        } else throw new DomainException('অনুরোধ সঠিক নয়।');
        $_SESSION['homepage_flash']='সংরক্ষণ হয়েছে।';
    } catch(DomainException $e) {$_SESSION['homepage_flash']=$e->getMessage();}
    catch(Throwable $e) {error_log('Homepage admin: '.$e->getMessage());$_SESSION['homepage_flash']='সংরক্ষণ করা যায়নি। মাইগ্রেশন পরীক্ষা করুন।';}
    header('Location: homepage_admin.php',true,303); exit;
}
$flash=$_SESSION['homepage_flash']??''; unset($_SESSION['homepage_flash']);
$ready=true; $rows=[]; $order=''; $edit=[];
$page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;
try {
    $order=$pdo->query('SELECT section_order FROM homepage_settings WHERE id=1')->fetchColumn();
    if($order===false) throw new RuntimeException('Migration missing');
    $offset=($page-1)*30;
    $rows=$pdo->query("SELECT * FROM homepage_content ORDER BY id DESC LIMIT 31 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
    $id=hp_id($_GET['edit']??0);
    if($id>0){$q=$pdo->prepare('SELECT * FROM homepage_content WHERE id=?');$q->execute([$id]);$edit=$q->fetch(PDO::FETCH_ASSOC)?:[];}
} catch(Throwable $e) {$ready=false;error_log('Homepage admin: '.$e->getMessage());}
function hp_val(array $row,string $key,string $default=''): string {return h((string)($row[$key]??$default));}
?><!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>হোমপেজ ব্যবস্থাপনা | Fire Safety BD</title>
<link rel="stylesheet" href="assets/admin-unified.css"><style>
*{box-sizing:border-box}body{margin:0;background:#fff8f4;color:#27191b;font-family:system-ui,sans-serif}.layout{display:grid;grid-template-columns:240px minmax(0,1fr);min-height:100vh}.hp-nav{background:linear-gradient(#450b15,#6a111f);padding:24px 16px;color:white}.hp-nav a{display:block;color:white;text-decoration:none;padding:12px;border-radius:10px}.hp-nav a.active{background:#a83b27}.brand{display:flex!important;align-items:center;gap:10px;font-weight:bold}.brand img{width:44px;height:44px;border-radius:10px;background:white}.hp-main{padding:24px;max-width:1200px;width:100%;margin:auto}.panel{background:white;border:1px solid #ead8d4;border-radius:18px;padding:20px;margin:16px 0}.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.fields label{display:grid;gap:6px}.wide{grid-column:1/-1}input:not([type=checkbox]),textarea,select{width:100%;padding:10px;border:1px solid #cdb9b9;border-radius:8px;background:white;color:#27191b}button,.btn{display:inline-block;border:0;border-radius:9px;background:#650d18;color:white;padding:10px 16px;text-decoration:none;cursor:pointer}.muted{color:#65565a;font-size:14px}.scroll{overflow:auto}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:10px;border-bottom:1px solid #ead8d4;overflow-wrap:anywhere}a{color:#650d18}@media(max-width:760px){.layout{display:block}.hp-nav{padding:8px}.hp-nav a{display:inline-block}.hp-main{padding:12px}.fields{grid-template-columns:1fr}}
</style></head><body><div class="layout"><aside class="hp-nav"><a class="brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png" alt="">Fire Safety BD</a><a href="fire_safety_job_prep_dashboard.php">ড্যাশবোর্ড</a><a class="active" href="homepage_admin.php">হোমপেজ ও ইন্টারভিউ</a><a href="questions.php">প্রশ্ন ব্যাংক</a><a href="notes.php">স্টাডি নোট</a><a href="admin_operations.php?tab=notifications">নোটিফিকেশন</a><a href="logout.php">লগ আউট</a></aside><main class="hp-main"><h1>হোমপেজ ও ইন্টারভিউ ব্যবস্থাপনা</h1>
<?php if($flash!==''): ?><p class="panel"><?=h($flash)?></p><?php endif; ?>
<?php if(!$ready): ?><p class="panel">হোমপেজ মাইগ্রেশন চালিয়ে আবার চেষ্টা করুন।</p><?php else: ?>
<section class="panel"><h2>হোমপেজ সেকশনের ক্রম ও দৃশ্যমানতা</h2><p class="muted">কমা দিয়ে সেকশনের নাম সাজান। বাদ দিলে ঐ ঐচ্ছিক সেকশন লুকাবে; মূল সেবার মেনু ও নেভিগেশন সবসময় থাকবে।</p><p><?php foreach($sections as $key=>$label): ?><code><?=h($key)?></code> = <?=h($label)?> · <?php endforeach; ?></p><form method="post"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="action" value="settings"><label>সেকশনের ক্রম<input name="section_order" maxlength="180" value="<?=h($order)?>"></label><p><button>সেটিংস সংরক্ষণ</button></p></form></section>
<section class="panel"><h2><?= $edit?'কনটেন্ট সম্পাদনা':'নতুন কনটেন্ট' ?></h2><form method="post" class="fields"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<?=(int)($edit['id']??0)?>">
<label>ধরন<select name="kind"><?php foreach($kinds as $k=>$v): ?><option value="<?=h($k)?>" <?=($edit['kind']??'banner')===$k?'selected':''?>><?=h($v)?></option><?php endforeach; ?></select></label>
<label>ক্রম (কম সংখ্যা আগে)<input type="number" min="0" max="10000" name="sort_order" value="<?=hp_val($edit,'sort_order','100')?>" required></label>
<label class="wide">বাংলা শিরোনাম / প্রশ্ন<input name="title" maxlength="240" required value="<?=hp_val($edit,'title')?>"></label><label class="wide">বাংলা বিস্তারিত / উত্তর<textarea name="body" rows="5" maxlength="4000" required><?=hp_val($edit,'body')?></textarea></label>
<label class="wide">English title / question<input name="title_en" maxlength="240" value="<?=hp_val($edit,'title_en')?>"></label><label class="wide">English details / answer<textarea name="body_en" rows="4" maxlength="4000"><?=hp_val($edit,'body_en')?></textarea></label>
<label>পদ / বিভাগ (ইন্টারভিউয়ের জন্য আবশ্যক)<input name="role_name" maxlength="100" value="<?=hp_val($edit,'role_name')?>" placeholder="Fire Safety Officer"></label><label>ইন্ডাস্ট্রি (ইন্টারভিউ)<input name="industry" maxlength="100" value="<?=hp_val($edit,'industry')?>"></label>
<label>লেভেল<select name="difficulty"><?php foreach(['basic','intermediate','advanced'] as $v): ?><option <?=($edit['difficulty']??'basic')===$v?'selected':''?>><?=h($v)?></option><?php endforeach; ?></select></label>
<label>ব্যানার/টিপসের গন্তব্য<select name="target"><?php foreach($targets as $v): ?><option <?=($edit['target']??'none')===$v?'selected':''?>><?=h($v)?></option><?php endforeach; ?></select></label>
<label class="wide">ব্যানার ছবির URL (ঐচ্ছিক, নিজস্ব uploads-এর বিদ্যমান ছবি)<input name="image_url" maxlength="500" value="<?=hp_val($edit,'image_url')?>"></label>
<label class="wide"><span><input type="checkbox" name="is_published" value="1" <?=!empty($edit['is_published'])?'checked':''?>> প্রকাশ করুন (টিক সরালে ড্রাফট হবে)</span></label><div><button>সংরক্ষণ</button> <?php if($edit): ?><a href="homepage_admin.php">বাতিল</a><?php endif; ?></div></form></section>
<section class="panel"><h2>সংরক্ষিত কনটেন্ট</h2><div class="scroll"><table><thead><tr><th>ধরন</th><th>শিরোনাম</th><th>ক্রম</th><th>অবস্থা</th><th>সম্পাদনা</th></tr></thead><tbody><?php foreach(array_slice($rows,0,30) as $row): ?><tr><td><?=h($kinds[$row['kind']]??'')?></td><td><?=h($row['title'])?></td><td><?=(int)$row['sort_order']?></td><td><?=$row['is_published']?'প্রকাশিত':'ড্রাফট'?></td><td><a href="?edit=<?=(int)$row['id']?>">এডিট</a></td></tr><?php endforeach; ?></tbody></table></div><?php if(!$rows): ?><p>কোনো কনটেন্ট নেই।</p><?php endif; ?><?php if($page>1): ?><a href="?page=<?=$page-1?>">আগের পেজ</a> <?php endif; ?><?php if(count($rows)>30): ?><a href="?page=<?=$page+1?>">পরের পেজ</a><?php endif; ?></section>
<?php endif; ?></main></div></body></html>
