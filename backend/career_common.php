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
