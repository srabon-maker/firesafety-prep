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
$editingMarksPerQuestion = 1.0;
$editingSelectionMode = 'manual';

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
$hasNegativeMarkingColumn = false;
$hasInstructionsColumn = false;
$hasPolicyColumns = false;
try {
    $hasRandomColumn = (bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'randomize_questions'")->fetch(PDO::FETCH_ASSOC);
    $hasNegativeMarkingColumn = (bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'negative_marks_per_question'")->fetch(PDO::FETCH_ASSOC);
    $hasInstructionsColumn = (bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'exam_instructions'")->fetch(PDO::FETCH_ASSOC);
    $hasPolicyColumns = (bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'max_attempts'")->fetch(PDO::FETCH_ASSOC)
        && (bool)$pdo->query("SHOW COLUMNS FROM model_tests LIKE 'results_released'")->fetch(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    $errors[] = 'model_tests টেবিল পাওয়া যায়নি। আগে প্রয়োজনীয় SQL Migration চালান।';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (!hash_equals($_SESSION['csrf_token'], (string)($_POST['csrf_token'] ?? ''))) {
            throw new RuntimeException('নিরাপত্তা যাচাই ব্যর্থ হয়েছে। পেজ রিফ্রেশ করে আবার চেষ্টা করুন।');
        }
        $action = (string)($_POST['action'] ?? '');
        if ($action === 'set_results_release') {
            if (!$hasPolicyColumns || !mt_table_exists($pdo, 'model_test_attempts')) throw new RuntimeException('Policy ও Attempt Migration আগে চালান।');
            $id = (int)($_POST['test_id'] ?? 0);
            $released = (int)($_POST['results_released'] ?? 0);
            if ($id < 1 || !in_array($released, [0, 1], true)) throw new RuntimeException('ফলাফল প্রকাশের অনুরোধ সঠিক নয়।');
            $st = $pdo->prepare('UPDATE model_tests SET results_released=? WHERE id=?');
            $st->execute([$released, $id]);
            mt_redirect('model_tests.php?release_updated=1#results');
        }
        if ($action === 'delete_test') {
            $id = (int)($_POST['test_id'] ?? 0);
            if ($id < 1) throw new RuntimeException('ভুল টেস্ট আইডি।');
            if (mt_table_exists($pdo, 'model_test_attempts')) {
                $attemptCheck = $pdo->prepare('SELECT COUNT(*) FROM model_test_attempts WHERE test_id = ?');
                $attemptCheck->execute([$id]);
                if ((int)$attemptCheck->fetchColumn() > 0) {
                    throw new RuntimeException('এই পরীক্ষায় শিক্ষার্থীর Attempt/Result রয়েছে। ডেটা সংরক্ষণের জন্য এটি Delete করা যাবে না; Archive করুন।');
                }
            }
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
            $examInstructions = trim((string)($_POST['exam_instructions'] ?? ''));
            $negativeMarks = (float)($_POST['negative_marks_per_question'] ?? 0);
            $categoryId = (int)($_POST['category_id'] ?? 0);
            $duration = (int)($_POST['duration_minutes'] ?? 30);
            $questionCount = (int)($_POST['question_count'] ?? 20);
            if ($duration < 1 || $duration > 1440) throw new RuntimeException('পরীক্ষার সময় ১ থেকে ১৪৪০ মিনিটের মধ্যে হতে হবে।');
            if ($questionCount < 1 || $questionCount > 500) throw new RuntimeException('Random প্রশ্নের সংখ্যা ১ থেকে ৫০০-এর মধ্যে হতে হবে।');
            $passInput = trim((string)($_POST['pass_marks'] ?? ''));
            $status = (string)($_POST['status'] ?? 'draft');
            $random = (int)($_POST['randomize_questions'] ?? 0) === 1;
            $maxAttempts = (int)($_POST['max_attempts'] ?? 0);
            $resultsReleased = (int)($_POST['results_released'] ?? 1);
            if ($maxAttempts < 0 || $maxAttempts > 1000) throw new RuntimeException('সর্বোচ্চ Attempt সংখ্যা ০ থেকে ১০০০-এর মধ্যে হতে হবে।');
            if (!in_array($resultsReleased, [0, 1], true)) throw new RuntimeException('Result Release সেটিং সঠিক নয়।');
            if (!$hasPolicyColumns) throw new RuntimeException('আগে 20261119_model_test_policies.sql Migration চালান।');
            $selectionMode = (string)($_POST['selection_mode'] ?? 'manual');
            $startsRaw = trim((string)($_POST['starts_at'] ?? ''));
            $endsRaw = trim((string)($_POST['ends_at'] ?? ''));

            if ($title === '') throw new RuntimeException('পরীক্ষার নাম লিখুন।');
            if (!in_array($status, ['draft', 'published', 'archived'], true)) throw new RuntimeException('স্ট্যাটাস সঠিক নয়।');
            if (!in_array($selectionMode, ['manual', 'random'], true)) throw new RuntimeException('প্রশ্ন নির্বাচনের ধরন সঠিক নয়।');
            if (!is_finite($negativeMarks) || $negativeMarks < 0 || $negativeMarks > 1000) throw new RuntimeException('প্রতি ভুল উত্তরের নেগেটিভ মার্ক ০ থেকে ১০০০-এর মধ্যে হতে হবে।');
            if (mb_strlen($examInstructions) > 5000) throw new RuntimeException('পরীক্ষার নির্দেশনা সর্বোচ্চ ৫০০০ অক্ষরের মধ্যে হতে হবে।');
            $categoryName = null;
            if ($categoryId > 0) {
                $cs = $pdo->prepare("SELECT name FROM categories WHERE id = ? AND category_type = 'test' AND is_active = 1");
                $cs->execute([$categoryId]);
                $categoryName = $cs->fetchColumn();
                if (!$categoryName) throw new RuntimeException('নির্বাচিত ক্যাটাগরি সক্রিয় নয়।');
            }

            $parseLocalDate = static function (string $value, string $label): ?string {
                if ($value === '') return null;
                $date = DateTime::createFromFormat('!Y-m-d\\TH:i', $value);
                $dateErrors = DateTime::getLastErrors();
                if (!$date || ($dateErrors !== false && ($dateErrors['warning_count'] > 0 || $dateErrors['error_count'] > 0)) || $date->format('Y-m-d\\TH:i') !== $value) {
                    throw new RuntimeException($label . ' সঠিক নয়।');
                }
                return $date->format('Y-m-d H:i:s');
            };
            $startsAt = $parseLocalDate($startsRaw, 'শুরুর তারিখ ও সময়');
            $endsAt = $parseLocalDate($endsRaw, 'শেষের তারিখ ও সময়');
            if ($startsAt && $endsAt && strtotime($endsAt) <= strtotime($startsAt)) throw new RuntimeException('শেষের সময় শুরুর সময়ের পরে হতে হবে।');
            if ($status === 'published' && $endsAt !== null && strtotime($endsAt) <= time()) throw new RuntimeException('ইতোমধ্যে শেষ হয়ে যাওয়া পরীক্ষা প্রকাশ করা যাবে না।');

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
            if (!is_finite($markEach) || $markEach <= 0 || $markEach > 1000) throw new RuntimeException('প্রতি প্রশ্নের নম্বর ০-এর বেশি এবং ১০০০-এর মধ্যে হতে হবে।');
            $totalMarks = count($chosen) * $markEach;
            $passMarks = $passInput === '' ? null : (float)$passInput;
            if ($passMarks !== null && ($passMarks < 0 || $passMarks > $totalMarks)) throw new RuntimeException('পাস নম্বর মোট নম্বরের বেশি হতে পারবে না।');

            $pdo->beginTransaction();
            if ($id > 0) {
                $lock = $pdo->prepare('SELECT id FROM model_tests WHERE id = ? FOR UPDATE');
                $lock->execute([$id]);
                if (!$lock->fetchColumn()) throw new RuntimeException('সম্পাদনার পরীক্ষাটি আর পাওয়া যাচ্ছে না। তালিকা রিফ্রেশ করে আবার চেষ্টা করুন।');
                $optionalUpdates = ($hasRandomColumn ? ", randomize_questions=?" : "") . ($hasNegativeMarkingColumn ? ", negative_marks_per_question=?" : "") . ($hasInstructionsColumn ? ", exam_instructions=?" : "") . ($hasPolicyColumns ? ", max_attempts=?, results_released=?" : "");
                $st = $pdo->prepare("UPDATE model_tests SET category_id=?, title=?, description=?, duration_minutes=?, total_marks=?, pass_marks=?, status=?, starts_at=?, ends_at=?, updated_at=NOW()" . $optionalUpdates . " WHERE id=?");
                $args = [$categoryId ?: null, $title, $description ?: null, $duration, $totalMarks, $passMarks, $status, $startsAt, $endsAt];
                if ($hasRandomColumn) $args[] = $random ? 1 : 0;
                if ($hasNegativeMarkingColumn) $args[] = $negativeMarks;
                if ($hasInstructionsColumn) $args[] = $examInstructions ?: null;
                if ($hasPolicyColumns) { $args[] = $maxAttempts; $args[] = $resultsReleased; }
                $args[] = $id;
                $st->execute($args);
                $pdo->prepare('DELETE FROM model_test_questions WHERE test_id=?')->execute([$id]);
            } else {
                $cols = "category_id,title,description,duration_minutes,total_marks,pass_marks,status,starts_at,ends_at,created_at,updated_at";
                $vals = "?,?,?,?,?,?,?,?,?,NOW(),NOW()";
                $args = [$categoryId ?: null, $title, $description ?: null, $duration, $totalMarks, $passMarks, $status, $startsAt, $endsAt];
                if ($hasRandomColumn) { $cols .= ",randomize_questions"; $vals .= ",?"; $args[] = $random ? 1 : 0; }
                if ($hasNegativeMarkingColumn) { $cols .= ",negative_marks_per_question"; $vals .= ",?"; $args[] = $negativeMarks; }
                if ($hasInstructionsColumn) { $cols .= ",exam_instructions"; $vals .= ",?"; $args[] = $examInstructions ?: null; }
                if ($hasPolicyColumns) { $cols .= ",max_attempts,results_released"; $vals .= ",?,?"; $args[] = $maxAttempts; $args[] = $resultsReleased; }
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
if (isset($_GET['release_updated'])) $notice = 'ফলাফল প্রকাশের সেটিং আপডেট হয়েছে।';

$viewQuestionsTestId = (int)($_GET['view_questions'] ?? 0);
$viewQuestionsTest = null;
$viewQuestions = [];
if ($viewQuestionsTestId > 0) {
    $vs = $pdo->prepare("SELECT id,title FROM model_tests WHERE id=? LIMIT 1");
    $vs->execute([$viewQuestionsTestId]);
    $viewQuestionsTest = $vs->fetch(PDO::FETCH_ASSOC) ?: null;
    if ($viewQuestionsTest) {
        $vq = $pdo->prepare("SELECT mtq.question_order,mtq.marks,q.id,q.category,q.question,q.option_a,q.option_b,q.option_c,q.option_d,q.correct_answer FROM model_test_questions mtq JOIN questions q ON q.id=mtq.question_id WHERE mtq.test_id=? ORDER BY mtq.question_order");
        $vq->execute([$viewQuestionsTestId]);
        $viewQuestions = $vq->fetchAll(PDO::FETCH_ASSOC);
    }
}
$editId = (int)($_GET['edit'] ?? 0);
if ($editId > 0) {
    $st = $pdo->prepare('SELECT * FROM model_tests WHERE id=?');
    $st->execute([$editId]);
    $editing = $st->fetch(PDO::FETCH_ASSOC) ?: null;
    if ($editing) {
        $st = $pdo->prepare('SELECT question_id, marks FROM model_test_questions WHERE test_id=? ORDER BY question_order');
        $st->execute([$editId]);
        $existingQuestionRows = $st->fetchAll(PDO::FETCH_ASSOC);
        $selectedQuestionIds = array_map(static fn($row) => (int)$row['question_id'], $existingQuestionRows);
        if ($existingQuestionRows) {
            $existingMarks = array_values(array_unique(array_map(static fn($row) => (string)$row['marks'], $existingQuestionRows)));
            if (count($existingMarks) === 1 && is_numeric($existingMarks[0]) && (float)$existingMarks[0] > 0) $editingMarksPerQuestion = (float)$existingMarks[0];
        }
        $editingSelectionMode = 'manual';
    }
}

try {
    $statsRow = $pdo->query("SELECT COUNT(*) AS total, COALESCE(SUM(status='published'),0) AS published, COALESCE(SUM(status='draft'),0) AS draft FROM model_tests")->fetch(PDO::FETCH_ASSOC) ?: [];
    $questionCountSql = $hasQuestionArchiveColumn ? "SELECT COUNT(*) FROM questions WHERE is_archived = 0" : "SELECT COUNT(*) FROM questions";
    $statsQuestionCount = (int)$pdo->query($questionCountSql)->fetchColumn();
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
    'total' => (int)($statsRow['total'] ?? 0),
    'published' => (int)($statsRow['published'] ?? 0),
    'draft' => (int)($statsRow['draft'] ?? 0),
    'questions' => $statsQuestionCount ?? 0,
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
.main{margin:0;width:auto;flex:1;min-width:0;padding:32px}.top{display:flex;justify-content:space-between;align-items:center;gap:18px;margin-bottom:28px}.top h1{font-size:32px;font-weight:900;margin:0 0 8px;color:var(--maroon)}.top p{margin:0;color:var(--muted);font-size:16px}.btn{border:0;border-radius:8px;padding:10px 15px;background:var(--orange);color:#fff;font-weight:700;text-decoration:none;cursor:pointer;display:inline-block}.btn.secondary{background:#f1e5e7;color:var(--maroon)}.btn.danger{background:#b42335}.cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px;margin-bottom:24px}.stat,.panel{background:#fff;border:1px solid var(--line);border-radius:18px;box-shadow:0 5px 20px #450b1507}.stat{padding:22px 20px;min-height:118px}.stat span{font-size:14px;color:var(--muted)}.stat strong{display:block;font-size:30px;color:var(--maroon);margin-top:9px;font-weight:900}.panel{padding:25px;margin-bottom:22px;border-radius:18px}.panel h2{font-size:21px;margin:0 0 19px;color:var(--maroon);font-weight:900}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.field label{display:block;font-size:13px;font-weight:700;margin-bottom:6px}.field input,.field select,.field textarea{width:100%;border:1px solid #dfe1e7;border-radius:8px;padding:10px 11px;font:inherit;background:#fff}.field textarea{min-height:75px;resize:vertical}.field.full{grid-column:1/-1}.hint{font-size:12px;color:var(--muted);margin-top:5px}.radio-row{display:flex;gap:18px;flex-wrap:wrap;padding:9px 0}.question-box{border:1px solid var(--line);border-radius:9px;padding:12px;margin:9px 0;display:flex;gap:10px;align-items:flex-start}.question-box input{margin-top:4px}.question-box small{display:block;color:var(--muted);margin-top:4px}.question-box{position:relative;cursor:pointer;transition:border-color .15s,background .15s,box-shadow .15s}.question-box:hover{border-color:var(--maroon);background:#fffaf9}.question-box.is-selected{border:2px solid var(--maroon);background:#fff5f3;box-shadow:0 0 0 2px rgba(128,28,45,.08)}.question-box:has(input[type="checkbox"]:checked){border:2px solid var(--maroon);background:#fff5f3;box-shadow:0 0 0 2px rgba(128,28,45,.08)}.question-select-label{display:flex;gap:10px;align-items:flex-start;flex:1;min-width:0;cursor:pointer}.question-box input[type="checkbox"]{width:23px;height:23px;min-width:23px;accent-color:var(--maroon);cursor:pointer;margin:2px 5px 0 1px}.question-content{flex:1;min-width:0;cursor:pointer;line-height:1.55}.question-actions{display:flex;gap:5px;flex-wrap:wrap;margin-left:auto}.question-actions button{border:1px solid var(--line);background:#fff;color:var(--maroon);border-radius:7px;padding:5px 8px;cursor:pointer}.question-actions button:disabled{opacity:.35;cursor:not-allowed}.question-toolbar{display:grid;grid-template-columns:minmax(180px,1fr) minmax(170px,220px) auto;gap:9px;align-items:center}.question-toolbar input,.question-toolbar select{min-width:0;border:1px solid var(--line);border-radius:8px;padding:10px;background:#fff;font:inherit}.selection-summary{font-weight:800;color:var(--maroon);white-space:nowrap}.question-empty{padding:16px;border:1px dashed var(--line);border-radius:9px;color:var(--muted);display:none}.preview-modal{position:fixed;inset:0;background:#1b0b0dcc;z-index:1000;display:none;align-items:center;justify-content:center;padding:18px}.preview-card{width:min(680px,100%);max-height:85vh;overflow:auto;background:#fff;border-radius:16px;padding:22px;box-shadow:0 20px 70px #0005}.preview-card h3{margin:0 0 12px;color:var(--maroon)}.preview-options{display:grid;gap:8px;margin-top:12px}.preview-option{padding:10px;border:1px solid var(--line);border-radius:8px}.preview-close{float:right}.toolbar{display:flex;gap:10px;flex-wrap:wrap;margin:12px 0}.toolbar input{flex:1;min-width:180px;border:1px solid var(--line);border-radius:8px;padding:10px}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse;min-width:700px}th,td{text-align:left;padding:12px;border-bottom:1px solid var(--line);font-size:13px}th{background:#faf7f8;color:var(--maroon)}.pill{padding:4px 9px;border-radius:20px;font-size:11px;background:#f2e6e8;color:var(--maroon)}.pill.live{background:#e4f5ed;color:#08764b}.alert{padding:12px 15px;border-radius:8px;margin:0 0 16px}.success{background:#e7f7ef;color:#116b47}.error{background:#fff0f0;color:#9d1c2c}.section{scroll-margin-top:18px}.mobile-head{display:none}
@media(max-width:1100px){.sidebar{width:250px;flex-basis:250px}.main{padding:26px 22px}.cards{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:700px){.layout{display:block}.sidebar{position:relative;width:100%;height:auto;min-height:0;padding:14px 12px}.brand{padding:4px 7px 14px}.brand img{width:48px;height:48px}.brand strong{font-size:17px}.brand small{font-size:12px}.nav{grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.nav a{font-size:13px;padding:10px}.nav .ico{font-size:17px}.main{padding:20px 14px 35px}.top{align-items:flex-start}.top h1{font-size:24px}.top .btn{white-space:nowrap}.cards{gap:10px}.stat{padding:15px;min-height:95px}.stat strong{font-size:24px}.panel{padding:17px}.grid{grid-template-columns:1fr}.field.full{grid-column:auto}}
</style>
</head>
<body>
<div class="layout">
<aside class="sidebar">
 <div class="brand"><a href="index.php" aria-label="ড্যাশবোর্ডে ফিরুন"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo"></a><div><a href="index.php"><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></a></div></div>
 <nav class="nav">
  <a href="index.php"><span class="ico">▦</span>ড্যাশবোর্ড</a>
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
   <div class="field full"><label>পরীক্ষার নির্দেশনা (ঐচ্ছিক)</label><textarea name="exam_instructions" maxlength="5000" placeholder="পরীক্ষা শুরুর আগে শিক্ষার্থীদের জন্য নির্দেশনা লিখুন..."><?=mt_h($form['exam_instructions'] ?? '')?></textarea><div class="hint">সর্বোচ্চ ৫০০০ অক্ষর। Student-side exam API সংযুক্ত না হওয়া পর্যন্ত নির্দেশনাটি শুধু Admin-এ সংরক্ষিত থাকবে।</div></div>
   <div class="field"><label>সময় (মিনিট) *</label><input type="number" name="duration_minutes" min="1" value="<?=mt_h($form['duration_minutes'] ?? 30)?>" required></div>
   <div class="field"><label>প্রশ্ন সংখ্যা (Random নির্বাচন হলে)</label><input type="number" name="question_count" min="1" max="500" value="<?= $editing ? max(1, count($selectedQuestionIds)) : 20 ?>" <?= $editing ? 'readonly' : '' ?>></div>
   <div class="field"><label>প্রতি প্রশ্নের নম্বর</label><input type="number" name="marks_per_question" min="0.25" max="1000" step="0.25" value="<?=mt_h($editingMarksPerQuestion)?>" required></div>
   <div class="field"><label>প্রতি ভুল উত্তরের নেগেটিভ মার্ক</label><input type="number" name="negative_marks_per_question" min="0" max="1000" step="0.01" value="<?=mt_h($form['negative_marks_per_question'] ?? 0)?>" required><div class="hint">০ দিলে নেগেটিভ মার্কিং বন্ধ থাকবে।</div></div>
   <div class="field"><label>পাস নম্বর (ঐচ্ছিক)</label><input type="number" name="pass_marks" min="0" step="0.25" value="<?=mt_h($form['pass_marks'] ?? '')?>"></div>
   <div class="field"><label>সর্বোচ্চ Attempt (০ = সীমাহীন)</label><input type="number" name="max_attempts" min="0" max="1000" step="1" value="<?=mt_h($form['max_attempts'] ?? 0)?>"><div class="hint">একজন শিক্ষার্থী সর্বোচ্চ কতবার পরীক্ষা দিতে পারবে।</div></div>
   <div class="field"><label>ফলাফল প্রকাশ</label><select name="results_released"><option value="1" <?=((int)($form['results_released'] ?? 1)===1)?'selected':''?>>Submit-এর পর সঙ্গে সঙ্গে</option><option value="0" <?=((int)($form['results_released'] ?? 1)===0)?'selected':''?>>Admin প্রকাশ না করা পর্যন্ত গোপন</option></select></div>
   <div class="field"><label>প্রশ্ন নির্বাচন পদ্ধতি</label><div class="radio-row"><label><input type="radio" name="selection_mode" value="random" <?=$editingSelectionMode==='random'?'checked':''?> <?= $editing ? 'disabled' : '' ?>> Random প্রশ্ন</label><label><input type="radio" name="selection_mode" value="manual" <?=$editingSelectionMode==='manual'?'checked':''?>> নিজে নির্বাচন</label>
   <?php if ($editing): ?><input type="hidden" name="selection_mode" value="manual"><div class="hint">আগের নির্বাচিত প্রশ্নগুলো অক্ষত রাখতে সম্পাদনার সময় Manual Mode ব্যবহার হচ্ছে।</div><?php endif; ?></div></div>
   <div class="field"><label>প্রশ্নের ক্রম</label><select name="randomize_questions"><option value="1" <?=((int)($form['randomize_questions'] ?? 0)===1)?'selected':''?>>এলোমেলো (Random)</option><option value="0" <?=((int)($form['randomize_questions'] ?? 0)===0)?'selected':''?>>নির্ধারিত ক্রম</option></select></div>
   <div class="field"><label>পরীক্ষার স্ট্যাটাস</label><select name="status"><option value="draft" <?=($form['status'] ?? 'draft')==='draft'?'selected':''?>>খসড়া</option><option value="published" <?=($form['status'] ?? '')==='published'?'selected':''?>>প্রকাশিত</option><option value="archived" <?=($form['status'] ?? '')==='archived'?'selected':''?>>আর্কাইভ</option></select></div>
   <div class="field"><label>শুরুর তারিখ ও সময়</label><input type="datetime-local" name="starts_at" value="<?=mt_h($fmtDate($form['starts_at'] ?? null))?>"></div>
   <div class="field"><label>শেষের তারিখ ও সময়</label><input type="datetime-local" name="ends_at" value="<?=mt_h($fmtDate($form['ends_at'] ?? null))?>"></div>
  </div>
  <div id="manualQuestions" style="display:<?= $editingSelectionMode === 'manual' ? 'block' : 'none' ?>;margin-top:18px">
   <h3>প্রশ্ন নির্বাচন</h3>
   <div class="question-toolbar">
    <input id="questionSearch" type="search" placeholder="প্রশ্ন বা ক্যাটাগরি দিয়ে খুঁজুন..." aria-label="প্রশ্ন খুঁজুন">
    <select id="questionCategoryFilter" aria-label="ক্যাটাগরি ফিল্টার"><option value="">সব ক্যাটাগরি</option><?php $questionCategories = array_values(array_unique(array_filter(array_map(static fn($q) => (string)$q['category'], $questions)))); sort($questionCategories, SORT_NATURAL | SORT_FLAG_CASE); foreach ($questionCategories as $qc): ?><option value="<?=mt_h(mb_strtolower($qc))?>"><?=mt_h($qc)?></option><?php endforeach; ?></select>
    <span class="selection-summary" id="selectedQuestionCount" aria-live="polite">নির্বাচিত: <?=count($selectedQuestionIds)?></span>
   </div>
   <div class="toolbar"><button class="btn secondary" type="button" id="selectVisibleQuestions">সব প্রশ্ন নির্বাচন</button><button class="btn secondary" type="button" id="clearVisibleQuestions">দেখানো সব বাতিল</button><span class="hint">সর্বোচ্চ ১০০০টি সাম্প্রতিক প্রশ্ন থেকে নির্বাচন করা যাবে।</span></div>
   <div id="questionList">
   <?php foreach ($questions as $q): ?><div class="question-box" data-search="<?=mt_h(mb_strtolower($q['category'].' '.$q['question']))?>" data-category="<?=mt_h(mb_strtolower($q['category']))?>" data-question="<?=mt_h($q['question'])?>" data-option-a="<?=mt_h($q['option_a'])?>" data-option-b="<?=mt_h($q['option_b'])?>" data-option-c="<?=mt_h($q['option_c'])?>" data-option-d="<?=mt_h($q['option_d'])?>">
    <label class="question-select-label"><input type="checkbox" name="question_ids[]" value="<?=(int)$q['id']?>" <?=in_array((int)$q['id'],$selectedQuestionIds,true)?'checked':''?> aria-label="প্রশ্ন #<?=(int)$q['id']?> নির্বাচন">
    <span class="question-content"><strong>#<?=(int)$q['id']?> · <?=mt_h($q['category'])?></strong><br><?=mt_h($q['question'])?><small>A. <?=mt_h($q['option_a'])?> · B. <?=mt_h($q['option_b'])?></small><?php if(!empty($q['is_archived'])): ?><small style="color:#a15b13;font-weight:700">Archived · এই পরীক্ষায় আগে থেকেই যুক্ত</small><?php endif; ?></span></label>
    <span class="question-actions"><button type="button" class="preview-question" aria-label="প্রশ্নের প্রিভিউ" data-id="<?=(int)$q['id']?>">প্রিভিউ</button><button type="button" class="move-question-up" aria-label="উপরে সরান">↑</button><button type="button" class="move-question-down" aria-label="নিচে সরান">↓</button></span>
   </div><?php endforeach; ?>
   </div><div id="questionEmpty" class="question-empty">এই ফিল্টারে কোনো প্রশ্ন পাওয়া যায়নি।</div>
  </div>
  <div class="toolbar"><button class="btn" type="submit">সংরক্ষণ করুন</button><?php if ($editing): ?><a class="btn secondary" href="model_tests.php">সম্পাদনা বাতিল</a><?php endif; ?></div>
 </form>
</section>

<section id="all-tests" class="panel section">
 <h2>সকল মডেল টেস্ট</h2>
 <?php if ($viewQuestionsTest): ?>
 <div class="panel" style="margin:14px 0;padding:16px">
  <h3>নির্বাচিত প্রশ্ন: <?=mt_h($viewQuestionsTest['title'])?></h3>
  <p class="hint">মোট <?=count($viewQuestions)?>টি প্রশ্ন সংরক্ষিত আছে। Random নির্বাচন Save করার সময় যে প্রশ্নগুলো নেওয়া হয়েছিল, সেগুলোই এখানে দেখানো হচ্ছে।</p>
  <?php foreach ($viewQuestions as $vq): ?><article class="question-box" style="display:block">
   <strong>প্রশ্ন <?= (int)$vq['question_order'] ?> · #<?= (int)$vq['id'] ?> · <?=mt_h($vq['category'])?></strong>
   <p><?=mt_h($vq['question'])?></p>
   <p>A. <?=mt_h($vq['option_a'])?><br>B. <?=mt_h($vq['option_b'])?><br>C. <?=mt_h($vq['option_c'])?><br>D. <?=mt_h($vq['option_d'])?></p>
   <p><strong>সঠিক উত্তর: <?=mt_h($vq['correct_answer'])?></strong> · নম্বর: <?=mt_h($vq['marks'])?></p>
  </article><?php endforeach; ?>
  <a class="btn secondary" href="model_tests.php#all-tests">বন্ধ করুন</a>
 </div>
 <?php elseif ($viewQuestionsTestId > 0): ?><p class="hint">এই পরীক্ষার তথ্য পাওয়া যায়নি।</p><?php endif; ?><div class="table-wrap"><table><thead><tr><th>পরীক্ষার নাম</th><th>ক্যাটাগরি</th><th>প্রশ্ন</th><th>সময়</th><th>নম্বর</th><th>Attempt Limit</th><th>ফলাফল</th><th>স্ট্যাটাস</th><th>অ্যাকশন</th></tr></thead><tbody>
 <?php if (!$tests): ?><tr><td colspan="9">এখনো কোনো মডেল টেস্ট তৈরি করা হয়নি।</td></tr><?php endif; ?>
 <?php foreach ($tests as $t): ?><tr><td><strong><?=mt_h($t['title'])?></strong><br><small>#<?=(int)$t['id']?></small></td><td><?=mt_h($t['category_name'] ?? 'সব ক্যাটাগরি')?></td><td><?=(int)$t['question_count']?></td><td><?=(int)$t['duration_minutes']?> মিনিট</td><td><?=mt_h($t['total_marks'])?></td><td><?=((int)($t['max_attempts'] ?? 0)===0)?'সীমাহীন':(int)$t['max_attempts']?></td><td><?=((int)($t['results_released'] ?? 1)===1)?'প্রকাশিত':'গোপন'?><form method="post" style="display:inline;margin-left:6px"><input type="hidden" name="csrf_token" value="<?=mt_h($_SESSION['csrf_token'])?>"><input type="hidden" name="action" value="set_results_release"><input type="hidden" name="test_id" value="<?=(int)$t['id']?>"><input type="hidden" name="results_released" value="<?=((int)($t['results_released'] ?? 1)===1)?0:1?>"><button class="btn secondary" type="submit"><?=((int)($t['results_released'] ?? 1)===1)?'গোপন করুন':'প্রকাশ করুন'?></button></form></td><td><span class="pill <?=($t['status']??'')==='published'?'live':''?>"><?=mt_h($t['status'])?></span></td><td><a class="btn secondary" href="?view_questions=<?=(int)$t['id']?>#all-tests">প্রশ্ন দেখুন</a> <a class="btn secondary" href="?edit=<?=(int)$t['id']?>#create">সম্পাদনা</a><form method="post" style="display:inline" onsubmit="return confirm('এই মডেল টেস্টটি মুছে ফেলবেন?')"><input type="hidden" name="csrf_token" value="<?=mt_h($_SESSION['csrf_token'])?>"><input type="hidden" name="action" value="delete_test"><input type="hidden" name="test_id" value="<?=(int)$t['id']?>"><button class="btn danger" type="submit">মুছুন</button></form></td></tr><?php endforeach; ?>
 </tbody></table></div>
</section>

<section id="scheduled" class="panel section"><h2>নির্ধারিত পরীক্ষা</h2><p>শুরুর বা শেষের সময় নির্ধারিত পরীক্ষাগুলো নিচে দেখানো হয়েছে।</p><div class="table-wrap"><table><thead><tr><th>পরীক্ষা</th><th>শুরু</th><th>শেষ</th><th>স্ট্যাটাস</th></tr></thead><tbody>
 <?php $scheduled = array_filter($tests, fn($t) => !empty($t['starts_at']) || !empty($t['ends_at'])); ?>
 <?php if (!$scheduled): ?><tr><td colspan="4">কোনো নির্ধারিত পরীক্ষা নেই।</td></tr><?php endif; ?>
 <?php foreach ($scheduled as $t): ?><tr><td><?=mt_h($t['title'])?></td><td><?=mt_h($t['starts_at'] ?? '—')?></td><td><?=mt_h($t['ends_at'] ?? '—')?></td><td><?=mt_h($t['status'])?></td></tr><?php endforeach; ?>
 </tbody></table></div></section>
<section id="results" class="panel section"><h2>পরীক্ষার ফলাফল ও শিক্ষার্থী রিপোর্ট</h2>
 <?php if (!$hasPolicyColumns || !mt_table_exists($pdo, 'model_test_attempts')): ?><p>ফলাফল ও নীতিমালা দেখতে Student Model Test এবং Policy SQL Migration চালাতে হবে।</p>
 <?php else: ?>
 <?php
 $attemptStats = $pdo->query("SELECT COUNT(*) total, SUM(status='in_progress') active, SUM(status IN ('submitted','expired')) submitted, AVG(CASE WHEN status IN ('submitted','expired') THEN score END) average_score FROM model_test_attempts")->fetch(PDO::FETCH_ASSOC) ?: [];
 $attemptRows = $pdo->query("SELECT a.id,a.test_id,a.user_id,a.status,a.started_at,a.submitted_at,a.question_count,a.total_marks,a.score,a.correct_count,a.incorrect_count,a.unanswered_count,a.passed,t.title,t.results_released,u.full_name,u.email FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id LEFT JOIN users u ON u.id=a.user_id ORDER BY a.id DESC LIMIT 200")->fetchAll(PDO::FETCH_ASSOC);
 ?>
 <div class="cards"><div class="stat"><span>মোট Attempt</span><strong><?=(int)($attemptStats['total'] ?? 0)?></strong></div><div class="stat"><span>চলমান</span><strong><?=(int)($attemptStats['active'] ?? 0)?></strong></div><div class="stat"><span>জমা হয়েছে</span><strong><?=(int)($attemptStats['submitted'] ?? 0)?></strong></div><div class="stat"><span>গড় নম্বর</span><strong><?=number_format((float)($attemptStats['average_score'] ?? 0),2)?></strong></div></div>
 <div class="table-wrap"><table><thead><tr><th>শিক্ষার্থী</th><th>পরীক্ষা</th><th>সময়</th><th>অবস্থা</th><th>স্কোর</th><th>সঠিক/ভুল/ফাঁকা</th><th>Pass</th><th>ফলাফল</th></tr></thead><tbody>
 <?php if (!$attemptRows): ?><tr><td colspan="8">এখনো কোনো শিক্ষার্থী পরীক্ষা দেয়নি।</td></tr><?php endif; ?>
 <?php foreach ($attemptRows as $ar): ?><tr><td><a class="btn secondary" href="?attempt=<?=(int)$ar['id']?>#results">বিস্তারিত</a><br><?=mt_h($ar['full_name'] ?: ('User #'.(int)$ar['user_id']))?><br><small><?=mt_h($ar['email'] ?? '')?></small></td><td><?=mt_h($ar['title'])?><br><small>Attempt #<?=(int)$ar['id']?></small></td><td><small>শুরু: <?=mt_h($ar['started_at'])?><br>জমা: <?=mt_h($ar['submitted_at'] ?? 'চলমান')?></small></td><td><?=mt_h($ar['status'])?></td><td><?= $ar['score']===null?'—':mt_h($ar['score']).' / '.mt_h($ar['total_marks']) ?></td><td><?=(int)$ar['correct_count']?> / <?=(int)$ar['incorrect_count']?> / <?=(int)$ar['unanswered_count']?></td><td><?= $ar['passed']===null?'—':((int)$ar['passed']===1?'Pass':'Fail') ?></td><td><?=((int)$ar['results_released']===1)?'প্রকাশিত':'গোপন'?></td></tr><?php endforeach; ?>
 </tbody></table></div>
 <?php
 $detailAttemptId=(int)($_GET['attempt'] ?? 0);
 $detailQuestions=[];
 $detailAttempt=null;
 if($detailAttemptId>0){
   $ds=$pdo->prepare("SELECT a.*,t.title,u.full_name,u.email FROM model_test_attempts a JOIN model_tests t ON t.id=a.test_id LEFT JOIN users u ON u.id=a.user_id WHERE a.id=? LIMIT 1");
   $ds->execute([$detailAttemptId]);$detailAttempt=$ds->fetch(PDO::FETCH_ASSOC) ?: null;
   if($detailAttempt && in_array($detailAttempt['status'], ['submitted','expired'], true)){$dq=$pdo->prepare("SELECT question_order,question_text,option_a,option_b,option_c,option_d,correct_answer,selected_answer,explanation,marks FROM model_test_attempt_questions WHERE attempt_id=? ORDER BY question_order");$dq->execute([$detailAttemptId]);$detailQuestions=$dq->fetchAll(PDO::FETCH_ASSOC);}
 }
 ?>
 <?php if($detailAttempt && in_array($detailAttempt['status'], ['submitted','expired'], true)): ?>
 <h3>Attempt #<?=(int)$detailAttempt['id']?> — <?=mt_h($detailAttempt['full_name'] ?: ('User #'.(int)$detailAttempt['user_id']))?> · <?=mt_h($detailAttempt['title'])?></h3>
 <?php foreach($detailQuestions as $dq): ?><article class="panel"><strong>প্রশ্ন <?=(int)$dq['question_order']?> · <?=mt_h($dq['question_text'])?></strong>
 <p>A. <?=mt_h($dq['option_a'])?><br>B. <?=mt_h($dq['option_b'])?><br>C. <?=mt_h($dq['option_c'])?><br>D. <?=mt_h($dq['option_d'])?></p>
 <p>শিক্ষার্থীর উত্তর: <strong><?=mt_h($dq['selected_answer'] ?? 'উত্তর নেই')?></strong> · সঠিক উত্তর: <strong><?=mt_h($dq['correct_answer'])?></strong> · নম্বর: <?=mt_h($dq['marks'])?></p>
 <?php if(!empty($dq['explanation'])): ?><p>ব্যাখ্যা: <?=mt_h($dq['explanation'])?></p><?php endif; ?>
 </article><?php endforeach; ?>
 <?php elseif($detailAttempt && $detailAttempt['status']==='in_progress'): ?><p>এই পরীক্ষা এখনো চলমান। জমা হওয়ার পর প্রশ্নভিত্তিক উত্তর পর্যালোচনা করা যাবে।</p>
 <?php elseif($detailAttemptId>0): ?><p>এই Attempt পাওয়া যায়নি।</p><?php endif; ?>
 <?php endif; ?>
</section>
<section id="performance" class="panel section"><h2>পারফরম্যান্স বিশ্লেষণ</h2><p>শিক্ষার্থীভিত্তিক স্কোর, সঠিক/ভুল উত্তর, সময় এবং ক্যাটাগরিভিত্তিক পারফরম্যান্সের তথ্য attempt/result ডেটা সংরক্ষণের পর দেখানো যাবে।</p></section>
<div class="preview-modal" id="questionPreviewModal" role="dialog" aria-modal="true" aria-labelledby="questionPreviewTitle"><div class="preview-card"><button type="button" class="btn secondary preview-close" id="closeQuestionPreview">বন্ধ করুন ✕</button><h3 id="questionPreviewTitle">প্রশ্নের প্রিভিউ</h3><div id="questionPreviewBody"></div></div></div>
<footer class="hint">Fire Safety Job Prep · Model Test Admin</footer>
</main></div>
<script src="/assets/model-tests.js?v=7351e043" defer></script>
<script>
(function () {
  'use strict';
  function bindModelTestSelectionFallback() {
    var list = document.getElementById('questionList');
    if (!list || list.dataset.inlineSelectionReady === '1') return;
    list.dataset.inlineSelectionReady = '1';
    var count = document.getElementById('selectedQuestionCount');
    var selectAll = document.getElementById('selectVisibleQuestions');
    var clearAll = document.getElementById('clearVisibleQuestions');
    function rows() { return Array.prototype.slice.call(list.querySelectorAll('.question-box')); }
    function checkbox(row) { return row.querySelector('input[name="question_ids[]"][type="checkbox"]'); }
    function sync() {
      var selected = 0;
      rows().forEach(function (row) {
        var input = checkbox(row);
        var checked = !!(input && input.checked);
        row.classList.toggle('is-selected', checked);
        row.setAttribute('aria-selected', checked ? 'true' : 'false');
        if (checked) selected++;
      });
      if (count) count.textContent = 'নির্বাচিত: ' + selected;
    }
    if (selectAll) selectAll.addEventListener('click', function (event) {
      event.preventDefault();
      rows().forEach(function (row) { var input = checkbox(row); if (input) input.checked = true; });
      sync();
    });
    if (clearAll) clearAll.addEventListener('click', function (event) {
      event.preventDefault();
      rows().forEach(function (row) { var input = checkbox(row); if (input) input.checked = false; });
      sync();
    });
    list.addEventListener('change', function (event) {
      if (event.target && event.target.matches('input[name="question_ids[]"][type="checkbox"]')) sync();
    });
    sync();
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bindModelTestSelectionFallback);
  } else {
    bindModelTestSelectionFallback();
  }
})();
</script>
</body></html>
