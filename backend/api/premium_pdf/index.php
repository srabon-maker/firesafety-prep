<?php
declare(strict_types=1);
header('Cache-Control: no-store, private');
header('Referrer-Policy: no-referrer');
header('X-Content-Type-Options: nosniff');
function pp_reply(int $code,array $data):never{
 header('Content-Type: application/json; charset=utf-8');http_response_code($code);echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_INVALID_UTF8_SUBSTITUTE);exit;
}
try{
 require_once __DIR__.'/../../db.php';
 require_once __DIR__.'/../../premium_access.php';
 require_once __DIR__.'/../../premium_pdf_storage.php';
 $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
 $method=$_SERVER['REQUEST_METHOD']??'GET';
 if($method==='POST'){
  $uid=premium_bearer_user($pdo);
  if($uid===null)pp_reply(401,['success'=>false,'message'=>'Login required']);
  if(premium_active($pdo,$uid)===null)pp_reply(403,['success'=>false,'message'=>'Premium required']);
  $raw=file_get_contents('php://input',false,null,0,1025);if($raw===false||strlen($raw)>1024)pp_reply(413,['success'=>false]);
  $body=json_decode($raw,true);$id=filter_var(is_array($body)?($body['note_id']??null):null,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
  if($id===false)pp_reply(422,['success'=>false,'message'=>'Invalid note']);
  $pdo->beginTransaction();
  $q=$pdo->prepare('SELECT id FROM users WHERE id=? AND is_registered=1 FOR UPDATE');$q->execute([$uid]);if(!$q->fetchColumn()){$pdo->rollBack();pp_reply(401,['success'=>false]);}
  $q=$pdo->prepare("SELECT p.storage_name FROM premium_note_pdfs p JOIN premium_note_items i ON i.note_id=p.note_id JOIN notes n ON n.id=p.note_id WHERE p.note_id=? AND n.status='published'");$q->execute([$id]);$name=$q->fetchColumn();
  if(!$name){$pdo->rollBack();pp_reply(404,['success'=>false,'message'=>'PDF unavailable']);}
  premium_pdf_path((string)$name);
  $pdo->prepare('DELETE FROM premium_pdf_downloads WHERE user_id=? AND expires_at<=UTC_TIMESTAMP()')->execute([$uid]);
  $q=$pdo->prepare('SELECT COUNT(*) FROM premium_pdf_downloads WHERE user_id=?');$q->execute([$uid]);
  if((int)$q->fetchColumn()>=5){$pdo->rollBack();pp_reply(429,['success'=>false,'message'=>'Please retry later']);}
  $token=bin2hex(random_bytes(32));
  $q=$pdo->prepare('INSERT INTO premium_pdf_downloads(token_hash,user_id,note_id,expires_at) VALUES (?,?,?,UTC_TIMESTAMP()+INTERVAL 90 SECOND)');$q->execute([hash('sha256',$token),$uid,$id]);$pdo->commit();
  pp_reply(200,['success'=>true,'url'=>'https://fire.manobikishwarganj.com/api/premium_pdf/index.php?download='.$token,'expires_in'=>90]);
 }
 if($method!=='GET'){header('Allow: GET, POST');pp_reply(405,['success'=>false]);}
 $token=$_GET['download']??'';
 if(!is_string($token)||!preg_match('/^[a-f0-9]{64}$/D',$token))pp_reply(404,['success'=>false]);
 $pdo->beginTransaction();
 $q=$pdo->prepare("SELECT d.user_id,d.note_id,p.storage_name,p.size_bytes FROM premium_pdf_downloads d JOIN premium_note_pdfs p ON p.note_id=d.note_id JOIN premium_note_items i ON i.note_id=d.note_id JOIN notes n ON n.id=d.note_id JOIN users u ON u.id=d.user_id WHERE d.token_hash=? AND d.expires_at>UTC_TIMESTAMP() AND n.status='published' AND u.is_registered=1 FOR UPDATE");
 $hash=hash('sha256',$token);$q->execute([$hash]);$row=$q->fetch(PDO::FETCH_ASSOC);
 if(!$row||premium_active($pdo,(int)$row['user_id'])===null){$pdo->rollBack();pp_reply(404,['success'=>false]);}
 $path=premium_pdf_path($row['storage_name']);$size=filesize($path);
 if($size===false||$size!==(int)$row['size_bytes']||$size>PREMIUM_PDF_MAX)throw new RuntimeException('Invalid private file size');
 $stream=fopen($path,'rb');if($stream===false)throw new RuntimeException('Unable to read file');
 $q=$pdo->prepare('DELETE FROM premium_pdf_downloads WHERE token_hash=?');$q->execute([$hash]);if($q->rowCount()!==1)throw new RuntimeException('Download already consumed');
 $pdo->commit();
 header('Content-Type: application/pdf');header('Content-Disposition: attachment; filename="fire-safety-note.pdf"');header('Content-Length: '.(string)$size);header('Content-Security-Policy: sandbox');fpassthru($stream);fclose($stream);exit;
}catch(Throwable $e){
 if(isset($pdo)&&$pdo instanceof PDO&&$pdo->inTransaction())$pdo->rollBack();
 error_log('Private PDF: '.$e->getMessage());pp_reply(503,['success'=>false,'message'=>'PDF temporarily unavailable']);
}
