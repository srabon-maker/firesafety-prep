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
function mt_question_archive_column_exists(PDO $pdo): bool {
    $s = $pdo->query("SHOW COLUMNS FROM questions LIKE 'is_archived'");
    return (bool)$s->fetch(PDO::FETCH_ASSOC);
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

$hasQuestionArchiveColumn = mt_question_archive_column_exists($pdo);

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
                $conditions = [];
                if ($hasQuestionArchiveColumn) $conditions[] = "is_archived = 0";
                if ($categoryName !== null) {
                    $conditions[] = "category = ?";
                    $params[] = $categoryName;
                }
                if ($conditions) $sql .= " WHERE " . implode(" AND ", $conditions);
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
                if ($chosen) {
                    $marks = implode(',', array_fill(0, count($chosen), '?'));
                    $conditions = [];
                    $checkParams = [];
                    if ($categoryName !== null) { $conditions[] = "category = ?"; $checkParams[] = $categoryName; }
                    if ($hasQuestionArchiveColumn) {
                        if ($id > 0) {
                            $conditions[] = "(is_archived = 0 OR id IN (SELECT question_id FROM model_test_questions WHERE test_id = ?))";
                            $checkParams[] = $id;
                        } else {
                            $conditions[] = "is_archived = 0";
                        }
                    }
                    $conditions[] = "id IN ($marks)";
                    $check = $pdo->prepare("SELECT id FROM questions WHERE " . implode(" AND ", $conditions));
                    $check->execute(array_merge($checkParams, $chosen));
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
    $questionArchiveWhere = "";
    if ($hasQuestionArchiveColumn) {
        $questionArchiveWhere = $editId > 0
            ? " WHERE is_archived = 0 OR id IN (SELECT question_id FROM model_test_questions WHERE test_id = " . (int)$editId . ")"
            : " WHERE is_archived = 0";
    }
    $questions = $pdo->query("SELECT id,category,question,option_a,option_b,option_c,option_d,correct_answer" . ($hasQuestionArchiveColumn ? ",is_archived" : "") . " FROM questions" . $questionArchiveWhere . " ORDER BY id DESC LIMIT 1000")->fetchAll(PDO::FETCH_ASSOC);
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
:root{--maroon:#510d18;--maroon2:#450b15;--orange:#ffa400;--bg:#fff8f5;--ink:#30191b;--muted:#8b7777;--line:#f1ddd6;--white:#fff;--green:#16845b}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font-family:system-ui,-apple-system,"Noto Sans Bengali",sans-serif;color:var(--ink)}
.layout{display:flex;min-height:100vh}.sidebar{width:280px;flex:0 0 280px;background:linear-gradient(180deg,#450b15,#6a111f);color:#f9e9e7;padding:24px 16px;min-height:100vh;position:sticky;top:0;align-self:flex-start;height:100vh;overflow:auto}
.brand{display:flex;align-items:center;gap:13px;padding:4px 9px 26px;border:0}.brand img{width:65px;height:65px;border:2px solid #fff;border-radius:13px;background:#510d18;object-fit:contain;padding:0}.brand strong{font-size:20px;font-weight:800;color:#fff;line-height:1.25}.brand small{display:block;color:#e0bfc2;font-size:14px;margin-top:5px}
.nav-title{display:none}.nav{display:grid;gap:5px}.nav a{display:flex;align-items:center;gap:13px;color:#f4dfe0;text-decoration:none;padding:13px 15px;margin:0;border-radius:14px;font-size:16px}.nav a:hover{background:#ffffff12}.nav a.active{background:var(--orange);color:#29170b;font-weight:800}.nav .ico{width:22px;text-align:center;font-size:20px}
.main{margin:0;width:auto;flex:1;min-width:0;padding:32px}.top{display:flex;justify-content:space-between;align-items:center;gap:18px;margin-bottom:28px}.top h1{font-size:32px;font-weight:900;margin:0 0 8px;color:var(--maroon)}.top p{margin:0;color:var(--muted);font-size:16px}.btn{border:0;border-radius:8px;padding:10px 15px;background:var(--orange);color:#fff;font-weight:700;text-decoration:none;cursor:pointer;display:inline-block}.btn.secondary{background:#f1e5e7;color:var(--maroon)}.btn.danger{background:#b42335}.cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px;margin-bottom:24px}.stat,.panel{background:#fff;border:1px solid var(--line);border-radius:18px;box-shadow:0 5px 20px #450b1507}.stat{padding:22px 20px;min-height:118px}.stat span{font-size:14px;color:var(--muted)}.stat strong{display:block;font-size:30px;color:var(--maroon);margin-top:9px;font-weight:900}.panel{padding:25px;margin-bottom:22px;border-radius:18px}.panel h2{font-size:21px;margin:0 0 19px;color:var(--maroon);font-weight:900}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.field label{display:block;font-size:13px;font-weight:700;margin-bottom:6px}.field input,.field select,.field textarea{width:100%;border:1px solid #dfe1e7;border-radius:8px;padding:10px 11px;font:inherit;background:#fff}.field textarea{min-height:75px;resize:vertical}.field.full{grid-column:1/-1}.hint{font-size:12px;color:var(--muted);margin-top:5px}.radio-row{display:flex;gap:18px;flex-wrap:wrap;padding:9px 0}.question-box{border:1px solid var(--line);border-radius:9px;padding:12px;margin:9px 0;display:flex;gap:10px;align-items:flex-start}.question-box input{margin-top:4px}.question-box small{display:block;color:var(--muted);margin-top:4px}.toolbar{display:flex;gap:10px;flex-wrap:wrap;margin:12px 0}.toolbar input{flex:1;min-width:180px;border:1px solid var(--line);border-radius:8px;padding:10px}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse;min-width:700px}th,td{text-align:left;padding:12px;border-bottom:1px solid var(--line);font-size:13px}th{background:#faf7f8;color:var(--maroon)}.pill{padding:4px 9px;border-radius:20px;font-size:11px;background:#f2e6e8;color:var(--maroon)}.pill.live{background:#e4f5ed;color:#08764b}.alert{padding:12px 15px;border-radius:8px;margin:0 0 16px}.success{background:#e7f7ef;color:#116b47}.error{background:#fff0f0;color:#9d1c2c}.section{scroll-margin-top:18px}.mobile-head{display:none}
@media(max-width:1100px){.sidebar{width:250px;flex-basis:250px}.main{padding:26px 22px}.cards{grid-template-columns:repeat(2,minmax(0,1fr))}}\n@media(max-width:700px){.layout{display:block}.sidebar{position:relative;width:100%;height:auto;min-height:0;padding:14px 12px}.brand{padding:4px 7px 14px}.brand img{width:48px;height:48px}.brand strong{font-size:17px}.brand small{font-size:12px}.nav{grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.nav a{font-size:13px;padding:10px}.nav .ico{font-size:17px}.main{padding:20px 14px 35px}.top{align-items:flex-start}.top h1{font-size:24px}.top .btn{white-space:nowrap}.cards{gap:10px}.stat{padding:15px;min-height:95px}.stat strong{font-size:24px}.panel{padding:17px}.grid{grid-template-columns:1fr}.field.full{grid-column:auto}}
</style>
</head>
<body>
<div class="layout">
<aside class="sidebar">
 <div class="brand"><a href="admin/fire_safety_job_prep_dashboard.php" aria-label="ড্যাশবোর্ডে ফিরুন"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo"></a><div><a href="admin/fire_safety_job_prep_dashboard.php"><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></a></div></div>
 <nav class="nav">
  <a href="admin/fire_safety_job_prep_dashboard.php"><span class="ico">▦</span>ড্যাশবোর্ড</a>
  <a href="questions.php"><span class="ico">ⓘ</span>প্রশ্ন ব্যাংক</a>
  <a class="active" href="model_tests.php" aria-current="page"><span class="ico">☑</span>মডেল টেস্ট</a>
  <a href="notes.php"><span class="ico">◫</span>নোট</a>
  <a href="job_circulars.php"><span class="ico">▣</span>চাকরির সার্কুলার</a>
  <a href="admin/fire_safety_job_prep_dashboard.php?section=marketplace"><span class="ico">🛒</span>মার্কেটপ্লেস</a>
  <a href="category_management.php"><span class="ico">⊞</span>ক্যাটাগরি</a>
  <a href="admin/fire_safety_job_prep_dashboard.php?section=community"><span class="ico">▱</span>কমিউনিটি</a>
  <a href="logout.php" class="logout"><span class="ico">↪</span>লগ আউট</a>
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
  <?php foreach ($questions as $q): ?><label class="question-box" data-search="<?=mt_h(mb_strtolower($q['category'].' '.$q['question']))?>"><input type="checkbox" name="question_ids[]" value="<?=(int)$q['id']?>" <?=in_array((int)$q['id'],$selectedQuestionIds,true)?'checked':''?>><span><strong>#<?=(int)$q['id']?> · <?=mt_h($q['category'])?></strong><br><?=mt_h($q['question'])?><small>A. <?=mt_h($q['option_a'])?> · B. <?=mt_h($q['option_b'])?></small><?php if(!empty($q['is_archived'])): ?><small style="color:#a15b13;font-weight:700">Archived · এই পরীক্ষায় আগে থেকেই যুক্ত</small><?php endif; ?></span></label><?php endforeach; ?>
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
