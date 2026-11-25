<?php
declare(strict_types=1);
// Shared, server-authoritative entitlement. Never trust client-provided user IDs or premium flags.
function premium_bearer_user(PDO $pdo): ?int {
    $header=$_SERVER['HTTP_AUTHORIZATION']??$_SERVER['REDIRECT_HTTP_AUTHORIZATION']??'';
    if(!$header&&function_exists('getallheaders')){
        foreach(getallheaders() as $k=>$v)if(strcasecmp($k,'Authorization')===0){$header=$v;break;}
    }
    if(!is_string($header)||!preg_match('/^Bearer\s+([a-f0-9]{64})$/iD',trim($header),$m))return null;
    $q=$pdo->prepare('SELECT u.id FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>NOW() AND u.is_registered=1 LIMIT 1');
    $q->execute([hash('sha256',$m[1])]);$uid=$q->fetchColumn();
    return $uid===false?null:(int)$uid;
}
function premium_active(PDO $pdo,?int $uid): ?string {
    if($uid===null)return null;
    $q=$pdo->prepare('SELECT expires_at FROM premium_memberships WHERE user_id=? AND expires_at>UTC_TIMESTAMP()');
    $q->execute([$uid]);$v=$q->fetchColumn();
    return $v===false?null:str_replace(' ','T',(string)$v).'Z';
}
