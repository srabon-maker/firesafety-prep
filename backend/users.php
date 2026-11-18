<?php
declare(strict_types=1);
require_once __DIR__ . '/admin_helpers.php';
start_secure_session();
require_admin();
require_once __DIR__ . '/db.php';
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');

function users_h(mixed $value): string {
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
function users_identifier(string $name): string {
    return '`' . str_replace('`', '``', $name) . '`';
}

$error = '';
$rows = [];
$total = 0;
$page = max(1, min(10000, (int)($_GET['page'] ?? 1)));
$perPage = 25;
$search = trim((string)($_GET['q'] ?? ''));
$search = function_exists('mb_substr') ? mb_substr($search, 0, 80, 'UTF-8') : substr($search, 0, 80);
$labels = [
    'id'=>'আইডি', 'full_name'=>'নাম', 'email'=>'ইমেইল',
    'mobile_number'=>'মোবাইল', 'phone'=>'ফোন',
    'current_status'=>'বর্তমান অবস্থা', 'company_name'=>'প্রতিষ্ঠান',
    'designation'=>'পদবি', 'job_location'=>'কর্মস্থল',
    'created_at'=>'নিবন্ধনের তারিখ', 'updated_at'=>'সর্বশেষ আপডেট'
];
$columns = [];
try {
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    // Only explicitly approved, non-secret columns are displayed.
    $available = $pdo->query('SHOW COLUMNS FROM users')->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('id', $available, true)) throw new RuntimeException('Missing user ID');
    foreach ($labels as $column => $label) {
        if (in_array($column, $available, true)) $columns[] = $column;
    }
    $searchColumns = array_values(array_intersect(['full_name', 'email', 'mobile_number', 'phone'], $available));
    $where = '';
    $params = [];
    if ($search !== '' && $searchColumns) {
        $where = ' WHERE ' . implode(' OR ', array_map(
            static fn(string $c): string => users_identifier($c) . ' LIKE :q',
            $searchColumns
        ));
        $params[':q'] = '%' . $search . '%';
    }
    $count = $pdo->prepare('SELECT COUNT(*) FROM users' . $where);
    $count->execute($params);
    $total = (int)$count->fetchColumn();
    $page = min($page, max(1, (int)ceil($total / $perPage)));
    $sql = 'SELECT ' . implode(', ', array_map('users_identifier', $columns)) .
           ' FROM users' . $where . ' ORDER BY id DESC LIMIT :limit OFFSET :offset';
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) $stmt->bindValue($key, $value, PDO::PARAM_STR);
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', ($page - 1) * $perPage, PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    error_log('Admin users list: ' . $e->getMessage());
    $error = 'ব্যবহারকারীদের তালিকা লোড করা যায়নি। ডাটাবেজ পরীক্ষা করুন।';
}
function users_page_url(int $page, string $q): string {
    return 'users.php?' . http_build_query(['q'=>$q, 'page'=>$page]);
}
?>
<!doctype html>
<html lang="bn">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ব্যবহারকারী ব্যবস্থাপনা | Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#faf5f3;color:#301d20;font:15px system-ui,-apple-system,sans-serif}
header{background:#490a17;color:#fff;padding:20px max(18px,calc((100vw - 1160px)/2))}
header a{color:#fff;text-decoration:none}.wrap{max-width:1160px;margin:25px auto;padding:0 16px}
h1{font-size:25px;margin:0 0 8px}.sub{color:#78656a;margin-bottom:24px}
.panel{background:#fff;border:1px solid #e8d9d5;border-radius:18px;padding:18px;box-shadow:0 4px 20px #3d101008}
.controls{display:flex;gap:12px;flex-wrap:wrap;justify-content:space-between;align-items:end;margin-bottom:18px}
form{display:flex;gap:8px;flex-wrap:wrap;flex:1}input{flex:1;min-width:190px;padding:12px;border:1px solid #d8c7c5;border-radius:10px;font:inherit}
button{padding:12px 19px;background:#751a2b;color:#fff;border:0;border-radius:10px;font-weight:700}
.count{font-weight:750;color:#751a2b}.scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;min-width:660px}
th,td{text-align:left;padding:12px;border-bottom:1px solid #f1e8e5;vertical-align:top;overflow-wrap:anywhere}
th{background:#fff6f0;color:#71303c;white-space:nowrap}tr:hover td{background:#fffaf7}
.empty,.error{padding:20px;text-align:center}.error{color:#a01025;background:#ffeded;border-radius:12px}
.pages{display:flex;gap:12px;align-items:center;justify-content:center;margin-top:22px}
.pages a{padding:10px 14px;text-decoration:none;color:#751a2b;border:1px solid #e5cfc8;border-radius:9px}
@media(max-width:600px){.wrap{margin:16px auto}.panel{padding:12px}h1{font-size:22px}}
</style>
</head>
<body>
<header><a href="fire_safety_job_prep_dashboard.php">← Fire Safety BD — অ্যাডমিন ড্যাশবোর্ড</a></header>
<main class="wrap">
<h1>ব্যবহারকারী ব্যবস্থাপনা</h1>
<p class="sub">নিবন্ধিত ব্যবহারকারীদের তালিকা দেখুন ও খুঁজুন। নিরাপত্তার জন্য পাসওয়ার্ড ও টোকেন দেখানো হয় না।</p>
<section class="panel">
<div class="controls">
<form method="get" action="users.php">
<input type="search" name="q" maxlength="80" placeholder="নাম, ইমেইল বা মোবাইল দিয়ে খুঁজুন" value="<?= users_h($search) ?>">
<button type="submit">খুঁজুন</button>
</form>
<span class="count">মোট <?= number_format($total) ?> জন</span>
</div>
<?php if ($error !== ''): ?>
<div class="error" role="alert"><?= users_h($error) ?></div>
<?php elseif (!$rows): ?>
<div class="empty">কোনো ব্যবহারকারী পাওয়া যায়নি।</div>
<?php else: ?>
<div class="scroll"><table>
<thead><tr><?php foreach ($columns as $column): ?><th><?= users_h($labels[$column]) ?></th><?php endforeach; ?></tr></thead>
<tbody><?php foreach ($rows as $row): ?><tr>
<?php foreach ($columns as $column): ?><td><?= users_h($row[$column] ?? '—') ?></td><?php endforeach; ?>
</tr><?php endforeach; ?></tbody></table></div>
<?php endif; ?>
<?php if ($total > $perPage): ?>
<nav class="pages" aria-label="পাতা পরিবর্তন">
<?php if ($page > 1): ?><a href="<?= users_h(users_page_url($page-1,$search)) ?>">← আগের</a><?php endif; ?>
<span><?= $page ?> / <?= (int)ceil($total/$perPage) ?></span>
<?php if ($page*$perPage < $total): ?><a href="<?= users_h(users_page_url($page+1,$search)) ?>">পরের →</a><?php endif; ?>
</nav>
<?php endif; ?>
</section>
</main>
</body></html>
