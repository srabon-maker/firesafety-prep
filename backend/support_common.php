<?php
declare(strict_types=1);
function support_id(mixed $v): int {
    if ((!is_string($v)&&!is_int($v))||!preg_match('/^[1-9][0-9]*$/D',(string)$v)) throw new DomainException('Invalid ID');
    $id=filter_var($v,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if($id===false)throw new DomainException('Invalid ID');return $id;
}
function support_text(mixed $v,int $limit):string {
    if(!is_string($v)||!preg_match('//u',$v)||trim($v)===''||mb_strlen(trim($v),'UTF-8')>$limit)throw new DomainException('সঠিক লেখা দিন।');
    return trim($v);
}
function support_thread(PDO $pdo,int $ticket,?int $before=null):array{
    $where='ticket_id=?';$args=[$ticket];
    if($before!==null){$where.=' AND id<?';$args[]=$before;}
    $q=$pdo->prepare("SELECT id,sender,body,created_at FROM support_messages WHERE $where ORDER BY id DESC LIMIT 51");$q->execute($args);
    $rows=$q->fetchAll(PDO::FETCH_ASSOC);$more=count($rows)>50;if($more)array_pop($rows);
    foreach($rows as &$row)$row['id']=(string)$row['id'];unset($row);
    $next=$more?$rows[count($rows)-1]['id']:null;
    return ['messages'=>array_reverse($rows),'next_before_id'=>$next];
}
function support_add(PDO $pdo,int $ticket,string $sender,string $body):void{
    $q=$pdo->prepare('INSERT INTO support_messages(ticket_id,sender,body,created_at) VALUES (?,?,?,UTC_TIMESTAMP())');$q->execute([$ticket,$sender,$body]);
    $q=$pdo->prepare('UPDATE support_tickets SET status=?,updated_at=UTC_TIMESTAMP() WHERE id=?');$q->execute([$sender==='admin'?'answered':'open',$ticket]);
}
