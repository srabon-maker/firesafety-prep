<?php
declare(strict_types=1);

/**
 * Standalone jobs publisher. Configure FIRE_SAFETY_JOBS_ADMIN_PASSWORD_HASH
 * in the web server environment; NEVER commit or hardcode a password.
 * Deploy only behind HTTPS and preferably additional server/IP restrictions.
 */
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store');

$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
if (!$isHttps && ($_SERVER['REMOTE_ADDR'] ?? '') !== '127.0.0.1') {
    http_response_code(403);
    exit('HTTPS is required for job administration.');
}

session_name('fsbd_jobs_admin');
session_set_cookie_params([
    'lifetime' => 0, 'path' => '/admin', 'secure' => $isHttps,
    'httponly' => true, 'samesite' => 'Strict',
]);
session_start();

function e($value): string {
    return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
function fail(string $message): void {
    http_response_code(422);
    throw new InvalidArgumentException($message);
}
function requiredText(string $key, int $max): string {
    $value = trim((string) ($_POST[$key] ?? ''));
    if ($value === '' || mb_strlen($value) > $max) fail('Invalid ' . $key);
    return $value;
}
function optionalText(string $key, int $max): string {
    $value = trim((string) ($_POST[$key] ?? ''));
    if (mb_strlen($value) > $max) fail('Invalid ' . $key);
    return $value;
}
function secureUrl(string $key): ?string {
    $url = optionalText($key, 2048);
    if ($url === '') return null;
    $parts = parse_url($url);
    if ($parts === false || strtolower($parts['scheme'] ?? '') !== 'https' ||
        empty($parts['host']) || isset($parts['user']) || isset($parts['pass'])) {
        fail('Only public HTTPS URLs are allowed for ' . $key);
    }
    return $url;
}
function dateOrNull(string $key): ?string {
    $value = trim((string) ($_POST[$key] ?? ''));
    if ($value === '') return null;
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    if (!$date || $date->format('Y-m-d') !== $value) fail('Invalid date.');
    return $value;
}

$hash = getenv('FIRE_SAFETY_JOBS_ADMIN_PASSWORD_HASH') ?: '';
if ($hash === '') {
    http_response_code(503);
    exit('Jobs admin is not configured. Set FIRE_SAFETY_JOBS_ADMIN_PASSWORD_HASH.');
}
$_SESSION['csrf'] ??= bin2hex(random_bytes(32));
$error = '';
$notice = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (!hash_equals($_SESSION['csrf'], (string) ($_POST['csrf'] ?? ''))) {
            fail('Invalid CSRF token. Refresh and try again.');
        }
        $action = (string) ($_POST['action'] ?? '');
        if ($action === 'login') {
            $blockedUntil = (int) ($_SESSION['blocked_until'] ?? 0);
            if ($blockedUntil > time()) fail('Too many attempts. Try later.');
            if (!password_verify((string) ($_POST['password'] ?? ''), $hash)) {
                $_SESSION['failures'] = (int) ($_SESSION['failures'] ?? 0) + 1;
                if ($_SESSION['failures'] >= 5) {
                    $_SESSION['blocked_until'] = time() + 900;
                    $_SESSION['failures'] = 0;
                }
                fail('Incorrect password.');
            }
            session_regenerate_id(true);
            $_SESSION['authenticated'] = true;
            $_SESSION['failures'] = 0;
            $_SESSION['csrf'] = bin2hex(random_bytes(32));
            header('Location: jobs.php');
            exit;
        }
        if (empty($_SESSION['authenticated'])) fail('Please log in.');
        if ($action === 'logout') {
            $_SESSION = [];
            session_destroy();
            header('Location: jobs.php');
            exit;
        }
        if ($action === 'save') {
            require_once __DIR__ . '/../db.php';
            if (!isset($pdo) || !$pdo instanceof PDO) {
                throw new RuntimeException('PDO database connection unavailable.');
            }
            $id = filter_var($_POST['id'] ?? '0', FILTER_VALIDATE_INT);
            $id = $id && $id > 0 ? $id : 0;
            $jobType = (string) ($_POST['job_type'] ?? '');
            $status = (string) ($_POST['status'] ?? '');
            if (!in_array($jobType, ['government', 'private'], true) ||
                !in_array($status, ['draft', 'published', 'archived'], true)) {
                fail('Invalid job type or status.');
            }
            $fields = [
                'organization' => requiredText('organization', 200),
                'title' => requiredText('title', 250),
                'job_type' => $jobType,
                'employment_type' => optionalText('employment_type', 100),
                'location' => optionalText('location', 200),
                'salary' => optionalText('salary', 150),
                'description' => optionalText('description', 30000),
                'requirements' => optionalText('requirements', 30000),
                'application_deadline' => dateOrNull('application_deadline'),
                'apply_url' => secureUrl('apply_url'),
                'circular_url' => secureUrl('circular_url'),
                'status' => $status,
            ];
            if ($id > 0) {
                $assignments = implode(', ', array_map(
                    static fn(string $key): string => "`$key` = :$key",
                    array_keys($fields)
                ));
                $statement = $pdo->prepare(
                    "UPDATE job_circulars SET $assignments WHERE id = :id"
                );
                $fields['id'] = $id;
                $statement->execute($fields);
            } else {
                $names = array_keys($fields);
                $columns = implode(', ', array_map(
                    static fn(string $key): string => "`$key`",
                    $names
                ));
                $params = implode(', ', array_map(
                    static fn(string $key): string => ":$key",
                    $names
                ));
                $statement = $pdo->prepare(
                    "INSERT INTO job_circulars ($columns) VALUES ($params)"
                );
                $statement->execute($fields);
            }
            header('Location: jobs.php?saved=1');
            exit;
        }
        fail('Unsupported action.');
    } catch (Throwable $exception) {
        $error = $exception instanceof InvalidArgumentException
            ? $exception->getMessage()
            : 'Operation failed. Check server logs.';
        if (!$exception instanceof InvalidArgumentException) {
            error_log('Jobs admin error: ' . $exception->getMessage());
        }
    }
}

$authenticated = !empty($_SESSION['authenticated']);
$rows = [];
$editing = null;
if ($authenticated) {
    try {
        require_once __DIR__ . '/../db.php';
        if (!isset($pdo) || !$pdo instanceof PDO) {
            throw new RuntimeException('PDO database connection unavailable.');
        }
        $rows = $pdo->query(
            'SELECT id, organization, title, job_type, application_deadline, status
             FROM job_circulars ORDER BY id DESC LIMIT 200'
        )->fetchAll(PDO::FETCH_ASSOC);
        $editId = filter_var($_GET['edit'] ?? '0', FILTER_VALIDATE_INT);
        if ($editId && $editId > 0) {
            $statement = $pdo->prepare('SELECT * FROM job_circulars WHERE id = ?');
            $statement->execute([$editId]);
            $editing = $statement->fetch(PDO::FETCH_ASSOC) ?: null;
        }
        if (isset($_GET['saved'])) $notice = 'Circular saved successfully.';
    } catch (Throwable $exception) {
        error_log('Jobs admin listing error: ' . $exception->getMessage());
        $error = 'Could not load job circulars. Verify database setup.';
    }
}
function fieldValue(?array $row, string $key): string {
    return e($row[$key] ?? '');
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fire Safety BD — Jobs Admin</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#faf6f7;color:#2c1b1f;font:15px system-ui,-apple-system,sans-serif}
header{background:#36060d;color:#fff;padding:20px}header h1{margin:0;font-size:22px}
main{max-width:1000px;margin:24px auto;padding:0 16px}
section{background:white;border:1px solid #e8d9dc;border-radius:16px;padding:20px;margin-bottom:20px}
h2{margin-top:0}label{display:block;margin:12px 0 5px;font-weight:650}
input,textarea,select{width:100%;padding:10px;border:1px solid #bca9ad;border-radius:8px;font:inherit}
textarea{min-height:95px}button,.btn{background:#650d18;color:#fff;border:0;border-radius:8px;padding:10px 18px;cursor:pointer;text-decoration:none;display:inline-block}
.btn.secondary{background:#eee4e6;color:#36060d}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:0 16px}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:10px;border-bottom:1px solid #eee}
.tablewrap{overflow-x:auto}.notice{color:#216c47}.error{color:#a20e20}
nav{display:flex;justify-content:space-between;align-items:center;gap:12px}
</style>
</head>
<body>
<header><h1>Fire Safety BD — Job Circular Management</h1></header>
<main>
<?php if ($error !== ''): ?><p class="error"><?= e($error) ?></p><?php endif; ?>
<?php if ($notice !== ''): ?><p class="notice"><?= e($notice) ?></p><?php endif; ?>
<?php if (!$authenticated): ?>
<section>
<h2>Admin sign in</h2>
<form method="post">
<input type="hidden" name="csrf" value="<?= e($_SESSION['csrf']) ?>">
<input type="hidden" name="action" value="login">
<label for="password">Admin password</label>
<input id="password" type="password" name="password" required autocomplete="current-password">
<p><button type="submit">Sign in</button></p>
</form>
</section>
<?php else: ?>
<nav><h2>Manage job circulars</h2>
<form method="post">
<input type="hidden" name="csrf" value="<?= e($_SESSION['csrf']) ?>">
<input type="hidden" name="action" value="logout">
<button type="submit">Sign out</button>
</form></nav>
<section>
<h2><?= $editing ? 'Edit circular #' . (int) $editing['id'] : 'Create a circular' ?></h2>
<form method="post">
<input type="hidden" name="csrf" value="<?= e($_SESSION['csrf']) ?>">
<input type="hidden" name="action" value="save">
<input type="hidden" name="id" value="<?= e($editing['id'] ?? 0) ?>">
<div class="grid">
<div><label>Organization *</label><input name="organization" required maxlength="200" value="<?= fieldValue($editing, 'organization') ?>"></div>
<div><label>Job title *</label><input name="title" required maxlength="250" value="<?= fieldValue($editing, 'title') ?>"></div>
<div><label>Sector *</label><select name="job_type">
<option value="private" <?= ($editing['job_type'] ?? 'private') === 'private' ? 'selected' : '' ?>>Private</option>
<option value="government" <?= ($editing['job_type'] ?? '') === 'government' ? 'selected' : '' ?>>Government</option>
</select></div>
<div><label>Employment type</label><input name="employment_type" maxlength="100" value="<?= fieldValue($editing, 'employment_type') ?>"></div>
<div><label>Location</label><input name="location" maxlength="200" value="<?= fieldValue($editing, 'location') ?>"></div>
<div><label>Salary</label><input name="salary" maxlength="150" value="<?= fieldValue($editing, 'salary') ?>"></div>
<div><label>Application deadline</label><input type="date" name="application_deadline" value="<?= fieldValue($editing, 'application_deadline') ?>"></div>
<div><label>Status</label><select name="status">
<?php foreach (['draft', 'published', 'archived'] as $status): ?>
<option value="<?= e($status) ?>" <?= ($editing['status'] ?? 'draft') === $status ? 'selected' : '' ?>><?= ucfirst($status) ?></option>
<?php endforeach; ?>
</select></div>
</div>
<label>Job description</label><textarea name="description"><?= fieldValue($editing, 'description') ?></textarea>
<label>Requirements</label><textarea name="requirements"><?= fieldValue($editing, 'requirements') ?></textarea>
<label>Official apply URL (HTTPS)</label><input type="url" name="apply_url" maxlength="2048" value="<?= fieldValue($editing, 'apply_url') ?>">
<label>Official circular URL (HTTPS)</label><input type="url" name="circular_url" maxlength="2048" value="<?= fieldValue($editing, 'circular_url') ?>">
<p><button type="submit">Save circular</button>
<a class="btn secondary" href="jobs.php">New circular</a></p>
</form>
</section>
<section>
<h2>Recent circulars</h2>
<div class="tablewrap"><table>
<thead><tr><th>ID</th><th>Organization</th><th>Title</th><th>Deadline</th><th>Status</th><th></th></tr></thead>
<tbody>
<?php foreach ($rows as $row): ?>
<tr><td><?= e($row['id']) ?></td><td><?= e($row['organization']) ?></td>
<td><?= e($row['title']) ?></td><td><?= e($row['application_deadline']) ?></td>
<td><?= e($row['status']) ?></td><td><a href="?edit=<?= (int) $row['id'] ?>">Edit</a></td></tr>
<?php endforeach; ?>
</tbody></table></div>
<?php if (!$rows): ?><p>No circulars yet. Create one above.</p><?php endif; ?>
</section>
<?php endif; ?>
</main></body></html>
