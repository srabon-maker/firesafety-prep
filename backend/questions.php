<?php
declare(strict_types=1);

require __DIR__ . '/admin_helpers.php';
require_admin();
require __DIR__ . '/db.php';

if (!isset($pdo) || !($pdo instanceof PDO)) {
    http_response_code(500);
    exit('Database connection is unavailable.');
}
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

$message = '';
$messageType = 'success';
$editQuestion = null;
$preview = $_SESSION['question_docx_preview'] ?? null;

function qh(string $value): string { return h($value); }
function qlen(string $value): int { return function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value); }
function qnorm(string $value): string {
    $value = trim($value);
    $value = preg_replace('/\s+/u', ' ', $value) ?? $value;
    return function_exists('mb_strtolower') ? mb_strtolower($value, 'UTF-8') : strtolower($value);
}
function qfield(?array $row, string $key): string { return h((string)($row[$key] ?? '')); }

function question_page_url(int $page, string $search, string $category, string $difficulty, string $language, string $status): string {
    $query = ['page' => $page];
    foreach (['q'=>$search, 'category'=>$category, 'difficulty'=>$difficulty, 'language'=>$language, 'status'=>$status] as $key=>$value) {
        if ($value !== '') $query[$key] = $value;
    }
    return '?' . http_build_query($query);
}

/** Read both ordinary paragraphs and Word tables without extracting files. */
function docx_content(string $file): array {
    if (!class_exists('ZipArchive') || !class_exists('DOMDocument')) {
        throw new RuntimeException('সার্ভারে PHP ZipArchive এবং DOM extension চালু নেই। Hosting support-কে এগুলো চালু করতে বলুন।');
    }
    $zip = new ZipArchive();
    if ($zip->open($file) !== true) throw new RuntimeException('DOCX ফাইলটি খোলা যায়নি।');
    $xml = $zip->getFromName('word/document.xml');
    $zip->close();
    if ($xml === false) throw new RuntimeException('সঠিক Word .docx ফাইল দিন।');

    $dom = new DOMDocument();
    $previous = libxml_use_internal_errors(true);
    $loaded = $dom->loadXML($xml, LIBXML_NONET | LIBXML_NOBLANKS);
    libxml_clear_errors();
    libxml_use_internal_errors($previous);
    if (!$loaded) throw new RuntimeException('DOCX-এর document structure পড়া যায়নি।');

    $xp = new DOMXPath($dom);
    $xp->registerNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
    $body = $xp->query('/w:document/w:body')->item(0);
    if (!$body) throw new RuntimeException('Word document-এর body পাওয়া যায়নি.');

    $paragraphs = [];
    $tables = [];
    foreach ($body->childNodes as $node) {
        if ($node instanceof DOMElement && $node->localName === 'p') {
            $text = '';
            foreach ($xp->query('.//w:t | .//w:tab | .//w:br', $node) as $part) {
                if ($part->localName === 't') $text .= $part->textContent;
                elseif ($part->localName === 'tab') $text .= "\t";
                else $text .= "\n";
            }
            $text = trim($text);
            if ($text !== '') $paragraphs[] = $text;
        } elseif ($node instanceof DOMElement && $node->localName === 'tbl') {
            $rows = [];
            foreach ($xp->query('./w:tr', $node) as $tr) {
                $cells = [];
                foreach ($xp->query('./w:tc', $tr) as $tc) {
                    $parts = [];
                    foreach ($xp->query('.//w:t', $tc) as $t) $parts[] = $t->textContent;
                    $cells[] = trim(implode('', $parts));
                }
                if (array_filter($cells, static fn($v) => $v !== '')) $rows[] = $cells;
            }
            if ($rows) $tables[] = $rows;
        }
    }
    return ['paragraphs'=>$paragraphs, 'tables'=>$tables];
}

function clean_label(string $label): string {
    $label = trim(mb_strtolower($label, 'UTF-8'));
    $label = str_replace([' ', '_', '-', '.', ':', '：'], '', $label);
    return $label;
}
function field_key(string $label): ?string {
    $x = clean_label($label);
    $map = [
        'category'=>'category','ক্যাটাগরি'=>'category','বিষয়'=>'category','বিষয়'=>'category',
        'question'=>'question','প্রশ্ন'=>'question',
        'optiona'=>'option_a','optionক'=>'option_a','অপশনa'=>'option_a','অপশনক'=>'option_a','ক'=>'option_a',
        'optionb'=>'option_b','optionখ'=>'option_b','অপশনb'=>'option_b','অপশনখ'=>'option_b','খ'=>'option_b',
        'optionc'=>'option_c','optionগ'=>'option_c','অপশনc'=>'option_c','অপশনগ'=>'option_c','গ'=>'option_c',
        'optiond'=>'option_d','optionঘ'=>'option_d','অপশনd'=>'option_d','অপশনঘ'=>'option_d','ঘ'=>'option_d',
        'correctanswer'=>'correct_answer','answer'=>'correct_answer','সঠিকউত্তর'=>'correct_answer','উত্তর'=>'correct_answer',
        'explanation'=>'explanation','ব্যাখ্যা'=>'explanation',
        'reference'=>'reference','সূত্র'=>'reference','রেফারেন্স'=>'reference',
        'difficulty'=>'difficulty','level'=>'difficulty','কঠিনতারমাত্রা'=>'difficulty','কঠিনতা'=>'difficulty',
        'language'=>'language','ভাষা'=>'language',
        'status'=>'status','অবস্থা'=>'status'
    ];
    return $map[$x] ?? null;
}
function normalize_answer(string $value): string {
    $v = strtoupper(trim($value));
    if (preg_match('/^[A-Dকখগঘ](?:[\.\)\:\-])?$/u', $v)) {
        $map = ['ক'=>'A','খ'=>'B','গ'=>'C','ঘ'=>'D'];
        return $map[$v] ?? $v;
    }
    if (preg_match('/^(?:OPTION|উত্তর)\s*([A-D])$/iu', $v, $m)) return strtoupper($m[1]);
    if (preg_match('/^([A-Dকখগঘ])[\.\)\:\-]/u', $v, $m)) {
        $map = ['ক'=>'A','খ'=>'B','গ'=>'C','ঘ'=>'D'];
        return $map[strtoupper($m[1])] ?? strtoupper($m[1]);
    }
    return $v;
}
function normalize_meta(array &$q): void {
    $d = strtolower(trim((string)($q['difficulty'] ?? 'medium')));
    $q['difficulty'] = in_array($d, ['easy','medium','hard'], true) ? $d : 'medium';
    $l = strtolower(trim((string)($q['language'] ?? 'english')));
    $q['language'] = (str_contains($l, 'bang') || str_contains($l, 'বাংলা')) ? 'Bangla' : ((str_contains($l, 'both') || str_contains($l, 'উভয়')) ? 'Both' : 'English');
    $s = strtolower(trim((string)($q['status'] ?? 'published')));
    $q['status'] = (in_array($s, ['draft','খসড়া','খসড়া'], true)) ? 'draft' : 'published';
}
function parse_docx_questions(array $content, string $defaultCategory): array {
    $out = [];
    $base = ['category'=>$defaultCategory,'question'=>'','option_a'=>'','option_b'=>'','option_c'=>'','option_d'=>'','correct_answer'=>'','explanation'=>'','reference'=>'','difficulty'=>'medium','language'=>'English','status'=>'published'];

    // Each key/value Word table is treated as one question record.
    foreach ($content['tables'] as $table) {
        $q = $base;
        $recognized = 0;
        foreach ($table as $cells) {
            if (count($cells) >= 2) {
                $key = field_key((string)$cells[0]);
                if ($key !== null) {
                    $q[$key] = trim(implode(' ', array_slice($cells, 1)));
                    $recognized++;
                }
            }
        }
        if ($recognized > 0 && trim($q['question']) !== '') {
            $q['correct_answer'] = normalize_answer($q['correct_answer']);
            normalize_meta($q);
            $out[] = $q;
        }
    }

    // Paragraph-style documents: Question/প্রশ্ন labels start a new record.
    $current = null;
    $lastField = null;
    $finish = static function() use (&$current, &$out): void {
        if ($current !== null && trim((string)$current['question']) !== '') {
            $current['correct_answer'] = normalize_answer((string)$current['correct_answer']);
            normalize_meta($current);
            $out[] = $current;
        }
        $current = null;
    };
    foreach ($content['paragraphs'] as $line) {
        if (preg_match('/^(?:question|প্রশ্ন)\s*\d*\s*[:：\-]\s*(.*)$/iu', $line, $m)) {
            $finish();
            $current = $base;
            $current['question'] = trim($m[1]);
            $lastField = 'question';
            continue;
        }
        if ($current === null) {
            $current = $base;
        }
        if (preg_match('/^(?:option\s*)?([A-Dকখগঘ])\s*[\.\)\:\-]\s*(.*)$/iu', $line, $m)) {
            $letter = strtoupper($m[1]);
            $map = ['A'=>'option_a','B'=>'option_b','C'=>'option_c','D'=>'option_d','ক'=>'option_a','খ'=>'option_b','গ'=>'option_c','ঘ'=>'option_d'];
            $lastField = $map[$letter] ?? $map[mb_strtolower($letter,'UTF-8')] ?? null;
            if ($lastField) $current[$lastField] = trim($m[2]);
            continue;
        }
        if (preg_match('/^([^:：]+)\s*[:：]\s*(.*)$/u', $line, $m)) {
            $key = field_key($m[1]);
            if ($key !== null) {
                if ($key === 'question' && trim((string)$current['question']) !== '') { $finish(); $current = $base; }
                $current[$key] = trim($m[2]);
                $lastField = $key;
                continue;
            }
        }
        if ($lastField !== null && isset($current[$lastField])) {
            $current[$lastField] = trim((string)$current[$lastField] . ' ' . $line);
        } elseif (trim((string)$current['question']) === '') {
            $current['question'] = $line;
            $lastField = 'question';
        }
    }
    $finish();

    // Remove records that are only empty table/paragraph artifacts.
    $unique = [];
    foreach ($out as $q) {
        if (trim((string)$q['question']) !== '') $unique[] = $q;
    }
    return $unique;
}
function validate_import_question(array $q): array {
    $errors = [];
    foreach (['category'=>'ক্যাটাগরি','question'=>'প্রশ্ন','option_a'=>'Option A','option_b'=>'Option B','option_c'=>'Option C','option_d'=>'Option D'] as $key=>$label) {
        if (trim((string)($q[$key] ?? '')) === '') $errors[] = $label . ' নেই';
    }
    if (!in_array((string)($q['correct_answer'] ?? ''), ['A','B','C','D'], true)) $errors[] = 'সঠিক উত্তর A/B/C/D নয়';
    if (qlen((string)($q['category'] ?? '')) > 100) $errors[] = 'ক্যাটাগরি ১০০ অক্ষরের বেশি';
    return $errors;
}


/* Optional feature schema introduced by migration 20261119_question_bank_features.sql. */
function q_table_exists(PDO $pdo, string $table): bool {
    $st = $pdo->prepare('SHOW TABLES LIKE ?');
    $st->execute([$table]);
    return (bool)$st->fetchColumn();
}
function q_column_exists(PDO $pdo, string $column): bool {
    if (!in_array($column, ['image_path','is_archived'], true)) return false;
    $st = $pdo->prepare('SHOW COLUMNS FROM questions LIKE ?');
    $st->execute([$column]);
    return (bool)$st->fetch(PDO::FETCH_ASSOC);
}
function q_json_snapshot(array $row): string {
    $allowed = ['id','category','question','option_a','option_b','option_c','option_d','correct_answer','explanation','difficulty','language','reference','status','image_path','is_archived'];
    $data = [];
    foreach ($allowed as $key) if (array_key_exists($key, $row)) $data[$key] = $row[$key];
    return json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
}
function q_save_revision(PDO $pdo, int $questionId, string $event, ?array $before, ?array $after): void {
    $actor = (string)($_SESSION['admin_username'] ?? $_SESSION['admin_name'] ?? 'admin');
    $st = $pdo->prepare('INSERT INTO question_revisions (question_id,event_type,before_data,after_data,changed_by,created_at) VALUES (?,?,?,?,?,NOW())');
    $actorName = function_exists('mb_substr') ? mb_substr($actor, 0, 120, 'UTF-8') : substr($actor, 0, 120);
    $st->execute([$questionId, $event, $before ? q_json_snapshot($before) : null, $after ? q_json_snapshot($after) : null, $actorName]);
}
function q_upload_image(?array $file): ?string {
    if ($file === null || ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) return null;
    if (!isset($file['error']) || is_array($file['error']) || $file['error'] !== UPLOAD_ERR_OK) throw new RuntimeException('ছবি আপলোড করা যায়নি। আবার চেষ্টা করুন।');
    $tmp = $file['tmp_name'] ?? '';
    $size = (int)($file['size'] ?? 0);
    if (!is_string($tmp) || !is_uploaded_file($tmp) || $size < 1 || $size > 5 * 1024 * 1024) throw new RuntimeException('ছবির সর্বোচ্চ সাইজ ৫ MB।');
    if (!function_exists('finfo_open') || !function_exists('getimagesize')) throw new RuntimeException('সার্ভারে image validation extension চালু নেই।');
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($tmp);
    $types = ['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp'];
    if (!is_string($mime) || !isset($types[$mime])) throw new RuntimeException('শুধু JPG, PNG অথবা WEBP ছবি দেওয়া যাবে।');
    $info = @getimagesize($tmp);
    if (!$info || (int)$info[0] > 6000 || (int)$info[1] > 6000 || ((int)$info[0] * (int)$info[1]) > 20000000) throw new RuntimeException('ছবির dimensions অনুমোদিত সীমার বাইরে।');
    $dir = __DIR__ . '/uploads/questions';
    if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) throw new RuntimeException('Question image folder তৈরি করা যায়নি।');
    $guard = $dir . '/.htaccess';
    if (!is_file($guard)) @file_put_contents($guard, "Options -Indexes\n<FilesMatch \"\\.(php|phtml|php[0-9]*)$\">\nRequire all denied\n</FilesMatch>\n");
    $name = bin2hex(random_bytes(16)) . '.' . $types[$mime];
    if (!move_uploaded_file($tmp, $dir . '/' . $name)) throw new RuntimeException('ছবি সংরক্ষণ করা যায়নি।');
    @chmod($dir . '/' . $name, 0644);
    return 'uploads/questions/' . $name;
}
function q_delete_local_image(?string $path): void {
    if (!$path || !str_starts_with($path, 'uploads/questions/')) return;
    $full = __DIR__ . '/' . $path;
    if (is_file($full)) @unlink($full);
}
function q_similarity(string $a, string $b): float {
    $a = qnorm($a); $b = qnorm($b);
    if ($a === '' || $b === '') return 0.0;
    if ($a === $b) return 1.0;
    $tokensA = array_values(array_unique(preg_split('/[^\p{L}\p{N}]+/u', $a, -1, PREG_SPLIT_NO_EMPTY) ?: []));
    $tokensB = array_values(array_unique(preg_split('/[^\p{L}\p{N}]+/u', $b, -1, PREG_SPLIT_NO_EMPTY) ?: []));
    if (!$tokensA || !$tokensB) return 0.0;
    $intersection = count(array_intersect($tokensA, $tokensB));
    return $intersection / max(1, count(array_unique(array_merge($tokensA, $tokensB))));
}
function q_similar_from_rows(array $rows, string $question, ?int $excludeId = null, int $limit = 3): array {
    $matches = [];
    foreach ($rows as $row) {
        if ($excludeId && (int)$row['id'] === $excludeId) continue;
        $score = q_similarity($question, (string)$row['question']);
        if ($score >= 0.72) $matches[] = ['id'=>(int)$row['id'],'category'=>(string)$row['category'],'question'=>(string)$row['question'],'score'=>$score];
    }
    usort($matches, static fn($a,$b) => $b['score'] <=> $a['score']);
    return array_slice($matches, 0, $limit);
}
function q_near_duplicates(PDO $pdo, string $question, ?int $excludeId = null, int $limit = 5): array {
    $rows = $pdo->query('SELECT id,category,question FROM questions ORDER BY id DESC LIMIT 3000')->fetchAll(PDO::FETCH_ASSOC);
    return q_similar_from_rows($rows, $question, $excludeId, $limit);
}

function existing_question_map(PDO $pdo): array {
    $map = [];
    foreach ($pdo->query('SELECT id, question FROM questions')->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $key = qnorm((string)$row['question']);
        if ($key !== '') $map[$key] = (int)$row['id'];
    }
    return $map;
}

$hasArchiveColumn = q_column_exists($pdo, 'is_archived');
$hasImageColumn = q_column_exists($pdo, 'image_path');
$hasRevisionTable = q_table_exists($pdo, 'question_revisions');
$featureSchemaReady = $hasArchiveColumn && $hasImageColumn && $hasRevisionTable;

/* All POST actions share the existing admin CSRF protection. */
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verify_csrf();
    $action = (string)($_POST['action'] ?? '');

    if (in_array($action, ['archive','restore','bulk_action'], true) && !$featureSchemaReady) {
        $message = 'Archive, Bulk Action ও Revision ফিচার চালুর আগে GitHub-এর migrations/20261119_question_bank_features.sql phpMyAdmin-এ একবার চালান।';
        $messageType = 'error';
    } elseif ($action === 'delete') {
        $id = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id || $id < 1) { $message = 'সঠিক প্রশ্ন আইডি পাওয়া যায়নি।'; $messageType = 'error'; }
        else {
            $st = $pdo->prepare('SELECT * FROM questions WHERE id=?'); $st->execute([$id]); $before = $st->fetch(PDO::FETCH_ASSOC);
            if ($before && $featureSchemaReady) q_save_revision($pdo, (int)$id, 'deleted', $before, null);
            $stmt = $pdo->prepare('DELETE FROM questions WHERE id=?');
            $stmt->execute([$id]);
            $message = $stmt->rowCount() ? 'প্রশ্নটি মুছে ফেলা হয়েছে। Revision History-তে আগের তথ্য সংরক্ষিত আছে।' : 'প্রশ্নটি পাওয়া যায়নি।';
            $messageType = $stmt->rowCount() ? 'success' : 'warning';
        }
    } elseif ($action === 'archive' || $action === 'restore') {
        $id = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id || $id < 1) { $message = 'সঠিক প্রশ্ন আইডি পাওয়া যায়নি।'; $messageType = 'error'; }
        else {
            $st=$pdo->prepare('SELECT * FROM questions WHERE id=?'); $st->execute([$id]); $before=$st->fetch(PDO::FETCH_ASSOC);
            if (!$before) { $message='প্রশ্নটি পাওয়া যায়নি।'; $messageType='warning'; }
            else {
                $value = $action === 'archive' ? 1 : 0;
                $pdo->prepare('UPDATE questions SET is_archived=? WHERE id=?')->execute([$value,$id]);
                $after=$before; $after['is_archived']=$value;
                q_save_revision($pdo,(int)$id,$action==='archive'?'archived':'restored',$before,$after);
                $message = $action === 'archive' ? 'প্রশ্নটি Archive করা হয়েছে।' : 'প্রশ্নটি Restore করা হয়েছে।';
            }
        }
    } elseif ($action === 'bulk_action') {
        $ids = $_POST['selected_ids'] ?? [];
        if (!is_array($ids)) $ids = [];
        $ids = array_values(array_unique(array_filter(array_map('intval',$ids),static fn($v)=>$v>0)));
        $operation = (string)($_POST['bulk_operation'] ?? '');
        if (!$ids || count($ids)>200) { $message='একবারে ১ থেকে ২০০টি প্রশ্ন নির্বাচন করুন।'; $messageType='error'; }
        elseif (!in_array($operation,['publish','draft','archive','restore','delete'],true)) { $message='Bulk action সঠিক নয়।'; $messageType='error'; }
        else {
            $marks=implode(',',array_fill(0,count($ids),'?'));
            $st=$pdo->prepare("SELECT * FROM questions WHERE id IN ($marks)"); $st->execute($ids); $rows=$st->fetchAll(PDO::FETCH_ASSOC);
            $pdo->beginTransaction();
            try {
                foreach($rows as $row) {
                    $id=(int)$row['id'];
                    if($operation==='delete') {
                        q_save_revision($pdo,$id,'deleted',$row,null);
                        $pdo->prepare('DELETE FROM questions WHERE id=?')->execute([$id]);
                    } else {
                        $after=$row;
                        if($operation==='publish'||$operation==='draft') {$after['status']=$operation;$pdo->prepare('UPDATE questions SET status=? WHERE id=?')->execute([$operation,$id]);}
                        else {$v=$operation==='archive'?1:0;$after['is_archived']=$v;$pdo->prepare('UPDATE questions SET is_archived=? WHERE id=?')->execute([$v,$id]);}
                        q_save_revision($pdo,$id,'bulk_'.$operation,$row,$after);
                    }
                }
                $pdo->commit(); $message=count($rows).'টি প্রশ্নে Bulk Action সম্পন্ন হয়েছে।';
            } catch(Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); throw $e; }
        }
    } elseif ($action === 'save') {
        $id = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
        $id = ($id && $id > 0) ? $id : null;
        $q = [
            'category'=>trim((string)($_POST['category'] ?? '')),
            'question'=>trim((string)($_POST['question'] ?? '')),
            'option_a'=>trim((string)($_POST['option_a'] ?? '')),
            'option_b'=>trim((string)($_POST['option_b'] ?? '')),
            'option_c'=>trim((string)($_POST['option_c'] ?? '')),
            'option_d'=>trim((string)($_POST['option_d'] ?? '')),
            'correct_answer'=>strtoupper(trim((string)($_POST['correct_answer'] ?? ''))),
            'explanation'=>trim((string)($_POST['explanation'] ?? '')),
            'reference'=>trim((string)($_POST['reference'] ?? '')),
            'difficulty'=>(string)($_POST['difficulty'] ?? 'medium'),
            'language'=>(string)($_POST['language'] ?? 'English'),
            'status'=>(string)($_POST['status'] ?? 'published')
        ];
        $errors = validate_import_question($q);
        if ($errors) { $message = implode(' · ', $errors); $messageType = 'error'; }
        elseif (!in_array($q['difficulty'], ['easy','medium','hard'], true) || !in_array($q['language'], ['Bangla','English','Both'], true) || !in_array($q['status'], ['draft','published'], true)) {
            $message = 'Difficulty, Language অথবা Status-এর মান সঠিক নয়।'; $messageType = 'error';
        } else {
            $dupe = $pdo->prepare('SELECT id FROM questions WHERE question = ?' . ($id ? ' AND id <> ?' : '') . ' LIMIT 1');
            $dupe->execute($id ? [$q['question'],$id] : [$q['question']]);
            $duplicateId = $dupe->fetchColumn();
            if ($duplicateId) { $message = 'একই প্রশ্ন আগে থেকেই আছে (ID: ' . (int)$duplicateId . ')।'; $messageType = 'warning'; }
            elseif (!$featureSchemaReady) {
                if (!empty($_FILES['question_image']['name'])) { $message='Image Upload চালুর আগে migration SQL চালান।'; $messageType='error'; }
                elseif ($id) {
                    $stmt = $pdo->prepare('UPDATE questions SET category=?,question=?,option_a=?,option_b=?,option_c=?,option_d=?,correct_answer=?,explanation=?,difficulty=?,language=?,reference=?,status=? WHERE id=?');
                    $stmt->execute([$q['category'],$q['question'],$q['option_a'],$q['option_b'],$q['option_c'],$q['option_d'],$q['correct_answer'],$q['explanation'],$q['difficulty'],$q['language'],$q['reference'],$q['status'],$id]);
                    $message='প্রশ্নটি আপডেট করা হয়েছে।';
                } else {
                    $stmt = $pdo->prepare('INSERT INTO questions (category,question,option_a,option_b,option_c,option_d,correct_answer,explanation,difficulty,language,reference,status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)');
                    $stmt->execute([$q['category'],$q['question'],$q['option_a'],$q['option_b'],$q['option_c'],$q['option_d'],$q['correct_answer'],$q['explanation'],$q['difficulty'],$q['language'],$q['reference'],$q['status']]);
                    $message='নতুন প্রশ্ন সফলভাবে যুক্ত হয়েছে।';
                }
            } else {
                $before = null;
                if ($id) { $st=$pdo->prepare('SELECT * FROM questions WHERE id=?'); $st->execute([$id]); $before=$st->fetch(PDO::FETCH_ASSOC) ?: null; }
                $newImage = null;
                try {
                    $newImage = q_upload_image($_FILES['question_image'] ?? null);
                    $imagePath = $newImage ?: (string)($before['image_path'] ?? '');
                    $pdo->beginTransaction();
                    try {
                    if ($id) {
                        $stmt = $pdo->prepare('UPDATE questions SET category=?,question=?,option_a=?,option_b=?,option_c=?,option_d=?,correct_answer=?,explanation=?,difficulty=?,language=?,reference=?,status=?,image_path=? WHERE id=?');
                        $stmt->execute([$q['category'],$q['question'],$q['option_a'],$q['option_b'],$q['option_c'],$q['option_d'],$q['correct_answer'],$q['explanation'],$q['difficulty'],$q['language'],$q['reference'],$q['status'],$imagePath ?: null,$id]);
                        $after=$q; $after['id']=$id; $after['image_path']=$imagePath ?: null; $after['is_archived']=(int)($before['is_archived']??0);
                        q_save_revision($pdo,$id,'updated',$before,$after);
                        $message = 'প্রশ্নটি আপডেট করা হয়েছে।';
                    } else {
                        $stmt = $pdo->prepare('INSERT INTO questions (category,question,option_a,option_b,option_c,option_d,correct_answer,explanation,difficulty,language,reference,status,image_path,is_archived) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,0)');
                        $stmt->execute([$q['category'],$q['question'],$q['option_a'],$q['option_b'],$q['option_c'],$q['option_d'],$q['correct_answer'],$q['explanation'],$q['difficulty'],$q['language'],$q['reference'],$q['status'],$imagePath ?: null]);
                        $newId=(int)$pdo->lastInsertId(); $after=$q; $after['id']=$newId; $after['image_path']=$imagePath ?: null; $after['is_archived']=0;
                        q_save_revision($pdo,$newId,'created',null,$after);
                        $message = 'নতুন প্রশ্ন সফলভাবে যুক্ত হয়েছে।';
                    }
                    $pdo->commit();
                    } catch (Throwable $saveError) {
                        if ($pdo->inTransaction()) $pdo->rollBack();
                        throw $saveError;
                    }
                    if($newImage && $id && !empty($before['image_path'])) q_delete_local_image((string)$before['image_path']);
                    $near=q_near_duplicates($pdo,$q['question'],$id ?: ($newId ?? null));
                    if($near){$message.=' কাছাকাছি মিল পাওয়া গেছে: #'.(int)$near[0]['id'].' ('.round($near[0]['score']*100).'%).';$messageType='warning';}
                } catch(Throwable $e) {
                    if($newImage) q_delete_local_image($newImage);
                    throw $e;
                }
            }
        }
    } elseif ($action === 'docx_preview') {
        try {
            if (!isset($_FILES['docx_file']) || $_FILES['docx_file']['error'] !== UPLOAD_ERR_OK) throw new RuntimeException('DOCX ফাইল আপলোড হয়নি বা আপলোডে সমস্যা হয়েছে।');
            if ((int)$_FILES['docx_file']['size'] > 10 * 1024 * 1024) throw new RuntimeException('ফাইলের সাইজ সর্বোচ্চ ১০ MB হতে পারবে।');
            $filename = (string)$_FILES['docx_file']['name'];
            if (strtolower(pathinfo($filename, PATHINFO_EXTENSION)) !== 'docx') throw new RuntimeException('শুধু .docx ফাইল আপলোড করা যাবে।');
            $defaultCategory = trim((string)($_POST['default_category'] ?? 'General'));
            if ($defaultCategory === '') $defaultCategory = 'General';
            $content = docx_content((string)$_FILES['docx_file']['tmp_name']);
            $parsed = parse_docx_questions($content, $defaultCategory);
            if (!$parsed) throw new RuntimeException('ফাইল থেকে কোনো প্রশ্ন শনাক্ত করা যায়নি। DOCX-এর লেবেল/ফরম্যাট পরীক্ষা করুন।');
            $existing = existing_question_map($pdo);
            $existingRows = $pdo->query('SELECT id,category,question FROM questions ORDER BY id DESC LIMIT 3000')->fetchAll(PDO::FETCH_ASSOC);
            $seen = [];
            $valid = 0;
            foreach ($parsed as $i => &$row) {
                $row['_errors'] = validate_import_question($row);
                $key = qnorm((string)$row['question']);
                if ($key !== '' && isset($existing[$key])) $row['_duplicate'] = 'ডেটাবেজে ID ' . $existing[$key] . ' নম্বরে আছে';
                elseif ($key !== '' && isset($seen[$key])) $row['_duplicate'] = 'এই ফাইলের প্রশ্ন #' . $seen[$key] . '-এর সঙ্গে ডুপ্লিকেট';
                else $row['_duplicate'] = '';
                $row['_similar'] = q_similar_from_rows($existingRows, (string)$row['question'], null, 1);
                if (!$row['_errors'] && $row['_duplicate'] === '') $valid++;
                $seen[$key] = $i + 1;
            }
            unset($row);
            $_SESSION['question_docx_preview'] = ['filename'=>$filename,'rows'=>$parsed,'created'=>time()];
            $preview = $_SESSION['question_docx_preview'];
            $message = 'প্রিভিউ তৈরি হয়েছে। মোট ' . count($parsed) . 'টি প্রশ্ন শনাক্ত হয়েছে; যোগ করা যাবে ' . $valid . 'টি।';
            $messageType = 'success';
        } catch (Throwable $e) {
            error_log('Question DOCX preview: ' . $e->getMessage());
            $message = $e->getMessage();
            $messageType = 'error';
        }
    } elseif ($action === 'paste_preview') {
        try {
            $raw = trim((string)($_POST['bulk_questions'] ?? ''));
            if ($raw === '') throw new RuntimeException('প্রশ্নের লেখা পেস্ট করুন।');
            if (qlen($raw) > 500000) throw new RuntimeException('একবারে সর্বোচ্চ ৫০০,০০০ অক্ষর পেস্ট করা যাবে।');
            $defaultCategory = trim((string)($_POST['default_category'] ?? 'General'));
            if ($defaultCategory === '') $defaultCategory = 'General';
            $lines = preg_split('/\r\n|\r|\n/u', $raw) ?: [];
            $parsed = parse_docx_questions(['paragraphs'=>$lines,'tables'=>[]], $defaultCategory);
            if (!$parsed) throw new RuntimeException('কোনো প্রশ্ন শনাক্ত হয়নি। নমুনা ফরম্যাট অনুসরণ করুন।');
            $existing = existing_question_map($pdo);
            $existingRows = $pdo->query('SELECT id,category,question FROM questions ORDER BY id DESC LIMIT 3000')->fetchAll(PDO::FETCH_ASSOC);
            $seen = []; $valid = 0;
            foreach ($parsed as $i => &$row) {
                $row['_errors'] = validate_import_question($row);
                $key = qnorm((string)$row['question']);
                if ($key !== '' && isset($existing[$key])) $row['_duplicate'] = 'ডেটাবেজে ID ' . $existing[$key] . ' নম্বরে আছে';
                elseif ($key !== '' && isset($seen[$key])) $row['_duplicate'] = 'এই পেস্টের প্রশ্ন #' . $seen[$key] . '-এর সঙ্গে ডুপ্লিকেট';
                else $row['_duplicate'] = '';
                $row['_similar'] = q_similar_from_rows($existingRows, (string)$row['question'], null, 1);
                if (!$row['_errors'] && $row['_duplicate'] === '') $valid++;
                if ($key !== '') $seen[$key] = $i + 1;
            }
            unset($row);
            $_SESSION['question_docx_preview'] = ['filename'=>'কপি-পেস্ট করা প্রশ্ন','rows'=>$parsed,'created'=>time()];
            $preview = $_SESSION['question_docx_preview'];
            $message = 'প্রিভিউ তৈরি হয়েছে। মোট ' . count($parsed) . 'টি প্রশ্ন শনাক্ত হয়েছে; যোগ করা যাবে ' . $valid . 'টি।';
            $messageType = 'success';
        } catch (Throwable $e) {
            $message = $e->getMessage(); $messageType = 'error';
        }
    } elseif ($action === 'docx_import') {
        $saved = $_SESSION['question_docx_preview'] ?? null;
        if (!is_array($saved) || empty($saved['rows']) || !is_array($saved['rows'])) {
            $message = 'প্রিভিউ পাওয়া যায়নি। আবার DOCX আপলোড করে Preview তৈরি করুন।'; $messageType = 'error';
        } else {
            try {
                $pdo->beginTransaction();
                $existing = existing_question_map($pdo);
                $insert = $pdo->prepare('INSERT INTO questions (category,question,option_a,option_b,option_c,option_d,correct_answer,explanation,difficulty,language,reference,status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)');
                $inserted = 0; $skipped = 0;
                foreach ($saved['rows'] as $row) {
                    $errors = validate_import_question($row);
                    $key = qnorm((string)($row['question'] ?? ''));
                    if ($errors || $key === '' || isset($existing[$key])) { $skipped++; continue; }
                    normalize_meta($row);
                    $insert->execute([
                        trim((string)$row['category']),trim((string)$row['question']),
                        trim((string)$row['option_a']),trim((string)$row['option_b']),
                        trim((string)$row['option_c']),trim((string)$row['option_d']),
                        normalize_answer((string)$row['correct_answer']),
                        trim((string)($row['explanation'] ?? '')),
                        $row['difficulty'],$row['language'],
                        trim((string)($row['reference'] ?? '')),$row['status']
                    ]);
                    $existing[$key] = (int)$pdo->lastInsertId();
                    $inserted++;
                }
                $pdo->commit();
                unset($_SESSION['question_docx_preview']);
                $preview = null;
                $message = $inserted . 'টি প্রশ্ন যুক্ত হয়েছে; ' . $skipped . 'টি অসম্পূর্ণ/ডুপ্লিকেট প্রশ্ন বাদ দেওয়া হয়েছে।';
                $messageType = 'success';
            } catch (Throwable $e) {
                if ($pdo->inTransaction()) $pdo->rollBack();
                error_log('Question DOCX import: ' . $e->getMessage());
                $message = 'Import সম্পন্ন হয়নি। সার্ভারের error log পরীক্ষা করুন।';
                $messageType = 'error';
            }
        }
    } elseif ($action === 'clear_preview') {
        unset($_SESSION['question_docx_preview']);
        $preview = null;
        $message = 'প্রশ্নের প্রিভিউ বাতিল করা হয়েছে।';
    } else {
        $message = 'অনুরোধটি সঠিক নয়।'; $messageType = 'error';
    }
}

/* Reload preview after POST. */
$preview = $_SESSION['question_docx_preview'] ?? null;

/* Load selected question for editing. */
if (isset($_GET['edit'])) {
    $editId = filter_var($_GET['edit'], FILTER_VALIDATE_INT);
    if ($editId && $editId > 0) {
        $stmt = $pdo->prepare('SELECT * FROM questions WHERE id=?');
        $stmt->execute([$editId]);
        $editQuestion = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
        if (!$editQuestion) { $message = 'সম্পাদনার জন্য প্রশ্নটি পাওয়া যায়নি।'; $messageType = 'warning'; }
    }
}

/* Filters and question list. */
$view = (string)($_GET['view'] ?? 'active');
if (!in_array($view,['active','archived'],true)) $view='active';
$historyId = filter_var($_GET['history'] ?? null, FILTER_VALIDATE_INT);
$historyRows = [];
if ($historyId && $featureSchemaReady) {
    $hs=$pdo->prepare('SELECT * FROM question_revisions WHERE question_id=? ORDER BY id DESC LIMIT 100');
    $hs->execute([$historyId]); $historyRows=$hs->fetchAll(PDO::FETCH_ASSOC);
}
$search = trim((string)($_GET['q'] ?? ''));
$selectedCategory = trim((string)($_GET['category'] ?? ''));
$difficulty = trim((string)($_GET['difficulty'] ?? ''));
$language = trim((string)($_GET['language'] ?? ''));
$status = trim((string)($_GET['status'] ?? ''));
$page = filter_var($_GET['page'] ?? 1, FILTER_VALIDATE_INT);
$page = ($page && $page > 0) ? $page : 1;
$perPage = 20;
$where = []; $params = [];
if ($search !== '') {
    $where[] = '(question LIKE ? OR category LIKE ? OR option_a LIKE ? OR option_b LIKE ? OR option_c LIKE ? OR option_d LIKE ?)';
    $like = '%' . $search . '%';
    for ($i=0; $i<6; $i++) $params[] = $like;
}
if ($selectedCategory !== '') { $where[] = 'category=?'; $params[] = $selectedCategory; }
if (in_array($difficulty, ['easy','medium','hard'], true)) { $where[] = 'difficulty=?'; $params[] = $difficulty; }
if (in_array($language, ['Bangla','English','Both'], true)) { $where[] = 'language=?'; $params[] = $language; }
if (in_array($status, ['draft','published'], true)) { $where[] = 'status=?'; $params[] = $status; }
if ($featureSchemaReady) $where[] = 'is_archived=' . ($view === 'archived' ? '1' : '0');
$whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';

$countStmt = $pdo->prepare('SELECT COUNT(*) FROM questions' . $whereSql);
$countStmt->execute($params);
$filteredCount = (int)$countStmt->fetchColumn();
$totalPages = max(1, (int)ceil($filteredCount / $perPage));
$page = min($page, $totalPages);
$offset = ($page - 1) * $perPage;
$listSql = 'SELECT id,category,question,option_a,option_b,option_c,option_d,correct_answer,explanation,difficulty,language,status' . ($featureSchemaReady ? ',image_path,is_archived' : '') . ',(SELECT COUNT(DISTINCT test_id) FROM model_test_questions WHERE question_id=questions.id) AS usage_count FROM questions' . $whereSql . ' ORDER BY id DESC LIMIT ' . $perPage . ' OFFSET ' . $offset;
$listStmt = $pdo->prepare($listSql);
$listStmt->execute($params);
$questions = $listStmt->fetchAll(PDO::FETCH_ASSOC);

$totalQuestions = (int)$pdo->query('SELECT COUNT(*) FROM questions' . ($featureSchemaReady ? ' WHERE is_archived=0' : ''))->fetchColumn();
$archivedCount = $featureSchemaReady ? (int)$pdo->query('SELECT COUNT(*) FROM questions WHERE is_archived=1')->fetchColumn() : 0;
$totalCategories = (int)$pdo->query("SELECT COUNT(DISTINCT category) FROM questions WHERE category IS NOT NULL AND TRIM(category)<>''")->fetchColumn();
$publishedCount = (int)$pdo->query("SELECT COUNT(*) FROM questions WHERE status='published'")->fetchColumn();
$draftCount = (int)$pdo->query("SELECT COUNT(*) FROM questions WHERE status='draft'")->fetchColumn();
$categoryStmt = $pdo->query("SELECT category,COUNT(*) AS question_count FROM questions WHERE category IS NOT NULL AND TRIM(category)<>'' GROUP BY category ORDER BY category ASC");
$categories = $categoryStmt->fetchAll(PDO::FETCH_ASSOC);
$token = csrf_token();
?>
<!doctype html>
<html lang="bn">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>প্রশ্ন ব্যবস্থাপনা | Fire Safety BD</title>
<style>

:root{--maroon:#510d18;--deep:#450b15;--soft:#6a111f;--orange:#ffa400;--bg:#fff8f5;--white:#fff;--ink:#30191b;--muted:#8b7777;--line:#f1ddd6;--green:#176b3b;--red:#b42318;--shadow:0 8px 24px rgba(69,11,21,.05)}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:Arial,"Noto Sans Bengali","SolaimanLipi",sans-serif;line-height:1.55}a{color:inherit}.layout{min-height:100vh;display:flex}.sidebar{width:280px;flex:0 0 280px;background:linear-gradient(180deg,#450b15,#6a111f);color:#f9e9e7;padding:24px 16px;display:flex;flex-direction:column;min-height:100vh}.brand{display:flex;align-items:center;gap:13px;padding:4px 9px 26px;border:0}.brand img{display:block;width:65px;height:65px;object-fit:contain;background:#510d18;border:2px solid #fff;border-radius:13px;padding:2px;margin:0;flex-shrink:0}.brand-name{font-size:20px;font-weight:800;color:#fff;line-height:1.25}.brand-sub{font-size:14px;color:#e0bfc2;margin-top:5px}.nav-title{font-size:11px;color:#bfaab1;text-transform:uppercase;letter-spacing:1px;padding:22px 12px 8px}.nav-list{display:grid;gap:5px}.nav-link{display:flex;align-items:center;gap:13px;padding:13px 15px;margin:0;text-decoration:none;border-radius:14px;color:#f4dfe0;font-size:14px}.nav-link:hover{background:#ffffff12}
.mobile-toggle{display:none}.topline{display:flex;align-items:center;gap:12px}.bulk-toolbar{display:flex;align-items:center;gap:9px;flex-wrap:wrap;padding:12px;background:#fff8f5;border:1px solid var(--line);border-radius:12px;margin-bottom:14px}.bulk-toolbar select{max-width:190px}.select-inline{display:inline-flex;align-items:center;gap:5px;margin:0 0 7px;font-size:12px}.question-preview{margin-top:14px;padding:15px;background:#fff8f5;border:1px solid var(--line);border-radius:12px}.preview-options{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:12px 0}.revision-row{padding:12px;border:1px solid var(--line);border-radius:10px;margin:9px 0}.revision-row summary{cursor:pointer;font-weight:700}.revision-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:12px}.revision-grid pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#fff8f5;padding:12px;border-radius:8px;font-size:12px}.image-current{display:flex;align-items:center;gap:10px;margin-top:8px}.nav-link.active{background:var(--orange);color:#29170b;font-weight:800}.sidebar-bottom{margin-top:auto;padding:18px 12px 0;color:#bfaab1;font-size:12px}
.main{min-width:0;flex:1;padding:32px 32px 45px}.topbar{display:flex;justify-content:space-between;align-items:center;gap:18px;margin-bottom:28px}.eyebrow{font-size:12px;color:var(--muted);margin-bottom:3px}.page-title{font-size:32px;font-weight:900;margin:0 0 8px;color:var(--deep)}.top-actions{display:flex;gap:9px;align-items:center;flex-wrap:wrap}.btn{display:inline-flex;align-items:center;justify-content:center;gap:7px;border:0;border-radius:8px;padding:10px 15px;background:var(--maroon);color:#fff;text-decoration:none;font-size:13px;font-weight:700;cursor:pointer}.btn:hover{background:var(--soft)}.btn.orange{background:var(--orange);color:#35100f}.btn.light{background:#f5edf0;color:var(--maroon)}.btn.danger{background:#fff0f0;color:var(--red);border:1px solid #f3d2d5}.btn.small{padding:7px 10px;font-size:12px}.stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px;margin-bottom:24px}.stat-card,.panel{background:var(--white);border:1px solid var(--line);border-radius:18px;box-shadow:var(--shadow)}.stat-card{padding:20px 18px;display:flex;align-items:center;justify-content:space-between;min-height:126px}.stat-label{font-size:13px;color:var(--muted)}.stat-number{font-size:26px;font-weight:800;color:var(--maroon);margin-top:3px}.stat-icon{width:40px;height:40px;border-radius:12px;background:#fff1df;color:#a65a10;display:grid;place-items:center;font-size:20px}.panel{padding:22px;margin-bottom:20px;border-radius:20px}.panel-head{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:15px}.panel-title{font-size:17px;margin:0;color:var(--deep)}.panel-note{font-size:12px;color:var(--muted)}.alert{padding:12px 15px;border-radius:9px;margin-bottom:18px;font-size:14px}.alert.success{background:#eaf7ef;color:#17633f}.alert.warning{background:#fff7e6;color:#8b5a08}.alert.error{background:#fff0f0;color:#a51d2a}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}.field-full{grid-column:1/-1}label{display:block;font-size:13px;font-weight:700;color:#44363b;margin-bottom:6px}input,select,textarea{width:100%;padding:11px 12px;border:1px solid #ded5d9;border-radius:8px;background:#fff;color:var(--ink);font:inherit;font-size:14px;outline:none}input:focus,select:focus,textarea:focus{border-color:var(--orange);box-shadow:0 0 0 3px #f39a3226}textarea{min-height:76px;resize:vertical}.question-textarea{min-height:95px}.form-actions{display:flex;gap:9px;flex-wrap:wrap;margin-top:16px}.help-text{font-size:12px;color:var(--muted);margin:6px 0 0}.filter-bar{display:grid;grid-template-columns:2fr 1.2fr 1fr 1fr 1fr auto auto;gap:8px;margin-bottom:16px}.question-item{padding:16px 0;border-bottom:1px solid var(--line)}.question-item:last-child{border-bottom:0;padding-bottom:0}.question-head{display:flex;justify-content:space-between;align-items:flex-start;gap:12px}.question-id{font-size:12px;color:var(--muted);font-weight:700}.category-pill,.meta-pill{display:inline-block;background:#fff1df;color:#8a4c0d;padding:4px 9px;border-radius:20px;font-size:11px;font-weight:700;margin:3px 3px 0 0}.meta-pill{background:#f4edf0;color:#65404c}.question-title{font-size:14px;font-weight:700;margin:8px 0;color:#302329;white-space:pre-wrap;overflow-wrap:anywhere}.answer-line{font-size:12px;color:var(--green);font-weight:700}.question-actions{display:flex;gap:7px;align-items:center;flex-wrap:wrap}.inline-form{display:inline}.empty{padding:30px 12px;text-align:center;color:var(--muted)}.pagination{display:flex;align-items:center;justify-content:center;gap:7px;flex-wrap:wrap;margin-top:20px}.page-link{padding:7px 11px;border:1px solid var(--line);border-radius:7px;text-decoration:none;font-size:12px;background:#fff}.page-link.current{background:var(--maroon);color:#fff;border-color:var(--maroon)}.page-link.disabled{opacity:.4;pointer-events:none}.category-list{display:flex;flex-wrap:wrap;gap:8px}.category-chip{background:#f8f1f3;border:1px solid var(--line);border-radius:8px;padding:7px 10px;font-size:12px;text-decoration:none}.category-chip strong{color:var(--maroon);margin-left:5px}.preview-table{width:100%;border-collapse:collapse;font-size:12px}.preview-table th,.preview-table td{border:1px solid var(--line);padding:9px;text-align:left;vertical-align:top}.preview-table th{background:#f8f1f3;color:var(--deep)}.good{color:#17633f;font-weight:700}.bad{color:#a51d2a;font-weight:700}.table-wrap{overflow-x:auto}.import-help{background:#fffaf3;border:1px solid #f4dfc2;padding:12px;border-radius:9px;font-size:12px;color:#684719;margin-bottom:14px}

.tool-panel{padding:0;overflow:hidden}.tool-panel[open]{border-color:#e6d5db}.tool-summary{list-style:none;display:flex;align-items:center;gap:13px;padding:16px 18px;cursor:pointer;min-height:76px}.tool-summary::-webkit-details-marker{display:none}.tool-summary:after{content:'＋';margin-left:8px;color:var(--maroon);font-size:20px;font-weight:700}.tool-panel[open]>.tool-summary:after{content:'−'}.tool-icon{width:42px;height:42px;flex:0 0 42px;border-radius:12px;background:#fff1df;color:#8a4c0d;display:grid;place-items:center;font-size:22px;font-weight:800}.tool-summary-copy{display:flex;flex-direction:column;gap:2px;min-width:0}.tool-summary-copy strong{font-size:15px;color:var(--deep)}.tool-summary-copy small{font-size:12px;color:var(--muted);font-weight:400}.tool-state{margin-left:auto;color:#8a4c0d;background:#fff7ec;border:1px solid #f5e2c8;border-radius:20px;padding:5px 10px;font-size:11px;font-weight:700;white-space:nowrap}.tool-body{padding:0 20px 20px;border-top:1px solid var(--line)}.tool-body>.panel-head{margin-top:18px}.tool-panel[open]>.tool-summary{background:#fffdfb}

@media(max-width:1100px){.filter-bar{grid-template-columns:repeat(3,minmax(0,1fr))}.stats{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:900px){.sidebar{width:230px;flex-basis:230px;padding:20px 12px}.main{padding:22px 18px}.nav-link{font-size:13px;padding:12px 12px}}
@media(max-width:650px){.revision-grid,.preview-options{grid-template-columns:1fr}.bulk-toolbar{align-items:stretch}.bulk-toolbar select{max-width:none;width:100%}.layout{display:block}.sidebar{display:none;width:100%;min-height:auto;padding:14px}.sidebar.open{display:block}.brand{padding-bottom:12px;gap:11px}.brand img{width:54px;height:54px}.brand-name{font-size:17px}.nav-list{grid-template-columns:repeat(2,minmax(0,1fr));gap:6px}.nav-link{font-size:13px;padding:10px}.main{padding:18px 14px 28px;min-width:0}.topbar{align-items:flex-start;flex-direction:column}.topline{display:flex;align-items:center;gap:12px}.mobile-toggle{display:inline-block;border:1px solid var(--line);border-radius:9px;background:#fff;color:var(--deep);padding:8px 11px;font-size:18px;cursor:pointer}.page-title{font-size:27px}.top-actions{width:100%;align-items:stretch;flex-direction:column}.top-actions .btn{width:100%}.stats{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.stat-card{padding:12px;min-height:100px}.stat-number{font-size:22px}.stat-icon{width:34px;height:34px}.panel{padding:16px}.form-grid{grid-template-columns:1fr}.field-full{grid-column:auto}.filter-bar{grid-template-columns:1fr}.question-head{display:block}.question-actions{margin-top:11px}}

</style>
</head>
<body>
<div class="layout">
<aside class="sidebar" id="sidebar">
 <div class="brand">
  <a href="fire_safety_job_prep_dashboard.php" aria-label="Fire Safety BD Dashboard"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo"></a>
  <div><a href="fire_safety_job_prep_dashboard.php"><div class="brand-name">Fire Safety BD</div><div class="brand-sub">অ্যাডমিন প্যানেল</div></a></div>
 </div>
 <nav class="nav-list" aria-label="Admin navigation">
  <a class="nav-link" href="fire_safety_job_prep_dashboard.php"><span class="ico">▦</span> ড্যাশবোর্ড</a>
  <a class="nav-link active" href="questions.php" aria-current="page"><span class="ico">ⓘ</span> প্রশ্ন ব্যাংক</a>
  <a class="nav-link" href="model_tests.php"><span class="ico">☑</span> মডেল টেস্ট</a>
  <a class="nav-link" href="notes.php"><span class="ico">◫</span> নোট</a>
  <a class="nav-link" href="job_circulars.php"><span class="ico">▣</span> চাকরির সার্কুলার</a>
  <a class="nav-link" href="fire_safety_job_prep_dashboard.php?section=marketplace"><span class="ico">🛒</span> মার্কেটপ্লেস</a>
  <a class="nav-link" href="category_management.php"><span class="ico">⊞</span> ক্যাটাগরি</a>
  <a class="nav-link" href="users.php"><span class="ico">♙</span> ব্যবহারকারী</a>
  <a class="nav-link" href="fire_safety_job_prep_dashboard.php?section=community"><span class="ico">▱</span> কমিউনিটি</a>
  <a class="nav-link" href="logout.php"><span class="ico">↪</span> লগ আউট</a>
 </nav>
</aside>
<main class="main">
<header class="topbar"><div class="topline"><button class="mobile-toggle" type="button" onclick="document.getElementById('sidebar').classList.toggle('open')" aria-label="মেনু">☰</button><div><h1 class="page-title">প্রশ্ন ব্যবস্থাপনা</h1><div class="eyebrow">Fire Safety BD — প্রশ্ন ব্যাংক ব্যবস্থাপনা</div></div></div><div class="top-actions"><a class="btn orange" href="#question-form" id="open-question-form">＋ প্রশ্ন যোগ করুন</a></div></header>
<?php if ($message !== ''): ?><div class="alert <?= qh($messageType) ?>"><?= qh($message) ?></div><?php endif; ?>

<section class="stats">
<div class="stat-card"><div><div class="stat-label">সর্বমোট প্রশ্ন</div><div class="stat-number"><?= number_format($totalQuestions) ?></div></div><div class="stat-icon">▤</div></div>
<div class="stat-card"><div><div class="stat-label">মোট ক্যাটাগরি</div><div class="stat-number"><?= number_format($totalCategories) ?></div></div><div class="stat-icon">▦</div></div>
<div class="stat-card"><div><div class="stat-label">Published</div><div class="stat-number"><?= number_format($publishedCount) ?></div></div><div class="stat-icon">✓</div></div>
<div class="stat-card"><div><div class="stat-label">Draft</div><div class="stat-number"><?= number_format($draftCount) ?></div></div><div class="stat-icon">✎</div></div>
</section>
<?php if(!$featureSchemaReady): ?><div class="alert warning">নতুন ফিচার চালু করতে একবার phpMyAdmin-এ <code>backend/migrations/20261119_question_bank_features.sql</code> চালান। পুরোনো প্রশ্ন ও ফিচার নিরাপদ থাকবে।</div><?php endif; ?>
<?php if($featureSchemaReady): ?><section class="panel"><div class="panel-head"><h2 class="panel-title">Archive Management</h2><span class="panel-note">Archived প্রশ্ন: <?= number_format($archivedCount) ?></span><a class="btn light small" href="questions.php?view=<?= $view==='archived'?'active':'archived' ?>"><?= $view==='archived'?'Active প্রশ্ন দেখুন':'Archived প্রশ্ন দেখুন' ?></a></div></section><?php endif; ?>

<details class="panel tool-panel" id="question-form" <?= $editQuestion ? 'open' : '' ?>>
<summary class="tool-summary"><span class="tool-icon">＋</span><span class="tool-summary-copy"><strong><?= $editQuestion ? 'প্রশ্ন সম্পাদনা করুন' : 'ম্যানুয়ালি প্রশ্ন যোগ করুন' ?></strong><small><?= $editQuestion ? 'প্রশ্নের তথ্য পরিবর্তন করুন' : 'একটি করে প্রশ্ন ও চারটি অপশন যোগ করুন' ?></small></span><span class="tool-state"><?= $editQuestion ? 'খোলা' : 'ফর্ম খুলুন' ?></span></summary>
<div class="tool-body"><?php if ($editQuestion): ?><div class="panel-head"><span class="panel-note">প্রশ্ন সম্পাদনা মোড</span><a class="btn light small" href="questions.php">সম্পাদনা বাতিল</a></div><?php endif; ?>
<form method="post" enctype="multipart/form-data" action="questions.php<?= $editQuestion ? '?edit='.(int)$editQuestion['id'] : '' ?>">
<input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<?= qfield($editQuestion,'id') ?>">
<div class="form-grid">
<div><label>ক্যাটাগরি *</label><input name="category" required maxlength="100" list="category-options" value="<?= qfield($editQuestion,'category') ?>" placeholder="যেমন: Fire Safety, NFPA, BNBC"><datalist id="category-options"><?php foreach($categories as $r): ?><option value="<?= qh((string)$r['category']) ?>"><?php endforeach; ?></datalist></div>
<div><label>সঠিক উত্তর *</label><select name="correct_answer" required><?php foreach(['A','B','C','D'] as $letter): ?><option value="<?= $letter ?>" <?= (($editQuestion['correct_answer']??'A')===$letter)?'selected':'' ?>>Option <?= $letter ?></option><?php endforeach; ?></select></div>
<div class="field-full"><label>প্রশ্ন *</label><textarea class="question-textarea" name="question" required><?= qfield($editQuestion,'question') ?></textarea></div>
<div><label>Option A *</label><textarea name="option_a" required><?= qfield($editQuestion,'option_a') ?></textarea></div><div><label>Option B *</label><textarea name="option_b" required><?= qfield($editQuestion,'option_b') ?></textarea></div><div><label>Option C *</label><textarea name="option_c" required><?= qfield($editQuestion,'option_c') ?></textarea></div><div><label>Option D *</label><textarea name="option_d" required><?= qfield($editQuestion,'option_d') ?></textarea></div>
<div><label>Difficulty</label><select name="difficulty"><?php foreach(['easy'=>'Easy','medium'=>'Medium','hard'=>'Hard'] as $v=>$label): ?><option value="<?= $v ?>" <?= (($editQuestion['difficulty']??'medium')===$v)?'selected':'' ?>><?= $label ?></option><?php endforeach; ?></select></div>
<div><label>Language</label><select name="language"><?php foreach(['Bangla','English','Both'] as $v): ?><option value="<?= $v ?>" <?= (($editQuestion['language']??'English')===$v)?'selected':'' ?>><?= $v ?></option><?php endforeach; ?></select></div>
<div><label>Status</label><select name="status"><?php foreach(['published'=>'Published','draft'=>'Draft'] as $v=>$label): ?><option value="<?= $v ?>" <?= (($editQuestion['status']??'published')===$v)?'selected':'' ?>><?= $label ?></option><?php endforeach; ?></select></div>
<div><label>Reference / সূত্র</label><input name="reference" maxlength="255" value="<?= qfield($editQuestion,'reference') ?>" placeholder="যেমন: NFPA 13, Section ..."></div>
<div class="field-full"><label>ব্যাখ্যা (ঐচ্ছিক)</label><textarea name="explanation" placeholder="সঠিক উত্তরটি কেন সঠিক, ব্যাখ্যা লিখুন..."><?= qfield($editQuestion,'explanation') ?></textarea></div>
<div><label>প্রশ্নের ছবি (ঐচ্ছিক · JPG/PNG/WEBP · সর্বোচ্চ ৫ MB)</label><input type="file" name="question_image" accept="image/jpeg,image/png,image/webp"><?php if(!empty($editQuestion['image_path'])): ?><div class="image-current"><img src="<?= qh((string)$editQuestion['image_path']) ?>" alt="Question image" style="max-width:180px;max-height:120px;object-fit:contain"><small>বর্তমান ছবি · নতুন ছবি দিলে পরিবর্তিত হবে</small></div><?php endif; ?></div>
</div>
<div class="form-actions"><button class="btn orange" type="submit"><?= $editQuestion?'পরিবর্তন সংরক্ষণ করুন':'প্রশ্ন যুক্ত করুন' ?></button><?php if($editQuestion): ?><a class="btn light" href="questions.php">বাতিল</a><?php else: ?><button class="btn light" type="reset">ফর্ম পরিষ্কার করুন</button><?php endif; ?></div>
</form>
</div></details>

<details class="panel tool-panel" id="paste-import" <?= (is_array($preview) && (($preview['filename'] ?? '') === 'কপি-পেস্ট করা প্রশ্ন')) ? 'open' : '' ?>>
<summary class="tool-summary"><span class="tool-icon">▤</span><span class="tool-summary-copy"><strong>কপি-পেস্ট করে প্রশ্ন যোগ</strong><small>একসঙ্গে অনেক প্রশ্ন পেস্ট করে Preview ও Import করুন</small></span><span class="tool-state">খুলুন</span></summary>
<div class="tool-body"><div class="import-help"><strong>ফরম্যাট:</strong> প্রতিটি প্রশ্নের আগে <b>প্রশ্ন:</b>, অপশনগুলো <b>A.</b>, <b>B.</b>, <b>C.</b>, <b>D.</b> এবং শেষে <b>সঠিক উত্তর: B</b> লিখুন। বাংলা অপশনের জন্য ক/খ/গ/ঘ-ও গ্রহণযোগ্য। প্রশ্নের মাঝে একটি ফাঁকা লাইন রাখুন।</div>
<form method="post" action="questions.php#paste-import">
<input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="paste_preview">
<div class="form-grid"><div><label>ডিফল্ট ক্যাটাগরি *</label><input name="default_category" maxlength="100" value="General" required placeholder="যেমন: Fire Safety, NFPA, BNBC"></div>
<div class="field-full"><label>প্রশ্নগুলো পেস্ট করুন *</label><textarea name="bulk_questions" required style="min-height:260px" placeholder="প্রশ্ন: আগুন জ্বলতে কোন তিনটি উপাদান প্রয়োজন?&#10;A. পানি, বাতাস ও তাপ&#10;B. জ্বালানি, অক্সিজেন ও তাপ&#10;C. ধোঁয়া, পানি ও অক্সিজেন&#10;D. তাপ, ধোঁয়া ও পানি&#10;সঠিক উত্তর: B&#10;&#10;প্রশ্ন: NFPA 10 কোন বিষয়ের সঙ্গে সম্পর্কিত?&#10;A. Fire Alarm&#10;B. Sprinkler System&#10;C. Portable Fire Extinguishers&#10;D. Standpipe System&#10;সঠিক উত্তর: C"></textarea></div></div>
<div class="form-actions"><button class="btn orange" type="submit">তথ্য সাজান ও Preview দেখুন</button></div>
</form>
</div></details>

<details class="panel tool-panel" id="docx-import" <?= (is_array($preview) && (($preview['filename'] ?? '') !== 'কপি-পেস্ট করা প্রশ্ন')) ? 'open' : '' ?>>
<summary class="tool-summary"><span class="tool-icon">▣</span><span class="tool-summary-copy"><strong>Word ফাইল ইমপোর্ট (DOCX)</strong><small>Word ফাইল আপলোড করে Preview দেখে প্রশ্ন যোগ করুন</small></span><span class="tool-state">খুলুন</span></summary>
<div class="tool-body"><div class="import-help"><strong>সমর্থিত ফরম্যাট:</strong> Word-এর টেবিল (প্রথম কলামে Field, দ্বিতীয় কলামে Value) অথবা লাইনভিত্তিক Question/প্রশ্ন, A./A), Option A, Correct Answer/সঠিক উত্তর, Explanation/ব্যাখ্যা। চারটি অপশন ও সঠিক উত্তর আবশ্যক। সর্বোচ্চ ১০ MB।</div>
<form method="post" enctype="multipart/form-data" action="questions.php#docx-import">
<input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="docx_preview">
<div class="form-grid"><div><label>DOCX ফাইল নির্বাচন করুন *</label><input type="file" name="docx_file" accept=".docx" required></div><div><label>ডিফল্ট ক্যাটাগরি</label><input name="default_category" maxlength="100" value="General" placeholder="টেবিলে ক্যাটাগরি না থাকলে ব্যবহৃত হবে"></div></div>
<div class="form-actions"><button class="btn orange" type="submit">Upload & Preview</button></div>
</form>
<?php if (is_array($preview) && !empty($preview['rows'])):
$validPreview=0; foreach($preview['rows'] as $r){if(empty($r['_errors']) && empty($r['_duplicate']))$validPreview++;}
?>
<div class="panel-head" style="margin-top:22px"><div><h3 class="panel-title">Import Preview</h3><div class="panel-note"><?= qh((string)($preview['filename']??'DOCX')) ?> · মোট <?= count($preview['rows']) ?> · Import করা যাবে <?= $validPreview ?>টি</div></div></div>
<div class="table-wrap"><table class="preview-table"><thead><tr><th>#</th><th>প্রশ্ন ও অপশন</th><th>উত্তর</th><th>যাচাই</th></tr></thead><tbody>
<?php foreach($preview['rows'] as $i=>$r): ?><tr><td><?= $i+1 ?></td><td><strong><?= qh((string)$r['question']) ?></strong><br>A. <?= qh((string)$r['option_a']) ?><br>B. <?= qh((string)$r['option_b']) ?><br>C. <?= qh((string)$r['option_c']) ?><br>D. <?= qh((string)$r['option_d']) ?><br><small><?= qh((string)$r['category']) ?> · <?= qh((string)$r['difficulty']) ?> · <?= qh((string)$r['language']) ?></small></td><td><?= qh((string)$r['correct_answer']) ?></td><td><?php if(!empty($r['_errors'])): ?><span class="bad"><?= qh(implode(', ',$r['_errors'])) ?></span><?php elseif(!empty($r['_duplicate'])): ?><span class="bad">Duplicate: <?= qh((string)$r['_duplicate']) ?></span><?php elseif(!empty($r['_similar'])): ?><span class="warn">Similar to #<?= (int)$r['_similar'][0]['id'] ?> (<?= (int)round($r['_similar'][0]['score']*100) ?>% match)</span><?php else: ?><span class="good">Ready</span><?php endif; ?></td></tr><?php endforeach; ?>
</tbody></table></div>
<div class="form-actions">
<?php if($validPreview>0): ?><form method="post" action="questions.php#docx-import" onsubmit="return confirm('শুধু valid ও duplicate নয় এমন প্রশ্নগুলো ডেটাবেজে যোগ করবেন?');"><input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="docx_import"><button class="btn orange" type="submit">Import <?= $validPreview ?>টি প্রশ্ন</button></form><?php endif; ?>
<form method="post" action="questions.php#docx-import"><input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="clear_preview"><button class="btn light" type="submit">Preview বাতিল</button></form>
</div>
<?php endif; ?>
</div></details>

<?php if($categories): ?><section class="panel"><div class="panel-head"><h2 class="panel-title">ক্যাটাগরি অনুযায়ী প্রশ্ন</h2><span class="panel-note">প্রতিটি ক্যাটাগরিতে প্রশ্নের সংখ্যা</span></div><div class="category-list"><?php foreach($categories as $r): ?><a class="category-chip" href="<?= qh(question_page_url(1,'',(string)$r['category'],'','','')) ?>"><?= qh((string)$r['category']) ?> <strong><?= number_format((int)$r['question_count']) ?></strong></a><?php endforeach; ?></div></section><?php endif; ?>

<?php if($historyId && $featureSchemaReady): ?><section class="panel"><div class="panel-head"><h2 class="panel-title">প্রশ্ন #<?= (int)$historyId ?> · Revision History</h2><a class="btn light small" href="questions.php">বন্ধ করুন</a></div><?php if(!$historyRows): ?><div class="empty">এই প্রশ্নের কোনো Revision History পাওয়া যায়নি।</div><?php else: foreach($historyRows as $rev): ?><details class="revision-row"><summary><?= qh((string)$rev['event_type']) ?> · <?= qh((string)$rev['changed_by']) ?> · <?= qh((string)$rev['created_at']) ?></summary><div class="revision-grid"><?php if($rev['before_data']): ?><div><b>আগের তথ্য</b><pre><?= qh((string)$rev['before_data']) ?></pre></div><?php endif; ?><?php if($rev['after_data']): ?><div><b>পরের তথ্য</b><pre><?= qh((string)$rev['after_data']) ?></pre></div><?php endif; ?></div></details><?php endforeach; endif; ?></section><?php endif; ?>

<section class="panel">
<div class="panel-head"><div><h2 class="panel-title">প্রশ্ন ব্যাংক <?= $view==='archived'?'· Archive':' ' ?></h2><div class="panel-note">মোট <?= number_format($filteredCount) ?>টি ফলাফল · প্রতি পেজে <?= $perPage ?>টি</div></div></div>
<?php if($featureSchemaReady && $view==='active'): ?><form id="bulk-questions-form" method="post" action="questions.php"><input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="bulk_action"><div class="bulk-toolbar"><strong>নির্বাচিত প্রশ্নে:</strong><select name="bulk_operation" required><option value="">Action নির্বাচন</option><option value="publish">Publish</option><option value="draft">Draft</option><option value="archive">Archive</option><option value="delete">Delete</option></select><button class="btn orange small" type="submit" onclick="return confirm('নির্বাচিত প্রশ্নগুলোর উপর Bulk Action চালাবেন?')">Apply</button><button class="btn light small" type="button" onclick="document.querySelectorAll('.question-select').forEach(x=>x.checked=true)">সব নির্বাচন</button><button class="btn light small" type="button" onclick="document.querySelectorAll('.question-select').forEach(x=>x.checked=false)">নির্বাচন বাতিল</button></div></form><?php endif; ?>
<form class="filter-bar" method="get" action="questions.php">
<input type="search" name="q" value="<?= qh($search) ?>" placeholder="প্রশ্ন/অপশন দিয়ে খুঁজুন">
<select name="category"><option value="">সব ক্যাটাগরি</option><?php foreach($categories as $r): ?><option value="<?= qh((string)$r['category']) ?>" <?= $selectedCategory===(string)$r['category']?'selected':'' ?>><?= qh((string)$r['category']) ?></option><?php endforeach; ?></select>
<select name="difficulty"><option value="">সব Difficulty</option><option value="easy" <?= $difficulty==='easy'?'selected':'' ?>>Easy</option><option value="medium" <?= $difficulty==='medium'?'selected':'' ?>>Medium</option><option value="hard" <?= $difficulty==='hard'?'selected':'' ?>>Hard</option></select>
<select name="language"><option value="">সব Language</option><?php foreach(['Bangla','English','Both'] as $v): ?><option value="<?= $v ?>" <?= $language===$v?'selected':'' ?>><?= $v ?></option><?php endforeach; ?></select>
<select name="status"><option value="">সব Status</option><option value="published" <?= $status==='published'?'selected':'' ?>>Published</option><option value="draft" <?= $status==='draft'?'selected':'' ?>>Draft</option></select>
<button class="btn" type="submit">Filter</button><a class="btn light" href="questions.php">Reset</a>
</form>
<?php if(!$questions): ?><div class="empty"><strong>কোনো প্রশ্ন পাওয়া যায়নি।</strong><div>সার্চ বা ফিল্টার পরিবর্তন করে আবার চেষ্টা করুন।</div></div>
<?php else: foreach($questions as $q): ?>
<article class="question-item"><div class="question-head"><div><?php if($featureSchemaReady && $view==='active'): ?><label class="select-inline"><input class="question-select" type="checkbox" name="selected_ids[]" value="<?= (int)$q['id'] ?>" form="bulk-questions-form"> নির্বাচন</label><?php endif; ?><div class="question-id">প্রশ্ন #<?= (int)$q['id'] ?></div><span class="category-pill"><?= qh((string)$q['category']) ?></span><span class="meta-pill"><?= qh(ucfirst((string)$q['difficulty'])) ?></span><span class="meta-pill"><?= qh((string)$q['language']) ?></span><span class="meta-pill"><?= qh(ucfirst((string)$q['status'])) ?></span><span class="meta-pill">ব্যবহার: <?= (int)$q['usage_count'] ?>টি টেস্ট</span></div><div class="question-actions"><a class="btn small" href="questions.php?edit=<?= (int)$q['id'] ?>#question-form">সম্পাদনা</a><button class="btn light small" type="button" onclick="document.getElementById('preview-<?= (int)$q['id'] ?>').hidden=!document.getElementById('preview-<?= (int)$q['id'] ?>').hidden">Preview</button><a class="btn light small" href="questions.php?history=<?= (int)$q['id'] ?>">History</a>
<?php if($featureSchemaReady): ?><form class="inline-form" method="post" action="questions.php"><input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="id" value="<?= (int)$q['id'] ?>"><input type="hidden" name="action" value="<?= $view==='archived'?'restore':'archive' ?>"><button class="btn small" type="submit"><?= $view==='archived'?'Restore':'Archive' ?></button></form><?php endif; ?>
<form class="inline-form" method="post" action="questions.php" onsubmit="return confirm('আপনি কি নিশ্চিতভাবে এই প্রশ্নটি মুছে ফেলতে চান?');"><input type="hidden" name="csrf_token" value="<?= qh($token) ?>"><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$q['id'] ?>"><button class="btn danger small" type="submit">মুছুন</button></form></div></div><div class="question-title"><?= qh((string)$q['question']) ?></div><div class="answer-line">সঠিক উত্তর: Option <?= qh((string)$q['correct_answer']) ?></div>
<div class="question-preview" id="preview-<?= (int)$q['id'] ?>" hidden><?php if(!empty($q['image_path'])): ?><img src="<?= qh((string)$q['image_path']) ?>" alt="Question image" style="max-width:260px;max-height:180px;object-fit:contain"><?php endif; ?><div class="preview-options"><div>A. <?= qh((string)$q['option_a']) ?></div><div>B. <?= qh((string)$q['option_b']) ?></div><div>C. <?= qh((string)$q['option_c']) ?></div><div>D. <?= qh((string)$q['option_d']) ?></div></div><strong>সঠিক উত্তর: <?= qh((string)$q['correct_answer']) ?></strong><?php if(!empty($q['explanation'])): ?><p><b>ব্যাখ্যা:</b> <?= nl2br(qh((string)$q['explanation'])) ?></p><?php endif; ?></div></article>
<?php endforeach; ?>
<?php if($totalPages>1): ?><nav class="pagination" aria-label="Question pages"><a class="page-link <?= $page<=1?'disabled':'' ?>" href="<?= qh(question_page_url(max(1,$page-1),$search,$selectedCategory,$difficulty,$language,$status)) ?>">‹ আগের</a><?php $start=max(1,$page-2);$end=min($totalPages,$page+2);for($p=$start;$p<=$end;$p++): ?><a class="page-link <?= $p===$page?'current':'' ?>" href="<?= qh(question_page_url($p,$search,$selectedCategory,$difficulty,$language,$status)) ?>"><?= $p ?></a><?php endfor; ?><a class="page-link <?= $page>=$totalPages?'disabled':'' ?>" href="<?= qh(question_page_url(min($totalPages,$page+1),$search,$selectedCategory,$difficulty,$language,$status)) ?>">পরের ›</a></nav><?php endif; endif; ?>
</section>
</main></div>
<script>
document.querySelectorAll('.tool-panel').forEach(panel=>{
  panel.addEventListener('toggle',()=>{
    if(panel.open) document.querySelectorAll('.tool-panel').forEach(other=>{if(other!==panel) other.open=false;});
  });
});
function openPanelFromHash(){
  const id=decodeURIComponent(location.hash.replace('#',''));
  const target=document.getElementById(id);
  if(target && target.classList.contains('tool-panel')) target.open=true;
}
window.addEventListener('hashchange',openPanelFromHash);
openPanelFromHash();
</script>
</body></html>
