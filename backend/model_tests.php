<?php
declare(strict_types=1);

require_once __DIR__ . '/admin_helpers.php';
require_admin();
require_once __DIR__ . '/db.php';

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}
if (!isset($pdo) || !($pdo instanceof PDO)) {
    http_response_code(500);
    exit('Database connection not found. Check db.php.');
}
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
function mt_h($value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
function mt_redirect(string $url): never {
    header('Location: ' . $url);
    exit;
}
function mt_table_exists(PDO $pdo, string $table): bool {
    $s = $pdo->prepare('SHOW TABLES LIKE ?');
    $s->execute([$table]);
    return (bool)$s->fetchColumn();
}

$errors = [];
$notice = '';
$categories = [];
$tests = [];
$questions = [];
$editing = null;
$selectedQuestionIds = [];

try {
    $categories = $pdo->query("
        SELECT id, name
        FROM categories
        WHERE category_type = 'test' AND is_active = 1
        ORDER BY sort_order ASC, name ASC
    ")->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    $errors[] = 'ক্যাটাগরি লোড করা যায়নি। categories টেবিলের কাঠামো যাচাই করুন।';
}

$hasRandomColumn = false;
try {
    $hasRandomColumn = (bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'randomize_questions'")->fetch(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    $errors[] = 'model_tests টেবিল পাওয়া যায়নি। আগে প্রয়োজনীয় SQL Migration চালান।';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (!hash_equals($_SESSION['csrf_token'], (string)($_POST['csrf_token'] ?? ''))) {
            throw new RuntimeException('নিরাপত্তা যাচাই ব্যর্থ হয়েছে। পেজ রিফ্রেশ করে আবার চেষ্টা করুন।');
        }
        $action = (string)($_POST['action'] ?? '');
        if ($action === 'delete_test') {
            $id = (int)($_POST['test_id'] ?? 0);
            if ($id < 1) throw new RuntimeException('ভুল টেস্ট আইডি।');
            $pdo->beginTransaction();
            $pdo->prepare('DELETE FROM model_test_questions WHERE test_id = ?')->execute([$id]);
            $pdo->prepare('DELETE FROM model_tests WHERE id = ?')->execute([$id]);
            $pdo->commit();
            mt_redirect('model_tests.php?deleted=1');
        }

        if ($action === 'save_test') {
            $id = (int)($_POST['test_id'] ?? 0);
            $title = trim((string)($_POST['title'] ?? ''));
            $description = trim((string)($_POST['description'] ?? ''));
            $categoryId = (int)($_POST['category_id'] ?? 0);
            $duration = max(1, (int)($_POST['duration_minutes'] ?? 30));
            $questionCount = max(1, (int)($_POST['question_count'] ?? 20));
            $passInput = trim((string)($_POST['pass_marks'] ?? ''));
            $status = (string)($_POST['status'] ?? 'draft');
            $random = (int)($_POST['randomize_questions'] ?? 0) === 1;
            $selectionMode = (string)($_POST['selection_mode'] ?? 'manual');
            $startsRaw = trim((string)($_POST['starts_at'] ?? ''));
            $endsRaw = trim((string)($_POST['ends_at'] ?? ''));

            if ($title === '') throw new RuntimeException('পরীক্ষার নাম লিখুন।');
            if (!in_array($status, ['draft', 'published', 'archived'], true)) throw new RuntimeException('স্ট্যাটাস সঠিক নয়।');
            if (!in_array($selectionMode, ['manual', 'random'], true)) throw new RuntimeException('প্রশ্ন নির্বাচনের ধরন সঠিক নয়।');

            $categoryName = null;
            if ($categoryId > 0) {
                $cs = $pdo->prepare("SELECT name FROM categories WHERE id = ? AND category_type = 'test' AND is_active = 1");
                $cs->execute([$categoryId]);
                $categoryName = $cs->fetchColumn();
                if (!$categoryName) throw new RuntimeException('নির্বাচিত ক্যাটাগরি সক্রিয় নয়।');
            }

            $startsAt = $startsRaw !== '' ? date('Y-m-d H:i:s', strtotime($startsRaw)) : null;
            $endsAt = $endsRaw !== '' ? date('Y-m-d H:i:s', strtotime($endsRaw)) : null;
            if ($startsRaw !== '' && !$startsAt) throw new RuntimeException('শুরুর তারিখ সঠিক নয়।');
            if ($endsRaw !== '' && !$endsAt) throw new RuntimeException('শেষের তারিখ সঠিক নয়।');
            if ($startsAt && $endsAt && strtotime($endsAt) < strtotime($startsAt)) throw new RuntimeException('শেষের সময় শুরুর সময়ের আগে হতে পারবে না।');

            $chosen = [];
            if ($selectionMode === 'random') {
                $sql = "SELECT id FROM questions";
                $params = [];
                if ($categoryName !== null) {
                    $sql .= " WHERE category = ?";
                    $params[] = $categoryName;
                }
                $sql .= " ORDER BY RAND() LIMIT " . (int)$questionCount;
                $qs = $pdo->prepare($sql);
                $qs->execute($params);
                $chosen = $qs->fetchAll(PDO::FETCH_COLUMN);
                if (count($chosen) < 1) throw new RuntimeException('নির্বাচিত ক্যাটাগরিতে কোনো প্রশ্ন পাওয়া যায়নি।');
                if (count($chosen) < $questionCount) {
                    throw new RuntimeException('প্রশ্নের সংখ্যা ' . count($chosen) . 'টি পাওয়া গেছে; আপনি ' . $questionCount . 'টি চেয়েছেন। প্রশ্ন যোগ করুন অথবা সংখ্যা কমান।');
                }
            } else {
                $posted = $_POST['question_ids'] ?? [];
                if (!is_array($posted)) $posted = [];
                $chosen = array_values(array_unique(array_filter(array_map('intval', $posted), fn($v) => $v > 0)));
                if ($categoryName !== null && $chosen) {
                    $marks = implode(',', array_fill(0, count($chosen), '?'));
                    $check = $pdo->prepare("SELECT id FROM questions WHERE category = ? AND id IN ($marks)");
                    $check->execute(array_merge([$categoryName], $chosen));
                    $chosen = $check->fetchAll(PDO::FETCH_COLUMN);
                }
                if (!$chosen) throw new RuntimeException('অন্তত একটি প্রশ্ন নির্বাচন করুন।');
            }

            $markEach = (float)($_POST['marks_per_question'] ?? 1);
            if ($markEach <= 0) throw new RuntimeException('প্রতি প্রশ্নের নম্বর শূন্যের বেশি হতে হবে।');
            $totalMarks = count($chosen) * $markEach;
            $passMarks = $passInput === '' ? null : (float)$passInput;
            if ($passMarks !== null && ($passMarks < 0 || $passMarks > $totalMarks)) throw new RuntimeException('পাস নম্বর মোট নম্বরের বেশি হতে পারবে না।');

            $pdo->beginTransaction();
            if ($id > 0) {
                $st = $pdo->prepare("UPDATE model_tests SET category_id=?, title=?, description=?, duration_minutes=?, total_marks=?, pass_marks=?, status=?, starts_at=?, ends_at=?, updated_at=NOW()" . ($hasRandomColumn ? ", randomize_questions=?" : "") . " WHERE id=?");
                $args = [$categoryId ?: null, $title, $description ?: null, $duration, $totalMarks, $passMarks, $status, $startsAt, $endsAt];
                if ($hasRandomColumn) $args[] = $random ? 1 : 0;
                $args[] = $id;
                $st->execute($args);
                $pdo->prepare('DELETE FROM model_test_questions WHERE test_id=?')->execute([$id]);
            } else {
                $cols = "category_id,title,description,duration_minutes,total_marks,pass_marks,status,starts_at,ends_at,created_at,updated_at";
                $vals = "?,?,?,?,?,?,?,?,?,NOW(),NOW()";
                $args = [$categoryId ?: null, $title, $description ?: null, $duration, $totalMarks, $passMarks, $status, $startsAt, $endsAt];
                if ($hasRandomColumn) { $cols .= ",randomize_questions"; $vals .= ",?"; $args[] = $random ? 1 : 0; }
                $st = $pdo->prepare("INSERT INTO model_tests ($cols) VALUES ($vals)");
                $st->execute($args);
                $id = (int)$pdo->lastInsertId();
            }

            $ins = $pdo->prepare("INSERT INTO model_test_questions (test_id,question_id,marks,question_order) VALUES (?,?,?,?)");
            foreach ($chosen as $i => $qid) $ins->execute([$id, (int)$qid, $markEach, $i + 1]);
            $pdo->commit();
            mt_redirect('model_tests.php?saved=1');
        }
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        $errors[] = $e->getMessage();
    }
}

if (isset($_GET['saved'])) $notice = 'মডেল টেস্ট সফলভাবে সংরক্ষণ করা হয়েছে।';
if (isset($_GET['deleted'])) $notice = 'মডেল টেস্ট মুছে ফেলা হয়েছে।';

$editId = (int)($_GET['edit'] ?? 0);
if ($editId > 0) {
    $st = $pdo->prepare('SELECT * FROM model_tests WHERE id=?');
    $st->execute([$editId]);
    $editing = $st->fetch(PDO::FETCH_ASSOC) ?: null;
    if ($editing) {
        $st = $pdo->prepare('SELECT question_id FROM model_test_questions WHERE test_id=? ORDER BY question_order');
        $st->execute([$editId]);
        $selectedQuestionIds = array_map('intval', $st->fetchAll(PDO::FETCH_COLUMN));
    }
}

try {
    $tests = $pdo->query("SELECT mt.*, c.name AS category_name, (SELECT COUNT(*) FROM model_test_questions q WHERE q.test_id=mt.id) AS question_count FROM model_tests mt LEFT JOIN categories c ON c.id=mt.category_id ORDER BY mt.id DESC LIMIT 200")->fetchAll(PDO::FETCH_ASSOC);
    $questions = $pdo->query("SELECT id,category,question,option_a,option_b,option_c,option_d,correct_answer FROM questions ORDER BY id DESC LIMIT 1000")->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    $errors[] = 'মডেল টেস্ট বা প্রশ্ন লোড করা যায়নি। SQL Migration এবং টেবিলের নাম যাচাই করুন।';
}

$stats = [
    'total' => count($tests),
    'published' => count(array_filter($tests, fn($t) => ($t['status'] ?? '') === 'published')),
    'draft' => count(array_filter($tests, fn($t) => ($t['status'] ?? '') === 'draft')),
    'questions' => count($questions),
];
$form = $editing ?: [];
$fmtDate = static function($v) { return $v ? date('Y-m-d\TH:i', strtotime((string)$v)) : ''; };
?>
<!doctype html>
<html lang="bn">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>মডেল টেস্ট | Fire Safety Job Prep</title>
<style>
:root{--maroon:#58101d;--maroon2:#3d0b14;--orange:#e87524;--bg:#f5f6f8;--ink:#252936;--muted:#747987;--line:#e8e9ee;--white:#fff;--green:#16845b}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font-family:system-ui,-apple-system,"Noto Sans Bengali",sans-serif;color:var(--ink)}
.layout{display:flex;min-height:100vh}.sidebar{width:260px;background:linear-gradient(180deg,var(--maroon),var(--maroon2));color:#fff;padding:22px 15px;position:fixed;inset:0 auto 0 0;overflow:auto}
.brand{display:flex;align-items:center;gap:12px;padding:4px 9px 24px;border-bottom:1px solid #ffffff26}.brand img{width:45px;height:45px;object-fit:contain;background:#fff;border-radius:12px;padding:4px}.brand strong{font-size:15px;line-height:1.35}.brand small{display:block;color:#e7cbd0;font-size:11px;margin-top:3px}
.nav-title{font-size:11px;color:#d8b7bd;padding:22px 11px 9px;letter-spacing:.5px}.nav a{display:flex;align-items:center;gap:11px;color:#f5e9eb;text-decoration:none;padding:12px 13px;margin:4px 0;border-radius:9px;font-size:14px}.nav a:hover,.nav a.active{background:var(--orange);color:#fff}.nav .ico{width:20px;text-align:center}
.main{margin-left:260px;width:calc(100% - 260px);padding:28px 30px 50px}.top{display:flex;justify-content:space-between;align-items:center;gap:15px;margin-bottom:24px}.top h1{font-size:25px;margin:0;color:var(--maroon)}.top p{margin:5px 0 0;color:var(--muted);font-size:13px}.btn{border:0;border-radius:8px;padding:10px 15px;background:var(--orange);color:#fff;font-weight:700;text-decoration:none;cursor:pointer;display:inline-block}.btn.secondary{background:#f1e5e7;color:var(--maroon)}.btn.danger{background:#b42335}.cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:15px;margin-bottom:22px}.stat,.panel{background:#fff;border:1px solid var(--line);border-radius:13px;box-shadow:0 3px 14px #1a223008}.stat{padding:18px}.stat span{font-size:13px;color:var(--muted)}.stat strong{display:block;font-size:27px;color:var(--maroon);margin-top:7px}.panel{padding:22px;margin-bottom:20px}.panel h2{font-size:18px;margin:0 0 17px;color:var(--maroon)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.field label{display:block;font-size:13px;font-weight:700;margin-bottom:6px}.field input,.field select,.field textarea{width:100%;border:1px solid #dfe1e7;border-radius:8px;padding:10px 11px;font:inherit;background:#fff}.field textarea{min-height:75px;resize:vertical}.field.full{grid-column:1/-1}.hint{font-size:12px;color:var(--muted);margin-top:5px}.radio-row{display:flex;gap:18px;flex-wrap:wrap;padding:9px 0}.question-box{border:1px solid var(--line);border-radius:9px;padding:12px;margin:9px 0;display:flex;gap:10px;align-items:flex-start}.question-box input{margin-top:4px}.question-box small{display:block;color:var(--muted);margin-top:4px}.toolbar{display:flex;gap:10px;flex-wrap:wrap;margin:12px 0}.toolbar input{flex:1;min-width:180px;border:1px solid var(--line);border-radius:8px;padding:10px}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse;min-width:700px}th,td{text-align:left;padding:12px;border-bottom:1px solid var(--line);font-size:13px}th{background:#faf7f8;color:var(--maroon)}.pill{padding:4px 9px;border-radius:20px;font-size:11px;background:#f2e6e8;color:var(--maroon)}.pill.live{background:#e4f5ed;color:#08764b}.alert{padding:12px 15px;border-radius:8px;margin:0 0 16px}.success{background:#e7f7ef;color:#116b47}.error{background:#fff0f0;color:#9d1c2c}.section{scroll-margin-top:18px}.mobile-head{display:none}
@media(max-width:900px){.sidebar{width:220px}.main{margin-left:220px;width:calc(100% - 220px);padding:22px 18px}.cards{grid-template-columns:repeat(2,1fr)}}
@media(max-width:650px){.layout{display:block}.sidebar{position:relative;width:100%;height:auto;padding:12px}.brand{padding-bottom:10px}.nav-title{padding-top:12px}.nav{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:3px}.nav a{font-size:12px;padding:9px}.main{margin:0;width:100%;padding:18px 12px 35px}.top{align-items:flex-start}.top h1{font-size:21px}.cards{gap:9px}.stat{padding:13px}.stat strong{font-size:23px}.panel{padding:15px}.grid{grid-template-columns:1fr}.field.full{grid-column:auto}}
</style>
</head>
<body>
<div class="layout">
<aside class="sidebar">
 <div class="brand"><img src="assets/fire-safety-bd-logo.png" alt="Logo" onerror="this.style.display='none'"><div><strong>Fire Safety Job Prep</strong><small>Admin Control Panel</small></div></div>
 <div class="nav-title">MODEL TEST MANAGEMENT</div>
 <nav class="nav">
  <a class="active" href="#dashboard"><span class="ico">▦</span>মডেল টেস্ট ড্যাশবোর্ড</a>
  <a href="#create"><span class="ico">＋</span>নতুন মডেল টেস্ট তৈরি</a>
  <a href="#all-tests"><span class="ico">☷</span>সকল মডেল টেস্ট</a>
  <a href="#scheduled"><span class="ico">◷</span>নির্ধারিত পরীক্ষা</a>
  <a href="#results"><span class="ico">✓</span>পরীক্ষার ফলাফল</a>
  <a href="#performance"><span class="ico">▤</span>পারফরম্যান্স বিশ্লেষণ</a>
 </nav>
</aside>
<main class="main">
<header class="top"><div><h1>মডেল টেস্ট ব্যবস্থাপনা</h1><p>পরীক্ষা তৈরি, প্রশ্ন নির্বাচন ও প্রকাশনা পরিচালনা করুন।</p></div><a class="btn" href="#create">＋ নতুন পরীক্ষা</a></header>
<?php if ($notice): ?><div class="alert success"><?=mt_h($notice)?></div><?php endif; ?>
<?php foreach ($errors as $err): ?><div class="alert error"><?=mt_h($err)?></div><?php endforeach; ?>

<section id="dashboard" class="section">
 <div class="cards">
  <div class="stat"><span>মোট মডেল টেস্ট</span><strong><?=$stats['total']?></strong></div>
  <div class="stat"><span>প্রকাশিত পরীক্ষা</span><strong><?=$stats['published']?></strong></div>
  <div class="stat"><span>খসড়া পরীক্ষা</span><strong><?=$stats['draft']?></strong></div>
  <div class="stat"><span>প্রশ্ন ব্যাংক</span><strong><?=$stats['questions']?></strong></div>
 </div>
</section>

<section id="create" class="panel section">
 <h2><?=$editing ? 'মডেল টেস্ট সম্পাদনা' : 'নতুন মডেল টেস্ট তৈরি'?></h2>
 <form method="post" action="model_tests.php<?= $editing ? '?edit='.(int)$editing['id'] : '' ?>">
  <input type="hidden" name="csrf_token" value="<?=mt_h($_SESSION['csrf_token'])?>">
  <input type="hidden" name="action" value="save_test">
  <input type="hidden" name="test_id" value="<?=(int)($form['id'] ?? 0)?>">
  <div class="grid">
   <div class="field"><label>পরীক্ষার নাম *</label><input name="title" required value="<?=mt_h($form['title'] ?? '')?>" placeholder="যেমন: Fire Safety Model Test 01"></div>
   <div class="field"><label>ক্যাটাগরি</label><select name="category_id"><option value="0">সব ক্যাটাগরি (মিশ্র প্রশ্ন)</option><?php foreach ($categories as $cat): ?><option value="<?=(int)$cat['id']?>" <?=((int)($form['category_id'] ?? 0)===(int)$cat['id'])?'selected':''?>><?=mt_h($cat['name'])?></option><?php endforeach; ?></select><div class="hint">ক্যাটাগরি পেজে সক্রিয় Test ক্যাটাগরি পরিবর্তন করলে এখানে স্বয়ংক্রিয়ভাবে আপডেট হবে।</div></div>
   <div class="field full"><label>পরীক্ষার বিবরণ</label><textarea name="description"><?=mt_h($form['description'] ?? '')?></textarea></div>
   <div class="field"><label>সময় (মিনিট) *</label><input type="number" name="duration_minutes" min="1" value="<?=mt_h($form['duration_minutes'] ?? 30)?>" required></div>
   <div class="field"><label>প্রশ্ন সংখ্যা (Random নির্বাচন হলে)</label><input type="number" name="question_count" min="1" max="500" value="20"></div>
   <div class="field"><label>প্রতি প্রশ্নের নম্বর</label><input type="number" name="marks_per_question" min="0.25" step="0.25" value="1" required></div>
   <div class="field"><label>পাস নম্বর (ঐচ্ছিক)</label><input type="number" name="pass_marks" min="0" step="0.25" value="<?=mt_h($form['pass_marks'] ?? '')?>"></div>
   <div class="field"><label>প্রশ্ন নির্বাচন পদ্ধতি</label><div class="radio-row"><label><input type="radio" name="selection_mode" value="random" checked> Random প্রশ্ন</label><label><input type="radio" name="selection_mode" value="manual"> নিজে নির্বাচন</label></div></div>
   <div class="field"><label>প্রশ্নের ক্রম</label><select name="randomize_questions"><option value="1">এলোমেলো (Random)</option><option value="0">নির্ধারিত ক্রম</option></select></div>
   <div class="field"><label>পরীক্ষার স্ট্যাটাস</label><select name="status"><option value="draft" <?=($form['status'] ?? 'draft')==='draft'?'selected':''?>>খসড়া</option><option value="published" <?=($form['status'] ?? '')==='published'?'selected':''?>>প্রকাশিত</option><option value="archived" <?=($form['status'] ?? '')==='archived'?'selected':''?>>আর্কাইভ</option></select></div>
   <div class="field"><label>শুরুর তারিখ ও সময়</label><input type="datetime-local" name="starts_at" value="<?=mt_h($fmtDate($form['starts_at'] ?? null))?>"></div>
   <div class="field"><label>শেষের তারিখ ও সময়</label><input type="datetime-local" name="ends_at" value="<?=mt_h($fmtDate($form['ends_at'] ?? null))?>"></div>
  </div>
  <div id="manualQuestions" style="display:none;margin-top:18px"><h3>প্রশ্ন নির্বাচন</h3><div class="toolbar"><input id="questionSearch" placeholder="প্রশ্ন বা ক্যাটাগরি দিয়ে খুঁজুন..."><span class="hint">সর্বোচ্চ ১০০০টি সাম্প্রতিক প্রশ্ন দেখানো হচ্ছে।</span></div>
  <?php foreach ($questions as $q): ?><label class="question-box" data-search="<?=mt_h(mb_strtolower($q['category'].' '.$q['question']))?>"><input type="checkbox" name="question_ids[]" value="<?=(int)$q['id']?>" <?=in_array((int)$q['id'],$selectedQuestionIds,true)?'checked':''?>><span><strong>#<?=(int)$q['id']?> · <?=mt_h($q['category'])?></strong><br><?=mt_h($q['question'])?><small>A. <?=mt_h($q['option_a'])?> · B. <?=mt_h($q['option_b'])?></small></span></label><?php endforeach; ?>
  </div>
  <div class="toolbar"><button class="btn" type="submit">সংরক্ষণ করুন</button><?php if ($editing): ?><a class="btn secondary" href="model_tests.php">সম্পাদনা বাতিল</a><?php endif; ?></div>
 </form>
</section>

<section id="all-tests" class="panel section">
 <h2>সকল মডেল টেস্ট</h2><div class="table-wrap"><table><thead><tr><th>পরীক্ষার নাম</th><th>ক্যাটাগরি</th><th>প্রশ্ন</th><th>সময়</th><th>নম্বর</th><th>স্ট্যাটাস</th><th>অ্যাকশন</th></tr></thead><tbody>
 <?php if (!$tests): ?><tr><td colspan="7">এখনো কোনো মডেল টেস্ট তৈরি করা হয়নি।</td></tr><?php endif; ?>
 <?php foreach ($tests as $t): ?><tr><td><strong><?=mt_h($t['title'])?></strong><br><small>#<?=(int)$t['id']?></small></td><td><?=mt_h($t['category_name'] ?? 'সব ক্যাটাগরি')?></td><td><?=(int)$t['question_count']?></td><td><?=(int)$t['duration_minutes']?> মিনিট</td><td><?=mt_h($t['total_marks'])?></td><td><span class="pill <?=($t['status']??'')==='published'?'live':''?>"><?=mt_h($t['status'])?></span></td><td><a class="btn secondary" href="?edit=<?=(int)$t['id']?>#create">সম্পাদনা</a><form method="post" style="display:inline" onsubmit="return confirm('এই মডেল টেস্টটি মুছে ফেলবেন?')"><input type="hidden" name="csrf_token" value="<?=mt_h($_SESSION['csrf_token'])?>"><input type="hidden" name="action" value="delete_test"><input type="hidden" name="test_id" value="<?=(int)$t['id']?>"><button class="btn danger" type="submit">মুছুন</button></form></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="scheduled" class="panel section"><h2>নির্ধারিত পরীক্ষা</h2><p>শুরুর বা শেষের সময় নির্ধারিত পরীক্ষাগুলো নিচে দেখানো হয়েছে।</p><div class="table-wrap"><table><thead><tr><th>পরীক্ষা</th><th>শুরু</th><th>শেষ</th><th>স্ট্যাটাস</th></tr></thead><tbody>
 <?php $scheduled = array_filter($tests, fn($t) => !empty($t['starts_at']) || !empty($t['ends_at'])); ?>
 <?php if (!$scheduled): ?><tr><td colspan="4">কোনো নির্ধারিত পরীক্ষা নেই।</td></tr><?php endif; ?>
 <?php foreach ($scheduled as $t): ?><tr><td><?=mt_h($t['title'])?></td><td><?=mt_h($t['starts_at'] ?? '—')?></td><td><?=mt_h($t['ends_at'] ?? '—')?></td><td><?=mt_h($t['status'])?></td></tr><?php endforeach; ?>
 </tbody></table></div></section>
<section id="results" class="panel section"><h2>পরীক্ষার ফলাফল</h2><p>ফলাফল দেখানোর জন্য পরীক্ষার্থীর attempt/submission টেবিল এবং student-side exam submission API সংযুক্ত করতে হবে। বর্তমান ডেটাবেজে সেই কাঠামো নিশ্চিত না হওয়ায় এখানে কোনো ফলাফল বানিয়ে দেখানো হচ্ছে না।</p></section>
<section id="performance" class="panel section"><h2>পারফরম্যান্স বিশ্লেষণ</h2><p>শিক্ষার্থীভিত্তিক স্কোর, সঠিক/ভুল উত্তর, সময় এবং ক্যাটাগরিভিত্তিক পারফরম্যান্সের তথ্য attempt/result ডেটা সংরক্ষণের পর দেখানো যাবে।</p></section>
<footer class="hint">Fire Safety Job Prep · Model Test Admin</footer>
</main></div>
<script>
const modeRadios=document.querySelectorAll('input[name="selection_mode"]');
const manual=document.getElementById('manualQuestions');
function updateMode(){const v=document.querySelector('input[name="selection_mode"]:checked')?.value;manual.style.display=v==='manual'?'block':'none';}
modeRadios.forEach(x=>x.addEventListener('change',updateMode));updateMode();
document.getElementById('questionSearch')?.addEventListener('input',function(){const q=this.value.toLocaleLowerCase();document.querySelectorAll('.question-box').forEach(el=>{el.style.display=el.dataset.search.includes(q)?'flex':'none';});});
</script>
</body></html>
