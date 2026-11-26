<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
require_once __DIR__.'/../../career_common.php';
require_once __DIR__.'/../../premium_learning.php';
function career_reply(int $status,array $body):never{
 http_response_code($status);echo json_encode($body,JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);exit;
}
$newPhoto=null;$oldPhoto=null;
try{
 $method=$_SERVER['REQUEST_METHOD']??'GET';
 if(!in_array($method,['GET','POST'],true)){header('Allow: GET, POST');career_reply(405,['success'=>false,'message'=>'GET or POST required']);}
 require_once __DIR__.'/../../db.php';$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
 $uid=premium_bearer_user($pdo);if($uid===null)career_reply(401,['success'=>false,'message'=>'Login required']);
 if($method==='GET'){
  $action=$_GET['action']??'';
  if($action==='photo'||$action==='directory'||$action==='my_profile'){
   $viewer=$pdo->prepare('SELECT id FROM users WHERE id=? AND is_registered=1');$viewer->execute([$uid]);
   if(!$viewer->fetchColumn())career_reply(403,['success'=>false,'message'=>'Registered account required']);
  }
  if($action==='photo'){
   $key=$_GET['key']??'';
   if(!is_string($key)||!preg_match('/^[a-f0-9]{32}$/D',$key))career_reply(404,['success'=>false,'message'=>'Photo unavailable']);
   $q=$pdo->prepare("SELECT p.photo_path FROM career_profiles p JOIN users u ON u.id=p.user_id WHERE p.photo_path=? AND u.is_registered=1 AND (p.user_id=? OR p.status='approved')");
   $q->execute([$key,$uid]);$allowed=$q->fetchColumn();$bytes=is_string($allowed)?career_photo_read($allowed):null;
   if(!is_string($bytes)||$bytes==='')career_reply(404,['success'=>false,'message'=>'Photo unavailable']);
   header('Content-Type: image/jpeg');header('Content-Length: '.strlen($bytes));echo $bytes;exit;
  }
  if($action==='alerts'){
   $q=$pdo->prepare('SELECT enabled,keyword,location FROM career_job_preferences WHERE user_id=?');$q->execute([$uid]);
   $pref=$q->fetch(PDO::FETCH_ASSOC)?:['enabled'=>0,'keyword'=>'','location'=>''];$pref['enabled']=(bool)$pref['enabled'];
   career_reply(200,['success'=>true,'preferences'=>$pref,'data'=>career_matches($pdo,$pref,$uid)]);
  }
  if($action==='mock'){
   $mode=premium_policy($pdo)['effective_mode'];$locked=premium_effective_interview($mode);
   $scope=premium_active($pdo,$uid)!==null?'1':"NOT ($locked)";
   $role=career_text($_GET['role']??'',120);
   $q=$pdo->prepare("SELECT id,title,body,role_name FROM homepage_content WHERE kind='interview' AND is_published=1 AND $scope AND (?='' OR role_name=?) ORDER BY RAND() LIMIT 10");
   $q->execute([$role,$role]);career_reply(200,['success'=>true,'data'=>$q->fetchAll(PDO::FETCH_ASSOC)]);
  }
  $before=isset($_GET['before_id'])?career_id($_GET['before_id']):PHP_INT_MAX;
  if($action==='courses'){
   $q=$pdo->prepare('SELECT id,title,provider,description,location,course_url,start_date FROM career_courses WHERE published=1 AND id<? ORDER BY id DESC LIMIT 26');$q->execute([$before]);
  }elseif($action==='directory'){
   $search=career_text($_GET['q']??'',160);
   $q=$pdo->prepare("SELECT p.user_id AS id,p.display_name,p.role_name,p.organization,p.city,p.bio,p.photo_path FROM career_profiles p JOIN users u ON u.id=p.user_id WHERE p.status='approved' AND u.is_registered=1 AND p.user_id<? AND (?='' OR LOCATE(?,CONCAT_WS(' ',p.display_name,p.role_name,p.organization,p.city,p.bio))>0) ORDER BY p.user_id DESC LIMIT 26");$q->execute([$before,$search,$search]);
  }elseif($action==='my_profile'){
   $q=$pdo->prepare('SELECT display_name,role_name,organization,city,bio,status,photo_path FROM career_profiles WHERE user_id=?');$q->execute([$uid]);career_reply(200,['success'=>true,'profile'=>$q->fetch(PDO::FETCH_ASSOC)?:null]);
  }else throw new DomainException('Unknown action');
  $rows=$q->fetchAll(PDO::FETCH_ASSOC);$more=count($rows)>25;if($more)array_pop($rows);
  career_reply(200,['success'=>true,'data'=>$rows,'next_before_id'=>$more?(string)end($rows)['id']:null]);
 }
 $raw=file_get_contents('php://input',false,null,0,3145729);
 if($raw===false||strlen($raw)>3145728)career_reply(413,['success'=>false,'message'=>'Request too large']);
 $b=json_decode($raw,true);if(!is_array($b)||array_is_list($b))throw new DomainException('JSON object required');
 $action=$b['action']??'';
 if($action!=='save_profile'&&strlen($raw)>8192)career_reply(413,['success'=>false,'message'=>'Request too large']);
 $pdo->beginTransaction();$q=$pdo->prepare('SELECT id FROM users WHERE id=? AND is_registered=1 FOR UPDATE');$q->execute([$uid]);if(!$q->fetchColumn())throw new DomainException('Account unavailable');
 $count=0;
 if($action==='save_alerts'){
  $enabled=$b['enabled']??null;if(!is_bool($enabled))throw new DomainException('Invalid preference');
  $keyword=career_text($b['keyword']??'',120);$location=career_text($b['location']??'',120);
  if($enabled&&$keyword===''&&$location==='')throw new DomainException('Enter a keyword or location');
  $q=$pdo->prepare('INSERT INTO career_job_preferences(user_id,enabled,keyword,location,updated_at) VALUES(?,?,?,?,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE enabled=VALUES(enabled),keyword=VALUES(keyword),location=VALUES(location),updated_at=VALUES(updated_at)');$q->execute([$uid,(int)$enabled,$keyword,$location]);
 }elseif($action==='check_alerts'){
  $q=$pdo->prepare('SELECT enabled,keyword,location FROM career_job_preferences WHERE user_id=?');$q->execute([$uid]);$pref=$q->fetch(PDO::FETCH_ASSOC);
  if($pref){
   $jobs=career_matches($pdo,$pref,$uid,true);
   $delivery=$pdo->prepare('INSERT INTO career_job_deliveries(user_id,job_id,created_at) VALUES(?,?,UTC_TIMESTAMP())');
   $notify=$pdo->prepare("INSERT INTO notifications(user_id,title,message,notification_type,reference_type,reference_id,is_read,sent_at) VALUES(?,?,?,'general','career_job',?,0,NOW())");
   foreach(array_slice($jobs,0,20) as $job){
    $delivery->execute([$uid,$job['id']]);
    $notify->execute([$uid,'নতুন মিল থাকা চাকরি',mb_substr($job['title'].' — '.$job['organization'],0,500).'। Career → Job Alert দেখুন।',$job['id']]);$count++;
   }
  }
 }elseif($action==='save_profile'){
  if(($b['consent']??null)!==true)throw new DomainException('Explicit consent required');
  $name=career_public_text($b['display_name']??'',100,true);$role=career_public_text($b['role_name']??'',120,true);
  $org=career_public_text($b['organization']??'',120);$city=career_public_text($b['city']??'',100);
  $bio=array_key_exists('bio',$b)?career_public_text($b['bio'],2000):null;
  $photoPath=null;$jpeg=null;
  $remove=$b['remove_photo']??false;
  if(!is_bool($remove))throw new DomainException('Invalid photo choice');
  if(array_key_exists('photo_base64',$b)){
   if($remove||!is_string($b['photo_base64'])||$b['photo_base64']===''||strlen($b['photo_base64'])>2796204)throw new DomainException('ছবির আকার ২ MB-এর মধ্যে রাখুন');
   $binary=base64_decode($b['photo_base64'],true);
   if($binary===false||strlen($binary)>2097152)throw new DomainException('অবৈধ ছবি');
   $info=@getimagesizefromstring($binary);
   if(!$info||!in_array($info[2],[IMAGETYPE_JPEG,IMAGETYPE_PNG,IMAGETYPE_WEBP],true)||$info[0]<1||$info[1]<1||$info[0]>2048||$info[1]>2048)throw new DomainException('JPG, PNG বা WebP ছবি দিন (সর্বোচ্চ 2048 × 2048)');
   if(!function_exists('imagecreatefromstring')||!function_exists('imagejpeg'))throw new RuntimeException('GD image support unavailable');
   $source=@imagecreatefromstring($binary);
   if($source===false)throw new DomainException('অবৈধ ছবি');
   $scale=min(1,720/max($info[0],$info[1]));$w=max(1,(int)round($info[0]*$scale));$h=max(1,(int)round($info[1]*$scale));
   $canvas=imagecreatetruecolor($w,$h);
   imagefill($canvas,0,0,imagecolorallocate($canvas,255,255,255));
   imagecopyresampled($canvas,$source,0,0,0,0,$w,$h,$info[0],$info[1]);
   foreach([85,76,66,56,46,36] as $quality){
    ob_start();$ok=imagejpeg($canvas,null,$quality);$jpeg=ob_get_clean();
    if(!$ok||!is_string($jpeg)||$jpeg==='')throw new RuntimeException('Photo processing failed');
    if(strlen($jpeg)<=204800)break;
   }
   if(strlen($jpeg)>204800)throw new DomainException('Photo could not be compressed; choose another image');
   $photoPath=bin2hex(random_bytes(16));
  }
  $q=$pdo->prepare('SELECT photo_path FROM career_profiles WHERE user_id=?');$q->execute([$uid]);$previous=$q->fetchColumn();
  $q=$pdo->prepare("INSERT INTO career_profiles(user_id,display_name,role_name,organization,city,bio,status,updated_at) VALUES(?,?,?,?,?,?, 'pending',UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE display_name=VALUES(display_name),role_name=VALUES(role_name),organization=VALUES(organization),city=VALUES(city),bio=IF(VALUES(bio) IS NULL,bio,VALUES(bio)),status='pending',revision=revision+1,updated_at=VALUES(updated_at)");
  $q->execute([$uid,$name,$role,$org,$city,$bio]);
  if($photoPath!==null){
   career_photo_write($photoPath,$jpeg);$newPhoto=$photoPath;
   $q=$pdo->prepare('UPDATE career_profiles SET photo_path=? WHERE user_id=?');$q->execute([$photoPath,$uid]);
   $oldPhoto=is_string($previous)?$previous:null;
  }elseif($remove){
   $q=$pdo->prepare("UPDATE career_profiles SET photo_path='' WHERE user_id=?");$q->execute([$uid]);
   $oldPhoto=is_string($previous)?$previous:null;
  }
 }elseif($action==='hide_profile'){
  $q=$pdo->prepare("UPDATE career_profiles SET status='hidden',revision=revision+1,updated_at=UTC_TIMESTAMP() WHERE user_id=?");$q->execute([$uid]);
 }else throw new DomainException('Unknown action');
 $pdo->commit();$newPhoto=null;if($oldPhoto!==null)career_photo_delete($oldPhoto);career_reply(200,['success'=>true,'new_alerts'=>$count]);
}catch(DomainException $e){if(isset($pdo)&&$pdo->inTransaction())$pdo->rollBack();if($newPhoto!==null)career_photo_delete($newPhoto);career_reply(422,['success'=>false,'message'=>$e->getMessage()]);}
catch(Throwable $e){if(isset($pdo)&&$pdo->inTransaction())$pdo->rollBack();if($newPhoto!==null)career_photo_delete($newPhoto);error_log('Career API: '.$e->getMessage());career_reply(500,['success'=>false,'message'=>'Career service unavailable']);}
