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
        $conditions = [];
        foreach ($searchColumns as $index => $column) {
            $parameter = ':q' . $index;
            $conditions[] = users_identifier($column) . ' LIKE ' . $parameter;
            $params[$parameter] = '%' . $search . '%';
        }
        $where = ' WHERE ' . implode(' OR ', $conditions);
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
:root{--wine:#500b19;--wine2:#761828;--orange:#ffad0d;--ink:#302127;--muted:#84757b;--line:#efdfda;--surface:#fff;--bg:#faf5f2}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 system-ui,-apple-system,"Noto Sans Bengali",sans-serif}
a{text-decoration:none;color:inherit}
.shell{display:grid;grid-template-columns:238px minmax(0,1fr);min-height:100vh}
.sidebar{background:linear-gradient(180deg,#3e0711,#650d1d);color:#fff;padding:25px 15px}
.brand{display:flex;gap:12px;align-items:center;padding:5px 6px 24px;border-bottom:1px solid #ffffff24}
.brand-logo{display:grid;place-items:center;width:52px;height:52px;overflow:hidden;border:1px solid #ffffff75;border-radius:14px;background:#780e20}.brand-logo img{display:block;width:100%;height:100%;object-fit:contain}
.brand-title{font-size:17px;line-height:1.3;font-weight:850}.brand small{font-size:12px;color:#f2c8c9}
.side-nav{display:grid;gap:7px;margin-top:23px}
.side-nav a{display:flex;align-items:center;gap:12px;border-radius:13px;padding:12px 14px;font-weight:650;color:#f9e9e9}
.side-nav a:hover{background:#ffffff17}.side-nav a.active{background:var(--orange);color:#37130b;font-weight:850}
.side-nav .icon{font-size:19px;width:22px;text-align:center}
.main{min-width:0;padding:30px clamp(16px,3vw,42px) 55px}
.topbar{display:flex;align-items:center;justify-content:space-between;gap:18px;flex-wrap:wrap;margin-bottom:26px}
.crumb{font-size:13px;color:#8b7b7c}.crumb a{color:#7d2234;font-weight:700}
.badge{background:#fff4d9;color:#84500a;border:1px solid #f4dba7;border-radius:100px;padding:7px 13px;font-size:12px;font-weight:800}
.heading{display:flex;justify-content:space-between;align-items:end;gap:16px;flex-wrap:wrap;margin-bottom:22px}
h1{margin:0;font-size:clamp(25px,3vw,34px);color:#3b1520;line-height:1.3}
.subtitle{margin:10px 0 0;color:var(--muted)}
.stat-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px;margin-bottom:23px}
.stat{background:var(--surface);border:1px solid var(--line);border-radius:19px;padding:21px;box-shadow:0 5px 18px #450e1510}
.stat small{display:block;color:#7b6970;font-weight:700}
.stat strong{display:block;font-size:32px;color:var(--wine2);font-weight:900;line-height:1.25;margin:8px 0}
.stat span{font-size:12px;color:#9b898c}
.stat.highlight{background:linear-gradient(130deg,#5c0c1c,#831f30);border-color:transparent;color:white}
.stat.highlight small,.stat.highlight strong,.stat.highlight span{color:#fff}
.panel{background:white;border:1px solid var(--line);border-radius:21px;box-shadow:0 7px 25px #4419230d;overflow:hidden}
.panel-head{display:flex;align-items:center;justify-content:space-between;gap:18px;flex-wrap:wrap;padding:21px 22px;border-bottom:1px solid #f2e7e3}
.panel-head h2{font-size:19px;margin:0;color:#4d1722}
.panel-head p{margin:3px 0 0;color:#89767b;font-size:13px}
.search{display:flex;gap:9px;flex-wrap:wrap;max-width:620px;flex:1}
.search input{flex:1;min-width:175px;min-height:46px;border:1px solid #e6d7d3;border-radius:12px;background:#fdfaf9;padding:12px 15px;font:inherit;color:var(--ink);outline:none}
.search input:focus{border-color:#b56575;box-shadow:0 0 0 3px #8b263012}
.search button{border:0;background:#74192b;color:white;padding:11px 20px;border-radius:12px;font:inherit;font-weight:800;cursor:pointer}
.clear{border:1px solid #e7d9d5;border-radius:12px;padding:11px 15px;color:#74333e;font-weight:700}
.table-scroll{overflow-x:auto}
table{width:100%;border-collapse:collapse;min-width:880px}
th{text-align:left;background:#fcf6f1;color:#705059;font-size:12px;letter-spacing:.1px;padding:15px 17px;white-space:nowrap}
td{border-top:1px solid #f3ebe7;padding:16px 17px;vertical-align:middle;font-size:13px;overflow-wrap:anywhere}
tbody tr:hover{background:#fffbf8}
.person{display:flex;align-items:center;gap:11px;min-width:160px}
.avatar{width:39px;height:39px;flex:0 0 39px;display:grid;place-items:center;border-radius:13px;background:#fff0e5;color:#7c2d32;font-size:17px;font-weight:900}
.person strong{color:#42232b;line-height:1.45;display:block}
.secondary{color:#87757b;font-size:12px}
.email{word-break:break-word}
.pill{display:inline-flex;border-radius:100px;background:#fff2df;color:#915412;padding:6px 10px;font-weight:750;font-size:12px;white-space:nowrap}
.mobile-list{display:none;padding:13px}
.user-card{border:1px solid #ebddd9;border-radius:17px;background:#fff;padding:16px;margin:0 0 12px}
.user-card-top{display:flex;gap:10px;align-items:center;justify-content:space-between;padding-bottom:13px;border-bottom:1px solid #f1e7e4}
.user-card .person{min-width:0;flex:1}
.user-card .person strong{overflow-wrap:anywhere}
.details{display:grid;grid-template-columns:1fr 1fr;gap:13px 10px;margin-top:15px}
.details dt{font-size:11px;color:#947f85;margin-bottom:3px}.details dd{margin:0;font-size:13px;font-weight:650;overflow-wrap:anywhere}
.details .wide{grid-column:1/-1}
.empty,.error{text-align:center;padding:55px 18px;color:#87757b}
.error{color:#a11a2b;background:#fff0f0}
.pages{display:flex;align-items:center;justify-content:center;gap:11px;flex-wrap:wrap;padding:20px}
.pages a{border:1px solid #e9d7d1;border-radius:10px;padding:9px 15px;color:#7b2735;font-weight:800;background:#fff}
.pages span{font-size:13px;color:#8c787c}
.footnote{padding:14px 22px;border-top:1px solid #f2e7e3;color:#97868a;font-size:12px;background:#fffdfa}
.mobile-home{display:none}
@media(max-width:1150px){.shell{grid-template-columns:205px minmax(0,1fr)}.sidebar{padding:20px 11px}}
@media(max-width:900px){.shell{display:block}.sidebar{display:none}.main{padding:18px 14px 42px}.mobile-home{display:inline-flex;background:#fff;border:1px solid #edddd7;border-radius:10px;padding:9px 13px;color:#751a2b;font-weight:800;font-size:13px}.topbar{margin-bottom:20px}.table-scroll{display:none}.mobile-list{display:block}}
@media(max-width:560px){.stat-grid{grid-template-columns:1fr 1fr;gap:9px}.stat{padding:15px;border-radius:15px}.stat strong{font-size:25px}.stat:last-child{grid-column:1/-1}.heading{margin-bottom:17px}.subtitle{font-size:13px}.panel-head{padding:17px 14px}.panel-head h2{font-size:18px}.search{width:100%;max-width:none}.search input{min-width:0}.search button{padding:11px 15px}.details{grid-template-columns:1fr 1fr}.user-card{padding:14px}}
</style>
</head>
<body>
<div class="shell">
<aside class="sidebar">
<div class="brand"><div class="brand-logo"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo" width="52" height="52"></div><div><div class="brand-title">Fire Safety<br>BD</div><small>অ্যাডমিন প্যানেল</small></div></div>
<nav class="side-nav" aria-label="অ্যাডমিন মেনু">
<a href="fire_safety_job_prep_dashboard.php"><span class="icon">▦</span> ড্যাশবোর্ড</a>
<a href="questions.php"><span class="icon">ⓘ</span> প্রশ্ন ব্যাংক</a>
<a href="model_tests.php"><span class="icon">☑</span> মডেল টেস্ট</a>
<a href="notes.php"><span class="icon">◫</span> নোট</a>
<a href="job_circulars.php"><span class="icon">▣</span> চাকরির সার্কুলার</a>
<a href="fire_safety_job_prep_dashboard.php?section=marketplace"><span class="icon">▤</span> মার্কেটপ্লেস</a>
<a href="category_management.php"><span class="icon">⊞</span> ক্যাটাগরি</a>
<a href="users.php" class="active" aria-current="page"><span class="icon">♙</span> ব্যবহারকারী</a>
<a href="fire_safety_job_prep_dashboard.php?section=community"><span class="icon">▱</span> কমিউনিটি</a>
<a href="logout.php"><span class="icon">↪</span> লগ আউট</a>
</nav>
</aside>
<main class="main">
<div class="topbar"><div class="crumb"><a href="fire_safety_job_prep_dashboard.php">ড্যাশবোর্ড</a> / ব্যবহারকারী ব্যবস্থাপনা</div><a class="mobile-home" href="fire_safety_job_prep_dashboard.php">← ড্যাশবোর্ডে ফিরুন</a><span class="badge">● Admin Only</span></div>
<div class="heading"><div><h1>ব্যবহারকারী ব্যবস্থাপনা</h1><p class="subtitle">সব নিবন্ধিত সদস্যের তথ্য, প্রোফাইল ও নিবন্ধনের তালিকা এক জায়গায়।</p></div></div>
<section class="stat-grid" aria-label="ব্যবহারকারীর সারসংক্ষেপ">
<div class="stat highlight"><small><?= $search !== '' ? 'সার্চে পাওয়া ব্যবহারকারী' : 'মোট নিবন্ধিত ব্যবহারকারী' ?></small><strong><?= number_format($total) ?></strong><span>ব্যবহারকারীর অ্যাকাউন্ট</span></div>
<div class="stat"><small>এই পেজে দেখানো হচ্ছে</small><strong><?= number_format(count($rows)) ?></strong><span>প্রতি পেজে সর্বোচ্চ <?= $perPage ?> জন</span></div>
<div class="stat"><small>বর্তমান পেজ</small><strong><?= number_format($page) ?></strong><span>মোট <?= number_format(max(1,(int)ceil($total/$perPage))) ?> পেজ</span></div>
</section>
<section class="panel">
<div class="panel-head">
<div><h2>সদস্য তালিকা</h2><p>নাম, মোবাইল বা ইমেইল দিয়ে দ্রুত খুঁজুন</p></div>
<form class="search" method="get" action="users.php" role="search">
<input type="search" name="q" maxlength="80" placeholder="সদস্য খুঁজুন..." value="<?= users_h($search) ?>" aria-label="নাম, ইমেইল বা মোবাইল">
<button type="submit">⌕ খুঁজুন</button>
<?php if ($search !== ''): ?><a class="clear" href="users.php">মুছুন</a><?php endif; ?>
</form>
</div>
<?php if ($error !== ''): ?>
<div class="error" role="alert"><?= users_h($error) ?></div>
<?php elseif (!$rows): ?>
<div class="empty">এই সার্চে কোনো ব্যবহারকারী পাওয়া যায়নি।</div>
<?php else: ?>
<div class="table-scroll"><table>
<thead><tr><th>আইডি</th><th>ব্যবহারকারী</th><th>যোগাযোগ</th><th>বর্তমান অবস্থা</th><th>প্রতিষ্ঠান / পদবি</th><th>নিবন্ধন</th></tr></thead>
<tbody><?php foreach ($rows as $row): ?>
<tr>
<td>#<?= users_h($row['id'] ?? '') ?></td>
<td><div class="person"><span class="avatar"><?= users_h(function_exists('mb_substr') ? mb_substr((string)($row['full_name'] ?? '?'),0,1,'UTF-8') : '?') ?></span><strong><?= users_h($row['full_name'] ?? 'নাম নেই') ?></strong></div></td>
<td><div><?= users_h($row['mobile_number'] ?? $row['phone'] ?? '—') ?></div><div class="secondary email"><?= users_h($row['email'] ?? '—') ?></div></td>
<td><span class="pill"><?= users_h($row['current_status'] ?? '—') ?></span></td>
<td><?= users_h($row['company_name'] ?? '—') ?><div class="secondary"><?= users_h($row['designation'] ?? '') ?></div></td>
<td><?= users_h($row['created_at'] ?? '—') ?></td>
</tr>
<?php endforeach; ?></tbody></table></div>
<div class="mobile-list">
<?php foreach ($rows as $row): ?>
<article class="user-card">
<div class="user-card-top"><div class="person"><span class="avatar"><?= users_h(function_exists('mb_substr') ? mb_substr((string)($row['full_name'] ?? '?'),0,1,'UTF-8') : '?') ?></span><div><strong><?= users_h($row['full_name'] ?? 'নাম নেই') ?></strong><span class="secondary">User ID #<?= users_h($row['id'] ?? '') ?></span></div></div><span class="pill"><?= users_h($row['current_status'] ?? 'সদস্য') ?></span></div>
<dl class="details">
<div><dt>মোবাইল নম্বর</dt><dd><?= users_h($row['mobile_number'] ?? $row['phone'] ?? '—') ?></dd></div>
<div><dt>নিবন্ধনের তারিখ</dt><dd><?= users_h($row['created_at'] ?? '—') ?></dd></div>
<div class="wide"><dt>ইমেইল</dt><dd><?= users_h($row['email'] ?? '—') ?></dd></div>
<div><dt>প্রতিষ্ঠান</dt><dd><?= users_h($row['company_name'] ?? '—') ?></dd></div>
<div><dt>পদবি</dt><dd><?= users_h($row['designation'] ?? '—') ?></dd></div>
</dl>
</article>
<?php endforeach; ?>
</div>
<?php endif; ?>
<?php if ($total > $perPage): ?>
<nav class="pages" aria-label="পাতা পরিবর্তন">
<?php if ($page > 1): ?><a href="<?= users_h(users_page_url($page-1,$search)) ?>">← আগের</a><?php endif; ?>
<span><?= number_format($page) ?> / <?= number_format((int)ceil($total/$perPage)) ?></span>
<?php if ($page*$perPage < $total): ?><a href="<?= users_h(users_page_url($page+1,$search)) ?>">পরের →</a><?php endif; ?>
</nav>
<?php endif; ?>
<div class="footnote">🔒 শুধু অনুমোদিত অ্যাডমিন এই তথ্য দেখতে পারবেন। পাসওয়ার্ড বা লগইন টোকেন প্রকাশ করা হয় না।</div>
</section>
</main></div>
</body></html>
