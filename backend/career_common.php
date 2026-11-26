<?php
declare(strict_types=1);
function career_text(mixed $value,int $max,bool $required=false):string{
 if(!is_string($value)||!mb_check_encoding($value,'UTF-8'))throw new DomainException('Invalid text');
 $value=trim($value);
 if(mb_strlen($value,'UTF-8')>$max||($required&&$value==='')||preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/',$value))throw new DomainException('Invalid text length');
 return $value;
}
function career_public_text(mixed $value,int $max,bool $required=false):string{
 $value=career_text($value,$max,$required);
 if(preg_match('/@|https?:|www\.|(?:\p{Nd}[\s().+-]*){7}/iu',$value))throw new DomainException('Do not include phone numbers, email or links');
 return $value;
}
function career_url(mixed $value):string{
 $value=career_text($value,500);
 if($value==='')return '';
 $p=parse_url($value);
 if(!$p||($p['scheme']??'')!=='https'||empty($p['host'])||isset($p['user'])||isset($p['pass'])||!filter_var($value,FILTER_VALIDATE_URL))throw new DomainException('HTTPS link required');
 return $value;
}
function career_id(mixed $value):int{
 $id=filter_var($value,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
 if($id===false)throw new DomainException('Invalid ID');
 return $id;
}
function career_matches(PDO $pdo,array $pref,int $uid,bool $undelivered=false):array{
 if(empty($pref['enabled'])||($pref['keyword']===''&&$pref['location']===''))return [];
 $where="j.status='published' AND COALESCE(j.published_at,j.created_at)>=DATE_SUB(NOW(),INTERVAL 30 DAY) AND (j.application_deadline IS NULL OR j.application_deadline>=DATE(UTC_TIMESTAMP()+INTERVAL 6 HOUR))";
 $args=[];
 if($pref['keyword']!==''){$where.=" AND LOCATE(?,CONCAT_WS(' ',j.title,j.organization,j.requirements,c.name))>0";$args[]=$pref['keyword'];}
 if($pref['location']!==''){$where.=" AND LOCATE(?,COALESCE(j.location,''))>0";$args[]=$pref['location'];}
 if($undelivered){$where.=' AND NOT EXISTS(SELECT 1 FROM career_job_deliveries d WHERE d.user_id=? AND d.job_id=j.id)';$args[]=$uid;}
 $q=$pdo->prepare("SELECT j.id,j.title,j.organization,j.location,j.requirements,j.application_deadline,j.application_url AS apply_url FROM job_circulars j LEFT JOIN categories c ON c.id=j.category_id WHERE $where ORDER BY COALESCE(j.published_at,j.created_at) DESC,j.id DESC LIMIT 50");
 $q->execute($args);return $q->fetchAll(PDO::FETCH_ASSOC);
}

/** Private hosting storage; never place this directory inside a site's document root. */
function career_photo_dir(bool $create=false):string{
 $root=realpath((string)($_SERVER['DOCUMENT_ROOT']??''));
 $dir=getenv('CAREER_PROFILE_PHOTO_DIR');
 if(!is_string($dir)||$dir===''){
  // Standard cPanel account home, including /home2 and addon-domain roots.
  if(!preg_match('~^(/home[0-9]*/[^/]+)(?:/|$)~',(string)realpath(__DIR__),$m))throw new RuntimeException('Configure CAREER_PROFILE_PHOTO_DIR outside the web root');
  $dir=$m[1].'/.fire-safety-private/profile-photos';
 }
 if($dir[0]!=='/'||preg_match('~(?:^|/)\.\.(?:/|$)~',$dir)||$root===false||$root==='/')throw new RuntimeException('Invalid private photo storage configuration');
 $dir=rtrim($dir,'/');
 $parent=$dir;while(!file_exists($parent)&&$parent!=='/')$parent=dirname($parent);
 $realParent=realpath($parent);
 if($realParent===false)throw new RuntimeException('Invalid photo storage parent');
 $resolved=rtrim($realParent,'/').substr($dir,strlen($parent));
 if($resolved===$root||str_starts_with($resolved,$root.'/')||preg_match('~/(public_html|www)(/|$)~',$resolved))throw new RuntimeException('Photo storage must be outside web roots');
 if($create&&!is_dir($dir)&&!mkdir($dir,0700,true)&&!is_dir($dir))throw new RuntimeException('Photo storage unavailable');
 return $resolved;
}
function career_photo_file(string $key,bool $create=false):string{
 if(!preg_match('/^[a-f0-9]{32}$/D',$key))throw new DomainException('Invalid photo key');
 return career_photo_dir($create).'/'.$key.'.jpg';
}
function career_photo_read(string $key):?string{
 $path=career_photo_file($key);
 if(!is_file($path)||is_link($path)||filesize($path)>204800)return null;
 $bytes=file_get_contents($path,false,null,0,204801);
 return is_string($bytes)&&$bytes!==''&&strlen($bytes)<=204800?$bytes:null;
}
function career_photo_write(string $key,string $bytes):void{
 $path=career_photo_file($key,true);
 $handle=fopen($path,'xb');
 if($handle===false)throw new RuntimeException('Photo storage write failed');
 try{
  if(!chmod($path,0600)||fwrite($handle,$bytes)!==strlen($bytes)||!fflush($handle))throw new RuntimeException('Photo storage write failed');
 }catch(Throwable $e){fclose($handle);@unlink($path);throw $e;}
 fclose($handle);
}
function career_photo_delete(string $key):void{
 if(!preg_match('/^[a-f0-9]{32}$/D',$key))return;
 try{$path=career_photo_file($key);if(is_file($path)&&!unlink($path))error_log('Career photo cleanup failed');}
 catch(Throwable $e){error_log('Career photo cleanup: '.$e->getMessage());}
}
