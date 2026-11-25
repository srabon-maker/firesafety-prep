<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../premium_learning.php';

function exam_reply(int $status, array $body): never {
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function exam_user(PDO $pdo): int {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!$header && function_exists('getallheaders')) {
        foreach (getallheaders() as $key=>$value) if (strcasecmp($key,'Authorization')===0) {$header=(string)$value;break;}
    }
    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($header), $m)) exam_reply(401,['success'=>false,'message'=>'পরীক্ষা দিতে লগইন করুন।']);
    $q=$pdo->prepare('SELECT user_id FROM auth_sessions WHERE token_hash=? AND expires_at>NOW() LIMIT 1');
    $q->execute([hash('sha256',$m[1])]);
    $id=$q->fetchColumn();
    if(!$id) exam_reply(401,['success'=>false,'message'=>'সেশন শেষ হয়েছে। আবার লগইন করুন।']);
    return (int)$id;
}
function exam_input(): array {
    $raw=file_get_contents('php://input');
    if($raw===false || strlen($raw)>32768) exam_reply(413,['success'=>false,'message'=>'অনুরোধটি অনেক বড়।']);
    $data=json_decode($raw,true);
    if(!is_array($data)) exam_reply(400,['success'=>false,'message'=>'সঠিক JSON পাঠান।']);
    return $data;
}
function exam_test(PDO $pdo,int $id): array {
    $hasRandom=(bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'randomize_questions'")->fetch(PDO::FETCH_ASSOC);
    $randomSelect=$hasRandom?',randomize_questions':'';
    $q=$pdo->prepare("SELECT id,title,description,exam_instructions,duration_minutes,total_marks,pass_marks,starts_at,ends_at,negative_marks_per_question,max_attempts,results_released".$randomSelect." FROM model_tests WHERE id=? AND status='published' LIMIT 1");

    $q->execute([$id]);$row=$q->fetch(PDO::FETCH_ASSOC);
    if(!$row) exam_reply(404,['success'=>false,'message'=>'পরীক্ষাটি পাওয়া যায়নি বা প্রকাশিত নয়।']);
    $now=time();
    if(!empty($row['starts_at']) && strtotime((string)$row['starts_at'])>$now) exam_reply(409,['success'=>false,'message'=>'পরীক্ষাটি এখনো শুরু হয়নি।']);
    if(!empty($row['ends_at']) && strtotime((string)$row['ends_at'])<=$now) exam_reply(409,['success'=>false,'message'=>'পরীক্ষার সময়সীমা শেষ হয়েছে।']);
    return $row;
}
function exam_model_test_schema_ready(PDO $pdo): bool {
    $requiredTables = ['model_test_attempts', 'model_test_attempt_questions'];
    $tableCheck = $pdo->prepare(
        "SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name IN (?, ?)"
    );
    $tableCheck->execute($requiredTables);
    if ((int)$tableCheck->fetchColumn() !== count($requiredTables)) return false;

    $columnCheck = $pdo->prepare(
        "SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'model_tests'
           AND column_name IN ('max_attempts', 'results_released')"
    );
    $columnCheck->execute();
    return (int)$columnCheck->fetchColumn() === 2;
}

function exam_public_question(array $r,bool $reveal=false): array {
    $item=['id'=>(int)$r['id'],'order'=>(int)$r['question_order'],'question'=>$r['question_text'],
      'category'=>(string)($r['category'] ?? 'অন্যান্য'),
      'options'=>['A'=>$r['option_a'],'B'=>$r['option_b'],'C'=>$r['option_c'],'D'=>$r['option_d']],
      'selected_answer'=>$r['selected_answer']];
    if($reveal){$item['correct_answer']=$r['correct_answer'];$item['explanation']=$r['explanation'];}
    return $item;
}
try {
    if(!isset($pdo)||!$pdo instanceof PDO) throw new RuntimeException('Database unavailable');
    $pdo->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);
    $method=$_SERVER['REQUEST_METHOD']??'GET';
    $action=(string)($_GET['action']??'list');

    if($method==='GET' && $action==='practice_dashboard'){
        $userId=exam_user($pdo);
        $settings=$pdo->prepare('SELECT daily_target FROM student_practice_settings WHERE user_id=? LIMIT 1');
        $settings->execute([$userId]);
        $target=(int)($settings->fetchColumn()?:10);
        $today=$pdo->prepare("SELECT COALESCE(SUM(total_questions),0) AS questions,COALESCE(SUM(correct_count),0) AS correct,COUNT(*) AS sessions FROM student_practice_sessions WHERE user_id=? AND completed_at>=CURDATE() AND completed_at<CURDATE()+INTERVAL 1 DAY");
        $today->execute([$userId]);$todayRow=$today->fetch(PDO::FETCH_ASSOC)?:[];
        $history=$pdo->prepare("SELECT DATE(completed_at) AS practice_date,SUM(total_questions) AS questions,SUM(correct_count) AS correct,COUNT(*) AS sessions FROM student_practice_sessions WHERE user_id=? AND completed_at>=CURDATE()-INTERVAL 6 DAY GROUP BY DATE(completed_at) ORDER BY practice_date ASC");
        $history->execute([$userId]);$historyRows=$history->fetchAll(PDO::FETCH_ASSOC);
        $subjects=$pdo->prepare("SELECT category, SUM(total_questions) AS questions, SUM(correct_count) AS correct, COUNT(*) AS sessions, MAX(completed_at) AS last_practiced FROM student_practice_sessions WHERE user_id=? AND completed_at>=CURDATE()-INTERVAL 30 DAY GROUP BY category HAVING SUM(total_questions)>0 ORDER BY (SUM(correct_count)/SUM(total_questions)) ASC, SUM(total_questions) DESC LIMIT 5");
        $subjects->execute([$userId]);$subjectRows=$subjects->fetchAll(PDO::FETCH_ASSOC);
        $total=$pdo->prepare('SELECT COALESCE(SUM(total_questions),0) AS questions,COALESCE(SUM(correct_count),0) AS correct,COUNT(*) AS sessions FROM student_practice_sessions WHERE user_id=?');
        $total->execute([$userId]);$totalRow=$total->fetch(PDO::FETCH_ASSOC)?:[];
        $dates=$pdo->prepare("SELECT DISTINCT DATE(completed_at) AS practice_date FROM student_practice_sessions WHERE user_id=? AND completed_at>=CURDATE()-INTERVAL 60 DAY ORDER BY practice_date DESC");
        $dates->execute([$userId]);$dateRows=$dates->fetchAll(PDO::FETCH_COLUMN);
        $streak=0;$expected=date('Y-m-d');
        if(!empty($dateRows) && $dateRows[0]===date('Y-m-d',strtotime('-1 day')))$expected=date('Y-m-d',strtotime('-1 day'));
        foreach($dateRows as $date){if($date!==$expected)break;$streak++;$expected=date('Y-m-d',strtotime($expected.' -1 day'));}
        exam_reply(200,['success'=>true,'data'=>[
            'daily_target'=>$target,
            'today'=>['questions'=>(int)($todayRow['questions']??0),'correct'=>(int)($todayRow['correct']??0),'sessions'=>(int)($todayRow['sessions']??0)],
            'weekly'=>array_map(static fn($r)=>['date'=>$r['practice_date'],'questions'=>(int)$r['questions'],'correct'=>(int)$r['correct']],$historyRows),
            'weak_subjects'=>array_map(static fn($r)=>['category'=>$r['category'],'questions'=>(int)$r['questions'],'correct'=>(int)$r['correct'],'accuracy'=>(int)round(((int)$r['correct']/max(1,(int)$r['questions']))*100),'sessions'=>(int)$r['sessions'],'last_practiced'=>$r['last_practiced']],$subjectRows),
            'overall'=>['questions'=>(int)($totalRow['questions']??0),'correct'=>(int)($totalRow['correct']??0),'sessions'=>(int)($totalRow['sessions']??0),'streak'=>$streak]
        ]]);
    }

    if($method==='GET' && $action==='practice_questions'){
        $userId=exam_user($pdo);
        $category=trim((string)($_GET['category']??''));
        $difficulty=strtolower(trim((string)($_GET['difficulty']??'all')));
        $limit=(int)($_GET['limit']??15);
        $limit=max(5,min(20,$limit));
        if($category==='' || mb_strlen($category)>100)exam_reply(422,['success'=>false,'message'=>'সঠিক বিষয় নির্বাচন করুন।']);
        if(!in_array($difficulty,['all','easy','medium','hard'],true))exam_reply(422,['success'=>false,'message'=>'সঠিক Difficulty নির্বাচন করুন।']);
        $where="q.status='published' AND q.is_archived=0 AND q.category=? AND q.correct_answer IN ('A','B','C','D')";
        if(premium_active($pdo,premium_bearer_user($pdo))===null)$where.=' AND NOT ('.premium_question_marked().')';
        $params=[$category];
        if($difficulty!=='all'){$where.=' AND difficulty=?';$params[]=$difficulty;}
        $q=$pdo->prepare("SELECT id,category,question,option_a,option_b,option_c,option_d,correct_answer,explanation,difficulty FROM questions q WHERE ".$where." ORDER BY RAND() LIMIT ".$limit);
        $q->execute($params);
        $rows=$q->fetchAll(PDO::FETCH_ASSOC);
        foreach($rows as &$row){
            $row['id']=(int)$row['id'];
            $row['options']=['A'=>$row['option_a'],'B'=>$row['option_b'],'C'=>$row['option_c'],'D'=>$row['option_d']];
            unset($row['option_a'],$row['option_b'],$row['option_c'],$row['option_d']);
        }
        unset($row);
        exam_reply(200,['success'=>true,'data'=>$rows,'count'=>count($rows),'category'=>$category,'difficulty'=>$difficulty]);
    }

    if($method==='GET' && $action==='active_attempts'){
        $userId=exam_user($pdo);
        $q=$pdo->prepare("SELECT a.id AS attempt_id,a.test_id,t.title,a.started_at,a.expires_at,a.question_count,a.total_marks,a.negative_marks_per_question FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id WHERE a.user_id=? AND a.status='in_progress' AND a.expires_at>NOW() AND t.status='published' ORDER BY a.expires_at ASC");
        $q->execute([$userId]);
        $rows=$q->fetchAll(PDO::FETCH_ASSOC);
        foreach($rows as &$row){
            $row['attempt_id']=(int)$row['attempt_id'];
            $row['test_id']=(int)$row['test_id'];
            $row['question_count']=(int)$row['question_count'];
            $row['remaining_seconds']=max(0,strtotime((string)$row['expires_at'])-time());
        }
        unset($row);
        exam_reply(200,['success'=>true,'data'=>$rows]);
    }

    if($method==='GET' && $action==='list'){
        $active=premium_has_access($pdo);$marked=premium_test_marked();$locked=$active?'0':$marked;
        $scope=(!$active&&($_GET['premium_preview']??'')!=='1')?" AND NOT ($marked)":'';
        $hasRandom=(bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'randomize_questions'")->fetch(PDO::FETCH_ASSOC);
        $hasNegative=(bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'negative_marks_per_question'")->fetch(PDO::FETCH_ASSOC);
        $randomSelect=$hasRandom?',mt.randomize_questions':'';
        $negativeSelect=$hasNegative?',mt.negative_marks_per_question':'';
        $randomGroup=$hasRandom?',mt.randomize_questions':'';
        $negativeGroup=$hasNegative?',mt.negative_marks_per_question':'';
        $q=$pdo->query("SELECT mt.id,mt.title,mt.description,mt.exam_instructions,$marked AS premium_only,$locked AS locked,mt.duration_minutes,mt.total_marks,mt.pass_marks,mt.starts_at,mt.ends_at,mt.max_attempts,COUNT(mq.id) AS question_count,mt.results_released".$randomSelect.$negativeSelect." FROM model_tests mt LEFT JOIN model_test_questions mq ON mq.test_id=mt.id WHERE mt.status='published' $scope AND (mt.starts_at IS NULL OR mt.starts_at<=NOW()) AND (mt.ends_at IS NULL OR mt.ends_at>NOW()) GROUP BY mt.id,mt.title,mt.description,mt.exam_instructions,mt.duration_minutes,mt.total_marks,mt.pass_marks,mt.starts_at,mt.ends_at,mt.max_attempts,mt.results_released".$randomGroup.$negativeGroup." ORDER BY mt.starts_at IS NULL,mt.starts_at ASC,mt.id DESC LIMIT 100");
        $rows=$q->fetchAll(PDO::FETCH_ASSOC);
        foreach($rows as &$r){
            $r['locked']=(bool)$r['locked'];$r['premium_only']=(bool)$r['premium_only'];$r['id']=(int)$r['id'];$r['duration_minutes']=(int)$r['duration_minutes'];$r['question_count']=(int)$r['question_count'];$r['total_marks']=(float)$r['total_marks'];
            $r['pass_marks']=$r['pass_marks']===null?null:(float)$r['pass_marks'];
            $r['max_attempts']=(int)$r['max_attempts'];
            $r['randomize_questions']=isset($r['randomize_questions'])?(bool)$r['randomize_questions']:false;
            $r['negative_marks_per_question']=isset($r['negative_marks_per_question'])?(float)$r['negative_marks_per_question']:0.0;
        }
        unset($r); exam_reply(200,['success'=>true,'data'=>$rows]);
    }

    if($method==='GET' && $action==='result'){
        $userId=exam_user($pdo);
        $attemptId=(int)($_GET['attempt_id']??0);
        if($attemptId<1) exam_reply(422,['success'=>false,'message'=>'সঠিক Attempt নির্বাচন করুন।']);
        exam_reply(200,['success'=>true,'result'=>exam_result_payload($pdo,$attemptId,$userId)]);
    }

    if($method==='GET' && $action==='my_results'){
        $userId=exam_user($pdo);
        $q=$pdo->prepare("SELECT a.id AS attempt_id,a.test_id,t.title,a.started_at,a.submitted_at,a.question_count,a.total_marks,a.score,a.correct_count,a.incorrect_count,a.unanswered_count,a.passed FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id WHERE a.user_id=? AND a.status IN ('submitted','expired') AND t.results_released=1 ORDER BY a.submitted_at DESC,a.id DESC LIMIT 100");
        $q->execute([$userId]); exam_reply(200,['success'=>true,'data'=>$q->fetchAll(PDO::FETCH_ASSOC)]);
    }

    if($method!=='POST') exam_reply(405,['success'=>false,'message'=>'Unsupported method.']);
    $userId=exam_user($pdo);$data=exam_input();
    if($action==='practice_target'){
        $target=(int)($data['daily_target']??0);
        if(!in_array($target,[5,10,15,20,30,50],true))exam_reply(422,['success'=>false,'message'=>'দৈনিক লক্ষ্য ৫, ১০, ১৫, ২০, ৩০ বা ৫০ নির্বাচন করুন।']);
        $save=$pdo->prepare('INSERT INTO student_practice_settings (user_id,daily_target) VALUES (?,?) ON DUPLICATE KEY UPDATE daily_target=VALUES(daily_target),updated_at=CURRENT_TIMESTAMP');
        $save->execute([$userId,$target]);
        exam_reply(200,['success'=>true,'daily_target'=>$target]);
    }
    if($action==='practice_complete'){
        $category=trim((string)($data['category']??''));
        $difficulty=strtolower(trim((string)($data['difficulty']??'all')));
        $total=(int)($data['total_questions']??0);$correct=(int)($data['correct_count']??-1);
        if($category===''||mb_strlen($category)>100)exam_reply(422,['success'=>false,'message'=>'সঠিক বিষয় নির্বাচন করুন।']);
        if(!in_array($difficulty,['all','easy','medium','hard'],true))exam_reply(422,['success'=>false,'message'=>'সঠিক Difficulty নির্বাচন করুন।']);
        if($total<1||$total>20||$correct<0||$correct>$total)exam_reply(422,['success'=>false,'message'=>'অনুশীলনের ফলাফল সঠিক নয়।']);
        $save=$pdo->prepare('INSERT INTO student_practice_sessions (user_id,category,difficulty,total_questions,correct_count) VALUES (?,?,?,?,?)');
        $save->execute([$userId,$category,$difficulty,$total,$correct]);
        exam_reply(201,['success'=>true,'session_id'=>(int)$pdo->lastInsertId()]);
    }
    $testId=(int)($data['test_id']??0);
    if($testId<1) exam_reply(422,['success'=>false,'message'=>'সঠিক পরীক্ষা নির্বাচন করুন।']);

    if($action==='start'){
        // Give a clear deployment instruction instead of a generic HTTP 500
        // when the required one-time database migrations have not been run.
        if (!exam_model_test_schema_ready($pdo)) {
            exam_reply(503, [
                'success' => false,
                'code' => 'MODEL_TEST_MIGRATION_REQUIRED',
                'message' => 'মডেল টেস্ট চালু করার জন্য সার্ভারের ডেটাবেজ আপডেট বাকি। Admin-কে model test migrations দুটি phpMyAdmin-এ চালাতে বলুন।',
            ]);
        }
        $existing=$pdo->prepare("SELECT id FROM model_test_attempts WHERE test_id=? AND user_id=? AND status='in_progress' ORDER BY id DESC LIMIT 1");
        $existing->execute([$testId,$userId]);$attemptId=(int)($existing->fetchColumn()?:0);
        if(!$attemptId){
            $test=exam_test($pdo,$testId);
            $pdo->beginTransaction();
            $policyLock=$pdo->prepare('SELECT max_attempts FROM model_tests WHERE id=? FOR UPDATE');
            $policyLock->execute([$testId]);
            $maxAttempts=(int)($policyLock->fetchColumn()?:0);
            // Existing owned attempts may finish; new attempts must pass the current policy.
            if(!premium_new_test_allowed($pdo,$testId,$userId)){$pdo->rollBack();exam_reply(403,['success'=>false,'code'=>'PREMIUM_REQUIRED','message'=>'এই মডেল টেস্টটি Premium সদস্যদের জন্য।']);}
            if($maxAttempts>0){
                $count=$pdo->prepare("SELECT COUNT(*) FROM model_test_attempts WHERE test_id=? AND user_id=?");
                $count->execute([$testId,$userId]);
                if((int)$count->fetchColumn()>=$maxAttempts){
                    $pdo->rollBack();
                    exam_reply(429,['success'=>false,'message'=>'এই পরীক্ষার সর্বোচ্চ Attempt সংখ্যা শেষ হয়েছে।']);
                }
            }
            $now=new DateTimeImmutable('now');
            $duration=(int)$test['duration_minutes'];
            $expires=$now->modify('+'.$duration.' minutes');
            if(!empty($test['ends_at'])){$hardEnd=new DateTimeImmutable((string)$test['ends_at']);if($hardEnd<$expires)$expires=$hardEnd;}
            $ins=$pdo->prepare("INSERT INTO model_test_attempts (test_id,user_id,status,started_at,expires_at,question_count,total_marks,pass_marks,negative_marks_per_question) VALUES (?,?,'in_progress',?,?,0,0,?,?)");
            $ins->execute([$testId,$userId,$now->format('Y-m-d H:i:s'),$expires->format('Y-m-d H:i:s'),$test['pass_marks'],$test['negative_marks_per_question']]);
            $attemptId=(int)$pdo->lastInsertId();
            $order=((int)($test['randomize_questions']??0)===1)?'RAND()':'mtq.question_order ASC';
            $q=$pdo->prepare("SELECT q.id,q.question,q.option_a,q.option_b,q.option_c,q.option_d,q.correct_answer,q.explanation,mtq.marks FROM model_test_questions mtq JOIN questions q ON q.id=mtq.question_id WHERE mtq.test_id=? ORDER BY ".$order);
            $q->execute([$testId]);$questions=$q->fetchAll(PDO::FETCH_ASSOC);
            if(!$questions){$pdo->rollBack();exam_reply(409,['success'=>false,'message'=>'এই পরীক্ষায় কোনো প্রশ্ন যুক্ত নেই।']);}
            $add=$pdo->prepare("INSERT INTO model_test_attempt_questions (attempt_id,question_id,question_order,question_text,option_a,option_b,option_c,option_d,correct_answer,explanation,marks) VALUES (?,?,?,?,?,?,?,?,?,?,?)");
            $sum=0.0;
            foreach($questions as $i=>$question){$add->execute([$attemptId,(int)$question['id'],$i+1,$question['question'],$question['option_a'],$question['option_b'],$question['option_c'],$question['option_d'],strtoupper($question['correct_answer']),$question['explanation'],$question['marks']]);$sum+=(float)$question['marks'];}
            $upd=$pdo->prepare('UPDATE model_test_attempts SET question_count=?,total_marks=? WHERE id=?');$upd->execute([count($questions),$sum,$attemptId]);
            $pdo->commit();
        }
        exam_reply(200,['success'=>true,'attempt'=>exam_attempt_payload($pdo,$attemptId,$userId,false)]);
    }

    if($action==='answer'){
        $attemptId=(int)($data['attempt_id']??0);$questionId=(int)($data['question_id']??0);$answer=strtoupper(trim((string)($data['answer']??'')));
        if(!in_array($answer,['A','B','C','D'],true)) exam_reply(422,['success'=>false,'message'=>'A, B, C অথবা D নির্বাচন করুন।']);
        $q=$pdo->prepare("SELECT a.id,a.expires_at,a.status FROM model_test_attempts a WHERE a.id=? AND a.user_id=? LIMIT 1");$q->execute([$attemptId,$userId]);$attempt=$q->fetch(PDO::FETCH_ASSOC);
        if(!$attempt) exam_reply(404,['success'=>false,'message'=>'পরীক্ষার Attempt পাওয়া যায়নি।']);
        if($attempt['status']!=='in_progress'||strtotime($attempt['expires_at'])<=time()) exam_reply(409,['success'=>false,'message'=>'পরীক্ষার সময় শেষ। Submit/Result দেখুন।']);
        $up=$pdo->prepare('UPDATE model_test_attempt_questions SET selected_answer=?,answered_at=NOW() WHERE attempt_id=? AND question_id=?');$up->execute([$answer,$attemptId,$questionId]);
        if($up->rowCount()===0){$ck=$pdo->prepare('SELECT id FROM model_test_attempt_questions WHERE attempt_id=? AND question_id=?');$ck->execute([$attemptId,$questionId]);if(!$ck->fetchColumn())exam_reply(404,['success'=>false,'message'=>'প্রশ্নটি এই পরীক্ষার অংশ নয়।']);}
        exam_reply(200,['success'=>true,'saved'=>true]);
    }

    if($action==='submit'){
        $attemptId=(int)($data['attempt_id']??0);
        $pdo->beginTransaction();
        $q=$pdo->prepare('SELECT * FROM model_test_attempts WHERE id=? AND user_id=? FOR UPDATE');$q->execute([$attemptId,$userId]);$attempt=$q->fetch(PDO::FETCH_ASSOC);
        if(!$attempt){$pdo->rollBack();exam_reply(404,['success'=>false,'message'=>'পরীক্ষার Attempt পাওয়া যায়নি।']);}
        if($attempt['status']==='in_progress'){
            $test=['negative_marks_per_question'=>$attempt['negative_marks_per_question'],'pass_marks'=>$attempt['pass_marks']];
            $rows=$pdo->prepare('SELECT correct_answer,selected_answer,marks FROM model_test_attempt_questions WHERE attempt_id=?');$rows->execute([$attemptId]);$questions=$rows->fetchAll(PDO::FETCH_ASSOC);
            $correct=0;$incorrect=0;$unanswered=0;$earned=0.0;$negative=(float)$test['negative_marks_per_question'];
            foreach($questions as $row){if(empty($row['selected_answer'])){$unanswered++;continue;}if(strtoupper($row['selected_answer'])===strtoupper($row['correct_answer'])){$correct++;$earned+=(float)$row['marks'];}else{$incorrect++;$earned-=$negative;}}
            $earned=max(0.0,$earned);$pass=($attempt['total_marks']>0 && $test['pass_marks']!==null)?($earned >= (float)$test['pass_marks']):null;
            $status=(strtotime($attempt['expires_at'])<=time())?'expired':'submitted';
            $upd=$pdo->prepare('UPDATE model_test_attempts SET status=?,submitted_at=NOW(),score=?,correct_count=?,incorrect_count=?,unanswered_count=?,passed=? WHERE id=?');
            $upd->execute([$status,$earned,$correct,$incorrect,$unanswered,$pass===null?null:($pass?1:0),$attemptId]);
        }
        $pdo->commit();
        $release=$pdo->prepare('SELECT t.results_released FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id WHERE a.id=? AND a.user_id=?');
        $release->execute([$attemptId,$userId]);
        if(!(int)$release->fetchColumn()) exam_reply(200,['success'=>true,'result_released'=>false,'message'=>'পরীক্ষা জমা হয়েছে। Admin ফলাফল প্রকাশ করলে বিস্তারিত দেখতে পারবেন।']);
        exam_reply(200,['success'=>true,'result_released'=>true,'result'=>exam_result_payload($pdo,$attemptId,$userId)]);
    }

    if($action==='resume'){
        $attemptId=(int)($data['attempt_id']??0);
        exam_reply(200,['success'=>true,'attempt'=>exam_attempt_payload($pdo,$attemptId,$userId,false)]);
    }
    exam_reply(404,['success'=>false,'message'=>'Action পাওয়া যায়নি।']);
} catch(Throwable $e){
    if(isset($pdo)&&$pdo instanceof PDO&&$pdo->inTransaction())$pdo->rollBack();
    error_log('Model test API error: '.$e->getMessage());
    exam_reply(500,['success'=>false,'message'=>'পরীক্ষার অনুরোধ সম্পন্ন হয়নি।']);
}

function exam_attempt_payload(PDO $pdo,int $attemptId,int $userId,bool $reveal): array {
    $q=$pdo->prepare("SELECT a.id,a.test_id,a.started_at,a.expires_at,a.status,a.negative_marks_per_question,t.title,t.exam_instructions FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id WHERE a.id=? AND a.user_id=? LIMIT 1");
    $q->execute([$attemptId,$userId]);$a=$q->fetch(PDO::FETCH_ASSOC);
    if(!$a)exam_reply(404,['success'=>false,'message'=>'পরীক্ষার Attempt পাওয়া যায়নি।']);
    $rows=$pdo->prepare('SELECT question_id AS id,question_order,question_text,option_a,option_b,option_c,option_d,correct_answer,explanation,selected_answer FROM model_test_attempt_questions WHERE attempt_id=? ORDER BY question_order');$rows->execute([$attemptId]);
    $questions=array_map(static fn($r)=>exam_public_question($r,$reveal),$rows->fetchAll(PDO::FETCH_ASSOC));
    return ['attempt_id'=>(int)$a['id'],'test_id'=>(int)$a['test_id'],'title'=>$a['title'],'instructions'=>$a['exam_instructions'],'started_at'=>$a['started_at'],'expires_at'=>$a['expires_at'],'remaining_seconds'=>max(0,strtotime((string)$a['expires_at'])-time()),'status'=>$a['status'],'negative_marks_per_question'=>(float)$a['negative_marks_per_question'],'questions'=>$questions];
}
function exam_test_for_attempt(PDO $pdo,int $testId): array {
    $q=$pdo->prepare('SELECT negative_marks_per_question,pass_marks FROM model_tests WHERE id=?');$q->execute([$testId]);return $q->fetch(PDO::FETCH_ASSOC)?:['negative_marks_per_question'=>0,'pass_marks'=>0];
}
function exam_result_payload(PDO $pdo,int $attemptId,int $userId): array {
    $q=$pdo->prepare("SELECT a.*,t.title,t.results_released FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id WHERE a.id=? AND a.user_id=? AND a.status IN ('submitted','expired') AND t.results_released=1 LIMIT 1");
    $q->execute([$attemptId,$userId]);$a=$q->fetch(PDO::FETCH_ASSOC);
    if(!$a)exam_reply(409,['success'=>false,'message'=>'ফলাফল এখনো প্রস্তুত নয়।']);
    // Subject/category is sourced from the Question Bank's existing questions.category field.
    // Attempts retain question IDs; category edits in the Question Bank can therefore affect older reports.
    $rows=$pdo->prepare("SELECT aq.question_id AS id,aq.question_order,aq.question_text,aq.option_a,aq.option_b,aq.option_c,aq.option_d,aq.correct_answer,aq.explanation,aq.selected_answer,COALESCE(NULLIF(TRIM(q.category),''),'অন্যান্য') AS category,aq.marks FROM model_test_attempt_questions aq LEFT JOIN questions q ON q.id=aq.question_id WHERE aq.attempt_id=? ORDER BY aq.question_order");
    $rows->execute([$attemptId]);$questionRows=$rows->fetchAll(PDO::FETCH_ASSOC);
    $subjectMap=[];
    foreach($questionRows as $row){
        $name=trim((string)($row['category']??'')) ?: 'অন্যান্য';
        if(!isset($subjectMap[$name]))$subjectMap[$name]=['subject'=>$name,'total_questions'=>0,'correct_count'=>0,'incorrect_count'=>0,'unanswered_count'=>0,'score'=>0.0,'total_marks'=>0.0];
        $subjectMap[$name]['total_questions']++;
        $subjectMap[$name]['total_marks']+=(float)$row['marks'];
        $selected=strtoupper(trim((string)($row['selected_answer']??'')));
        if($selected===''){$subjectMap[$name]['unanswered_count']++;}
        elseif($selected===strtoupper((string)$row['correct_answer'])){$subjectMap[$name]['correct_count']++;$subjectMap[$name]['score']+=(float)$row['marks'];}
        else{$subjectMap[$name]['incorrect_count']++;$subjectMap[$name]['score']-=(float)$a['negative_marks_per_question'];}
    }
    foreach($subjectMap as &$subjectRow){$subjectRow['score']=max(0.0,$subjectRow['score']);$subjectRow['accuracy']=$subjectRow['total_questions']>0?round($subjectRow['correct_count']/$subjectRow['total_questions']*100,1):0.0;}
    unset($subjectRow);
    $subjects=array_values($subjectMap);
    return ['attempt_id'=>(int)$a['id'],'test_id'=>(int)$a['test_id'],'title'=>$a['title'],'status'=>$a['status'],'score'=>(float)$a['score'],'total_marks'=>(float)$a['total_marks'],'passed'=>$a['passed']===null?null:(bool)$a['passed'],'pass_marks'=>$a['pass_marks']===null?null:(float)$a['pass_marks'],'correct_count'=>(int)$a['correct_count'],'incorrect_count'=>(int)$a['incorrect_count'],'unanswered_count'=>(int)$a['unanswered_count'],'subject_performance'=>$subjects,'questions'=>array_map(static fn($r)=>exam_public_question($r,true),$questionRows)];
}
