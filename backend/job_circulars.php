<?php
declare(strict_types=1);

// Matches the existing Fire Safety BD dashboard authentication and database.
require_once __DIR__ . '/admin_helpers.php';
start_secure_session();
require_admin();
require_once __DIR__ . '/db.php';

if (!isset($pdo) || !($pdo instanceof PDO)) {
    http_response_code(500);
    exit('ডাটাবেজ সংযোগ পাওয়া যাচ্ছে না।');
}
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

function job_h(mixed $value): string {
    return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
function job_text(string $key, int $max, bool $required = false): string {
    $value = trim((string) ($_POST[$key] ?? ''));
    $length = function_exists('mb_strlen')
        ? mb_strlen($value, 'UTF-8')
        : (preg_match_all('/./us', $value) ?: 0);
    if (($required && $value === '') || $length > $max) {
        throw new InvalidArgumentException('সঠিক তথ্য দিন: ' . $key);
    }
    return $value;
}
function job_date(string $key): ?string {
    $value = job_text($key, 10);
    if ($value === '') return null;
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    if (!$date || $date->format('Y-m-d') !== $value) {
        throw new InvalidArgumentException('আবেদনের শেষ তারিখ সঠিক নয়।');
    }
    return $value;
}
function job_https_url(string $key): ?string {
    $value = job_text($key, 2048);
    if ($value === '') return null;
    $parts = parse_url($value);
    if ($parts === false || strtolower($parts['scheme'] ?? '') !== 'https' ||
        empty($parts['host']) || isset($parts['user']) || isset($parts['pass'])) {
        throw new InvalidArgumentException('শুধু HTTPS আবেদনের লিংক দিন।');
    }
    return $value;
}

$error = '';
$token = csrf_token();
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    verify_csrf();
    try {
        if (($_POST['action'] ?? '') !== 'save') {
            throw new InvalidArgumentException('অবৈধ অনুরোধ।');
        }
        $rawId = trim((string) ($_POST['id'] ?? ''));
        $id = $rawId === '' ? null : filter_var(
            $rawId, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]
        );
        if ($id === false) throw new InvalidArgumentException('সঠিক আইডি দিন।');

        $status = job_text('status', 20, true);
        if (!in_array($status, ['draft', 'published', 'archived'], true)) {
            throw new InvalidArgumentException('অবৈধ প্রকাশনা অবস্থা।');
        }
        $rawCategory = trim((string) ($_POST['category_id'] ?? ''));
        $categoryId = $rawCategory === '' ? null : filter_var(
            $rawCategory, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]
        );
        if ($categoryId === false) {
            throw new InvalidArgumentException('সঠিক ক্যাটাগরি দিন।');
        }
        if ($categoryId !== null) {
            $categoryCheck = $pdo->prepare(
                "SELECT COUNT(*) FROM categories WHERE id = ? AND category_type = 'job'"
            );
            $categoryCheck->execute([$categoryId]);
            if (!(int) $categoryCheck->fetchColumn()) {
                throw new InvalidArgumentException('সঠিক চাকরির ক্যাটাগরি নির্বাচন করুন।');
            }
        }

        $fields = [
            'category_id' => $categoryId,
            'title' => job_text('title', 255, true),
            'organization' => job_text('organization', 200),
            'location' => job_text('location', 200),
            'employment_type' => job_text('employment_type', 100),
            'salary' => job_text('salary', 120),
            'vacancies' => job_text('vacancies', 80),
            'description' => job_text('description', 60000, true),
            'requirements' => job_text('requirements', 60000),
            'application_url' => job_https_url('application_url'),
            'application_deadline' => job_date('application_deadline'),
            'status' => $status,
            'is_pinned' => isset($_POST['is_pinned']) ? 1 : 0,
        ];

        if ($id !== null) {
            $assignments = implode(', ', array_map(
                static fn(string $name): string => "`$name` = :$name",
                array_keys($fields)
            ));
            $statement = $pdo->prepare(
                "UPDATE job_circulars SET $assignments,
                 published_at = CASE
                   WHEN :publish_status = 'published' AND published_at IS NULL
                   THEN NOW() ELSE published_at END
                 WHERE id = :job_id"
            );
            foreach ($fields as $key => $value) {
                $statement->bindValue(
                    ':' . $key, $value,
                    $value === null ? PDO::PARAM_NULL :
                        (is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR)
                );
            }
            $statement->bindValue(':publish_status', $status);
            $statement->bindValue(':job_id', $id, PDO::PARAM_INT);
            $statement->execute();
        } else {
            $names = array_keys($fields);
            $columns = implode(', ', array_map(
                static fn(string $name): string => "`$name`", $names
            ));
            $params = implode(', ', array_map(
                static fn(string $name): string => ":$name", $names
            ));
            $statement = $pdo->prepare(
                "INSERT INTO job_circulars ($columns, published_at)
                 VALUES ($params, CASE WHEN :publish_status = 'published'
                 THEN NOW() ELSE NULL END)"
            );
            foreach ($fields as $key => $value) {
                $statement->bindValue(
                    ':' . $key, $value,
                    $value === null ? PDO::PARAM_NULL :
                        (is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR)
                );
            }
            $statement->bindValue(':publish_status', $status);
            $statement->execute();
        }
        header('Location: job_circulars.php?saved=1');
        exit;
    } catch (InvalidArgumentException $exception) {
        $error = $exception->getMessage();
    } catch (Throwable $exception) {
        error_log('Job circular admin save: ' . $exception->getMessage());
        $error = 'সংরক্ষণ করা যায়নি। সার্ভার লগ পরীক্ষা করুন।';
    }
}

$categories = $pdo->query(
    "SELECT id, name FROM categories
     WHERE category_type = 'job' ORDER BY sort_order, name"
)->fetchAll(PDO::FETCH_ASSOC);
$rows = $pdo->query(
    'SELECT id, title, organization, application_deadline, status, is_pinned
     FROM job_circulars ORDER BY id DESC LIMIT 200'
)->fetchAll(PDO::FETCH_ASSOC);
$edit = null;
$editId = filter_var(
    $_GET['edit'] ?? null, FILTER_VALIDATE_INT,
    ['options' => ['min_range' => 1]]
);
if ($editId !== false && $editId !== null) {
    $statement = $pdo->prepare('SELECT * FROM job_circulars WHERE id = ?');
    $statement->execute([$editId]);
    $edit = $statement->fetch(PDO::FETCH_ASSOC) ?: null;
}
function job_field(?array $row, string $key): string {
    return job_h($row[$key] ?? '');
}
?>
<!doctype html><html lang="bn"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>চাকরির সার্কুলার | Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f8f4f5;color:#281b1e;font:15px Arial,sans-serif}
header{background:#36060d;color:#fff;padding:20px}header a{color:#fff}
main{max-width:1100px;margin:20px auto;padding:0 16px}
section{background:white;padding:20px;border:1px solid #eadbdf;border-radius:16px;margin-bottom:18px}
h1{font-size:22px;margin:0}h2{font-size:19px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:0 14px}
label{display:block;font-weight:650;margin:12px 0 5px}
input,select,textarea{width:100%;padding:10px;border:1px solid #c9b9bd;border-radius:8px;font:inherit}
textarea{min-height:115px}button,.button{background:#650d18;color:white;border:0;border-radius:8px;padding:11px 17px;cursor:pointer}
.button{text-decoration:none;display:inline-block}.error{color:#a51020}
table{width:100%;border-collapse:collapse}td,th{padding:10px;border-bottom:1px solid #eee;text-align:left}
.scroll{overflow-x:auto}
</style></head><body>
<header><h1>Fire Safety BD — চাকরির সার্কুলার</h1>
<p><a href="fire_safety_job_prep_dashboard.php">← Dashboard</a></p></header>
<main>
<?php if ($error !== ''): ?><p class="error"><?= job_h($error) ?></p><?php endif; ?>
<?php if (isset($_GET['saved'])): ?><p>সার্কুলার সংরক্ষিত হয়েছে।</p><?php endif; ?>
<section><h2><?= $edit ? 'সার্কুলার সম্পাদনা' : 'নতুন সার্কুলার' ?></h2>
<form method="post">
<input type="hidden" name="csrf_token" value="<?= job_h($token) ?>">
<input type="hidden" name="action" value="save">
<input type="hidden" name="id" value="<?= job_field($edit,'id') ?>">
<div class="grid">
<div><label>পদের নাম *</label><input name="title" required maxlength="255" value="<?= job_field($edit,'title') ?>"></div>
<div><label>প্রতিষ্ঠান</label><input name="organization" maxlength="200" value="<?= job_field($edit,'organization') ?>"></div>
<div><label>ক্যাটাগরি</label><select name="category_id"><option value="">ক্যাটাগরি নেই</option>
<?php foreach ($categories as $category): ?>
<option value="<?= (int)$category['id'] ?>" <?= (string)($edit['category_id'] ?? '') === (string)$category['id'] ? 'selected' : '' ?>><?= job_h($category['name']) ?></option>
<?php endforeach; ?></select></div>
<div><label>লোকেশন</label><input name="location" maxlength="200" value="<?= job_field($edit,'location') ?>"></div>
<div><label>চাকরির ধরন</label><input name="employment_type" maxlength="100" value="<?= job_field($edit,'employment_type') ?>"></div>
<div><label>বেতন</label><input name="salary" maxlength="120" value="<?= job_field($edit,'salary') ?>"></div>
<div><label>পদসংখ্যা</label><input name="vacancies" maxlength="80" value="<?= job_field($edit,'vacancies') ?>"></div>
<div><label>আবেদনের শেষ তারিখ</label><input name="application_deadline" type="date" value="<?= job_field($edit,'application_deadline') ?>"></div>
<div><label>অবস্থা</label><select name="status">
<?php foreach (['draft','published','archived'] as $status): ?>
<option value="<?= job_h($status) ?>" <?= ($edit['status'] ?? 'draft') === $status ? 'selected' : '' ?>><?= job_h($status) ?></option>
<?php endforeach; ?></select></div>
</div>
<label>চাকরির বিবরণ *</label><textarea name="description" required><?= job_field($edit,'description') ?></textarea>
<label>যোগ্যতা</label><textarea name="requirements"><?= job_field($edit,'requirements') ?></textarea>
<label>আবেদনের লিংক (HTTPS)</label><input name="application_url" type="url" maxlength="2048" value="<?= job_field($edit,'application_url') ?>">
<p><label><input type="checkbox" name="is_pinned" value="1" style="width:auto" <?= (int)($edit['is_pinned'] ?? 0) === 1 ? 'checked' : '' ?>> পিন করা সার্কুলার</label></p>
<p><button type="submit">সংরক্ষণ করুন</button> <a class="button" href="job_circulars.php">নতুন সার্কুলার</a></p>
</form></section>
<section><h2>সাম্প্রতিক সার্কুলার</h2><div class="scroll"><table>
<thead><tr><th>ID</th><th>পদ</th><th>প্রতিষ্ঠান</th><th>শেষ তারিখ</th><th>অবস্থা</th><th></th></tr></thead>
<tbody>
<?php foreach ($rows as $row): ?>
<tr><td><?= (int)$row['id'] ?></td><td><?= job_h($row['title']) ?><?= (int)$row['is_pinned'] ? ' 📌' : '' ?></td>
<td><?= job_h($row['organization']) ?></td><td><?= job_h($row['application_deadline']) ?></td>
<td><?= job_h($row['status']) ?></td><td><a href="?edit=<?= (int)$row['id'] ?>">Edit</a></td></tr>
<?php endforeach; ?>
</tbody></table></div></section></main></body></html>
