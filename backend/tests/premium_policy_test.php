<?php
declare(strict_types=1);
require_once __DIR__.'/../premium_learning.php';
function check_policy(bool $condition,string $message):void{
 if(!$condition)throw new RuntimeException($message);
}
foreach(['free','selected','all'] as $mode){
 $q=premium_effective_question($mode);$n=premium_effective_note($mode);$t=premium_effective_test($mode);$i=premium_effective_interview($mode);
 if($mode==='free')check_policy([$q,$n,$t,$i]===['0','0','0','0'],'Free overrides every mark');
 if($mode==='selected')check_policy(str_contains($q,'premium_question_items')&&str_contains($n,'premium_note_items')&&str_contains($t,'model_test_questions')&&str_contains($i,'premium_interview_items'),'Selected and inherited marks');
 if($mode==='all')check_policy($q==='1'&&$t==='1'&&$i==='1'&&str_contains($n,'file_url')&&str_contains($n,'NOT REGEXP'),'Global mode excludes legacy public media');
}
try{premium_effective_question('unexpected');throw new LogicException('Invalid mode accepted');}catch(RuntimeException $e){check_policy($e->getMessage()==='Invalid access mode','Fail closed');}
$public=premium_policy_public(['mode'=>'all','effective_mode'=>'free','starts_at'=>'2027-01-01 06:00:00']);
check_policy($public===['mode'=>'free','scheduled_mode'=>'all','starts_at'=>'2027-01-01T06:00:00Z'],'Scheduled policy response');
echo "Premium policy tests passed\n";
