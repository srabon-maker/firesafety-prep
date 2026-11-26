<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';require_admin();
require_once __DIR__.'/db.php';require_once __DIR__.'/career_common.php';
header('Cache-Control: no-store, private');header('X-Content-Type-Options: nosniff');
$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
if(($_SERVER['REQUEST_METHOD']??'GET')==='GET'&&isset($_GET['photo'])){
 $key=$_GET['photo'];
 if(!is_string($key)||!preg_match('/^[a-f0-9]{32}$/D',$key)){http_response_code(404);exit;}
 $q=$pdo->prepare("SELECT p.photo_path FROM career_profiles p JOIN users u ON u.id=p.user_id WHERE p.photo_path=? AND u.is_registered=1 AND p.status IN ('pending','approved')");
 $q->execute([$key]);$allowed=$q->fetchColumn();$bytes=is_string($allowed)?career_photo_read($allowed):null;
 if(!is_string($bytes)||$bytes===''){http_response_code(404);exit;}
 header('Content-Type: image/jpeg');header('Content-Length: '.strlen($bytes));echo $bytes;exit;
}
if(($_SERVER['REQUEST_METHOD']??'GET')==='POST'){
 verify_csrf();
 try{
  $action=$_POST['action']??'';
  if($action==='course'){
   $id=empty($_POST['id'])?null:career_id($_POST['id']);
   $title=career_text($_POST['title']??'',180,true);$provider=career_text($_POST['provider']??'',180,true);
   $description=career_text($_POST['description']??'',5000,true);$location=career_text($_POST['location']??'',120);$url=career_url($_POST['course_url']??'');
   $date=career_text($_POST['start_date']??'',10);
   if($date!==''&&(!preg_match('/^\d{4}-\d{2}-\d{2}$/D',$date)||!checkdate((int)substr($date,5,2),(int)substr($date,8,2),(int)substr($date,0,4))))throw new DomainException('Invalid date');
   $args=[$title,$provider,$description,$location,$url,$date===''?null:$date,isset($_POST['published'])?1:0];
   if($id===null){$q=$pdo->prepare('INSERT INTO career_courses(title,provider,description,location,course_url,start_date,published,updated_at) VALUES(?,?,?,?,?,?,?,UTC_TIMESTAMP())');}
   else{$q=$pdo->prepare('UPDATE career_courses SET title=?,provider=?,description=?,location=?,course_url=?,start_date=?,published=?,updated_at=UTC_TIMESTAMP() WHERE id=?');$args[]=$id;}
   $q->execute($args);
  }elseif($action==='moderate'){
   $id=career_id($_POST['id']??null);$revision=career_id($_POST['revision']??null);$status=$_POST['status']??'';
   if(!in_array($status,['approved','hidden'],true))throw new DomainException('Invalid status');
   $q=$pdo->prepare("UPDATE career_profiles SET status=?,revision=revision+1,updated_at=UTC_TIMESTAMP() WHERE user_id=? AND revision=? AND (status='pending' OR (status='approved' AND ?='hidden'))");
   $q->execute([$status,$id,$revision,$status]);if(!$q->rowCount())throw new DomainException('Profile changed or consent withdrawn; reload');
  }else throw new DomainException('Invalid action');
  $_SESSION['career_flash']='সংরক্ষণ হয়েছে।';
 }catch(Throwable $e){if(!($e instanceof DomainException))error_log('Career admin: '.$e->getMessage());$_SESSION['career_flash']=$e instanceof DomainException?$e->getMessage():'সংরক্ষণ হয়নি।';}
 header('Location: career_admin.php',true,303);exit;
}
$flash=$_SESSION['career_flash']??'';unset($_SESSION['career_flash']);$error='';$courses=[];$profiles=[];$edit=[];
$page=filter_var($_GET['page']??1,FILTER_VALIDATE_INT,['options'=>['min_range'=>1,'max_range'=>10000]])?:1;$offset=($page-1)*25;
try{
 $courses=$pdo->query("SELECT * FROM career_courses ORDER BY id DESC LIMIT 26 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
 $profiles=$pdo->query("SELECT p.* FROM career_profiles p JOIN users u ON u.id=p.user_id WHERE u.is_registered=1 AND p.status IN ('pending','approved') ORDER BY (p.status='pending') DESC,p.user_id DESC LIMIT 26 OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
 if(isset($_GET['edit'])){$q=$pdo->prepare('SELECT * FROM career_courses WHERE id=?');$q->execute([career_id($_GET['edit'])]);$edit=$q->fetch(PDO::FETCH_ASSOC)?:[];}
}catch(Throwable $e){error_log('Career admin: '.$e->getMessage());$error='ডাটাবেজ মাইগ্রেশন ও সার্ভার লগ পরীক্ষা করুন।';}
?><!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ক্যারিয়ার ব্যবস্থাপনা | Fire Safety BD</title><link rel="stylesheet" href="assets/admin-unified.css"><style>
*{box-sizing:border-box}body{margin:0;background:#fff8f5;color:#32191d;font:15px/1.6 system-ui,sans-serif}header{background:#650d18;color:white;padding:20px}header a{color:#fff}main{max-width:1100px;margin:auto;padding:18px}section{background:white;border:1px solid #eadbd5;border-radius:16px;padding:20px;margin:18px 0}h1,h2{margin:0 0 12px}label{display:block;margin:10px 0}input:not([type=checkbox]),textarea{display:block;width:100%;font:inherit;padding:10px;border:1px solid #d8bcbf;border-radius:8px}button{background:#650d18;color:white;border:0;border-radius:8px;padding:10px 16px;font:inherit;cursor:pointer}article{border-top:1px solid #eadbd5;padding:12px 0;overflow-wrap:anywhere}a{color:#650d18}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}@media(max-width:650px){.grid{grid-template-columns:1fr}}
</style></head><body><header><h1>ক্যারিয়ার ব্যবস্থাপনা</h1><a href="fire_safety_job_prep_dashboard.php">← ড্যাশবোর্ড</a> · <a href="interview_admin.php">ইন্টারভিউ প্রশ্ন</a> · <a href="job_circulars.php">চাকরির সার্কুলার</a></header><main>
<?php if($flash!==''):?><section role="status"><?=h($flash)?></section><?php endif;?>
<?php if($error!==''):?><section><?=h($error)?></section><?php else:?>
<section><h2><?=$edit?'কোর্স সম্পাদনা':'নতুন ট্রেনিং / কোর্স'?></h2><p>প্রকাশের আগে প্রশিক্ষণ প্রদানকারী ও অফিসিয়াল লিংক যাচাই করুন।</p>
<form method="post"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="action" value="course"><input type="hidden" name="id" value="<?=h((string)($edit['id']??''))?>">
<div class="grid"><label>কোর্সের নাম<input name="title" required maxlength="180" value="<?=h($edit['title']??'')?>"></label><label>প্রতিষ্ঠান<input name="provider" required maxlength="180" value="<?=h($edit['provider']??'')?>"></label><label>স্থান<input name="location" maxlength="120" value="<?=h($edit['location']??'')?>"></label><label>শুরুর তারিখ<input type="date" name="start_date" value="<?=h($edit['start_date']??'')?>"></label></div>
<label>বিস্তারিত<textarea name="description" required maxlength="5000" rows="4"><?=h($edit['description']??'')?></textarea></label><label>অফিসিয়াল HTTPS লিংক<input type="url" name="course_url" maxlength="500" value="<?=h($edit['course_url']??'')?>"></label>
<label><input type="checkbox" name="published" <?=$edit&&$edit['published']?'checked':''?>> অ্যাপে প্রকাশ করুন</label><button>সংরক্ষণ</button> <a href="career_admin.php">নতুন কোর্স</a></form>
</section><section><h2>ট্রেনিং ও কোর্স</h2><?php foreach(array_slice($courses,0,25) as $c):?><article><strong><?=h($c['title'])?></strong> · <?=h($c['provider'])?> · <?=$c['published']?'প্রকাশিত':'ড্রাফট'?> <a href="?edit=<?=(int)$c['id']?>">সম্পাদনা</a></article><?php endforeach;?><?php if(!$courses):?><p>কোনো কোর্স নেই।</p><?php endif;?></section>
<section><h2>Professional Directory অনুমোদন</h2><p>স্বেচ্ছায় জমা দেওয়া প্রোফাইল। যোগাযোগের তথ্য বা অসত্য দাবি অনুমোদন করবেন না। অনুমোদন পেশাগত সনদ যাচাই নয়।</p>
<?php foreach(array_slice($profiles,0,25) as $p):?><article><?php if(preg_match('/^[a-f0-9]{32}$/D',(string)($p['photo_path']??''))):?><a href="?photo=<?=h($p['photo_path'])?>" target="_blank" rel="noopener"><img src="?photo=<?=h($p['photo_path'])?>" alt="Profile photo" loading="lazy" width="72" height="72" style="object-fit:cover;border-radius:50%;vertical-align:middle;margin-right:12px"></a><?php endif;?><strong><?=h($p['display_name'])?></strong> — <?=h($p['role_name'])?><div><?=h($p['organization'])?> · <?=h($p['city'])?> · <?=h($p['status'])?></div>
<?php if(trim((string)($p['bio']??''))!==''):?><p><strong>বিস্তারিত পরিচিতি:</strong><br><?=nl2br(h($p['bio']))?></p><?php endif;?>
<form method="post"><input type="hidden" name="csrf_token" value="<?=h(csrf_token())?>"><input type="hidden" name="action" value="moderate"><input type="hidden" name="id" value="<?=(int)$p['user_id']?>"><input type="hidden" name="revision" value="<?=(int)$p['revision']?>"><?php if($p['status']==='pending'):?><button name="status" value="approved">অনুমোদন</button><?php endif;?> <button name="status" value="hidden">লুকান / প্রত্যাখ্যান</button></form></article><?php endforeach;?><?php if(!$profiles):?><p>কোনো প্রোফাইল নেই।</p><?php endif;?></section>
<?php if($page>1):?><a href="?page=<?=$page-1?>">আগের পেজ</a><?php endif;?> <?php if(count($courses)>25||count($profiles)>25):?><a href="?page=<?=$page+1?>">পরের পেজ</a><?php endif;?>
<?php endif;?></main></body></html>
