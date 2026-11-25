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
try{
 $method=$_SERVER['REQUEST_METHOD']??'GET';
 if(!in_array($method,['GET','POST'],true)){header('Allow: GET, POST');career_reply(405,['success'=>false,'message'=>'GET or POST required']);}
 require_once __DIR__.'/../../db.php';$pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
 $uid=premium_bearer_user($pdo);if($uid===null)career_reply(401,['success'=>false,'message'=>'Login required']);
 if($method==='GET'){
  $action=$_GET['action']??'';
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
   $q=$pdo->prepare("SELECT p.user_id AS id,p.display_name,p.role_name,p.organization,p.city FROM career_profiles p JOIN users u ON u.id=p.user_id WHERE p.status='approved' AND u.is_registered=1 AND p.user_id<? ORDER BY p.user_id DESC LIMIT 26");$q->execute([$before]);
  }elseif($action==='my_profile'){
   $q=$pdo->prepare('SELECT display_name,role_name,organization,city,status FROM career_profiles WHERE user_id=?');$q->execute([$uid]);career_reply(200,['success'=>true,'profile'=>$q->fetch(PDO::FETCH_ASSOC)?:null]);
  }else throw new DomainException('Unknown action');
  $rows=$q->fetchAll(PDO::FETCH_ASSOC);$more=count($rows)>25;if($more)array_pop($rows);
  career_reply(200,['success'=>true,'data'=>$rows,'next_before_id'=>$more?(string)end($rows)['id']:null]);
 }
 $raw=file_get_contents('php://input',false,null,0,8193);
 if($raw===false||strlen($raw)>8192)career_reply(413,['success'=>false,'message'=>'Request too large']);
 $b=json_decode($raw,true);if(!is_array($b)||array_is_list($b))throw new DomainException('JSON object required');
 $action=$b['action']??'';
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
  $q=$pdo->prepare("INSERT INTO career_profiles(user_id,display_name,role_name,organization,city,status,updated_at) VALUES(?,?,?,?,?,'pending',UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE display_name=VALUES(display_name),role_name=VALUES(role_name),organization=VALUES(organization),city=VALUES(city),status='pending',revision=revision+1,updated_at=VALUES(updated_at)");$q->execute([$uid,$name,$role,$org,$city]);
 }elseif($action==='hide_profile'){
  $q=$pdo->prepare("UPDATE career_profiles SET status='hidden',revision=revision+1,updated_at=UTC_TIMESTAMP() WHERE user_id=?");$q->execute([$uid]);
 }else throw new DomainException('Unknown action');
 $pdo->commit();career_reply(200,['success'=>true,'new_alerts'=>$count]);
}catch(DomainException $e){if(isset($pdo)&&$pdo->inTransaction())$pdo->rollBack();career_reply(422,['success'=>false,'message'=>$e->getMessage()]);}
catch(Throwable $e){if(isset($pdo)&&$pdo->inTransaction())$pdo->rollBack();error_log('Career API: '.$e->getMessage());career_reply(500,['success'=>false,'message'=>'Career service unavailable']);}
