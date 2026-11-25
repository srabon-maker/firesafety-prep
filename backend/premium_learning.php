<?php
declare(strict_types=1);
require_once __DIR__.'/premium_access.php';
// Fixed SQL fragments only: no request input is interpolated.
function premium_question_marked():string{
 return 'EXISTS (SELECT 1 FROM premium_question_items pqi WHERE pqi.question_id=q.id)';
}
function premium_note_marked():string{
 return 'EXISTS (SELECT 1 FROM premium_note_items pni WHERE pni.note_id=n.id)';
}
function premium_test_marked():string{
 return '(EXISTS (SELECT 1 FROM premium_test_items pti WHERE pti.test_id=mt.id) OR EXISTS (SELECT 1 FROM model_test_questions pmq JOIN premium_question_items pqi ON pqi.question_id=pmq.question_id WHERE pmq.test_id=mt.id))';
}
function premium_has_access(PDO $pdo):bool{
 return premium_active($pdo,premium_bearer_user($pdo))!==null;
}
function premium_new_test_allowed(PDO $pdo,int $testId,int $uid):bool{
 if(premium_active($pdo,$uid)!==null)return true;
 $mode=premium_policy($pdo)['effective_mode'];
 $q=$pdo->prepare('SELECT 1 FROM model_tests mt WHERE mt.id=? AND '.premium_effective_test($mode));
 $q->execute([$testId]);return !$q->fetchColumn();
}

/** The database clock is authoritative. One policy snapshot per request.
 * Missing/invalid schema is an error, never an accidental free-mode fallback.
 */
function premium_policy(PDO $pdo):array {
 $row=$pdo->query("SELECT mode,starts_at,CASE WHEN mode='free' OR (starts_at IS NOT NULL AND starts_at>UTC_TIMESTAMP()) THEN 'free' ELSE mode END AS effective_mode FROM premium_access_policy WHERE id=1")->fetch(PDO::FETCH_ASSOC);
 if(!$row||!in_array($row['effective_mode'],['free','selected','all'],true))throw new RuntimeException('Premium access policy unavailable');
 return $row;
}
function premium_effective_mark(string $mode,string $marked,string $all='1'):string {
 return match($mode){'free'=>'0','selected'=>$marked,'all'=>$all,default=>throw new RuntimeException('Invalid access mode')};
}
function premium_effective_question(string $mode):string {
 return premium_effective_mark($mode,premium_question_marked());
}
function premium_effective_note(string $mode):string {
 // Public legacy attachments cannot be secured retroactively; keep these free in all-mode.
 $safe="(COALESCE(TRIM(n.file_url),'')='' AND LOWER(COALESCE(n.content,'')) NOT REGEXP 'https?:|uploads/|<[[:space:]]*(img|iframe|object|embed|video|audio|a)([[:space:]>]|$)')";
 return premium_effective_mark($mode,premium_note_marked(),$safe);
}
function premium_effective_test(string $mode):string {
 return premium_effective_mark($mode,premium_test_marked());
}
function premium_effective_interview(string $mode):string {
 return premium_effective_mark($mode,'EXISTS (SELECT 1 FROM premium_interview_items pi WHERE pi.content_id=homepage_content.id)');
}
function premium_policy_public(array $policy):array {
 return ['mode'=>$policy['effective_mode'],'scheduled_mode'=>$policy['mode'],'starts_at'=>$policy['starts_at']===null?null:str_replace(' ','T',(string)$policy['starts_at']).'Z'];
}
