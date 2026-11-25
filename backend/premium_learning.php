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
 $q=$pdo->prepare('SELECT 1 FROM model_tests mt WHERE mt.id=? AND '.premium_test_marked());
 $q->execute([$testId]);return !$q->fetchColumn();
}
