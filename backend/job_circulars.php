<?php
require_once __DIR__ . '/admin_helpers.php';

start_secure_session();
require_admin();
require_once __DIR__ . '/db.php';

if (!isset($pdo) || !($pdo instanceof PDO)) {
    http_response_code(500);
    exit('Database connection unavailable.');
}
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
$csrf = $_SESSION['csrf_token'];

function e($value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
function redirectJobs(): void {
    header('Location: job_circulars.php');
    exit;
}
function validDateOrNull($value): ?string {
    if (!$value) return null;
    $d = DateTime::createFromFormat('Y-m-d', $value);
    return ($d && $d->format('Y-m-d') === $value) ? $value : null;
}

$message = '';
$error = '';

/* ---------- SAVE / EDIT / PIN / DELETE ---------- */
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $token = $_POST['csrf_token'] ?? '';
        if (!is_string($token) || !hash_equals($csrf, $token)) {
            throw new RuntimeException('অনুরোধটি যাচাই করা যায়নি। পেজটি রিফ্রেশ করে আবার চেষ্টা করুন।');
        }

        $action = $_POST['action'] ?? '';

        if ($action === 'add' || $action === 'edit') {
            $id = (int)($_POST['id'] ?? 0);
            $title = trim($_POST['title'] ?? '');
            $organization = trim($_POST['organization'] ?? '');
            $location = trim($_POST['location'] ?? '');
            $employment = trim($_POST['employment_type'] ?? '');
            $salary = trim($_POST['salary'] ?? '');
            $vacancies = trim($_POST['vacancies'] ?? '');
            $description = trim($_POST['description'] ?? '');
            $requirements = trim($_POST['requirements'] ?? '');
            $url = trim($_POST['application_url'] ?? '');
            $deadlineInput = trim($_POST['application_deadline'] ?? '');
            $status = $_POST['status'] ?? 'draft';

            if ($title === '' || $description === '') {
                throw new RuntimeException('পদের নাম ও চাকরির বিবরণ অবশ্যই দিতে হবে।');
            }
            if (!in_array($status, ['draft', 'published', 'archived'], true)) {
                throw new RuntimeException('প্রকাশের অবস্থা সঠিক নয়।');
            }
            if ($url !== '' && (!filter_var($url, FILTER_VALIDATE_URL) || !in_array(strtolower((string)parse_url($url, PHP_URL_SCHEME)), ['https'], true))) {
                throw new RuntimeException('সঠিক https:// Application URL দিন।');
            }
            $deadline = validDateOrNull($deadlineInput);
            if ($deadlineInput !== '' && $deadline === null) {
                throw new RuntimeException('আবেদনের শেষ তারিখ সঠিক নয়।');
            }

            if ($action === 'add') {
                $publishedAt = $status === 'published' ? date('Y-m-d H:i:s') : null;
                $stmt = $pdo->prepare("
                    INSERT INTO job_circulars
                    (category_id,title,organization,location,employment_type,salary,vacancies,
                     description,requirements,application_url,application_deadline,published_at,status,is_pinned)
                    VALUES (NULL,?,?,?,?,?,?,?,?,?,?,?,?,0)
                ");
                $stmt->execute([
                    $title, $organization ?: null, $location ?: null, $employment ?: null,
                    $salary ?: null, $vacancies ?: null, $description, $requirements ?: null,
                    $url ?: null, $deadline, $publishedAt, $status
                ]);
            } else {
                if ($id < 1) throw new RuntimeException('সার্কুলারের ID সঠিক নয়।');
                $stmt = $pdo->prepare("SELECT published_at FROM job_circulars WHERE id=?");
                $stmt->execute([$id]);
                $old = $stmt->fetch(PDO::FETCH_ASSOC);
                if (!$old) throw new RuntimeException('সার্কুলারটি পাওয়া যায়নি।');
                $publishedAt = $status === 'published'
                    ? ($old['published_at'] ?: date('Y-m-d H:i:s'))
                    : $old['published_at'];

                $stmt = $pdo->prepare("
                    UPDATE job_circulars SET
                    title=?, organization=?, location=?, employment_type=?, salary=?, vacancies=?,
                    description=?, requirements=?, application_url=?, application_deadline=?,
                    published_at=?, status=? WHERE id=?
                ");
                $stmt->execute([
                    $title, $organization ?: null, $location ?: null, $employment ?: null,
                    $salary ?: null, $vacancies ?: null, $description, $requirements ?: null,
                    $url ?: null, $deadline, $publishedAt, $status, $id
                ]);
            }
            redirectJobs();
        }

        if ($action === 'pin') {
            $id = (int)($_POST['id'] ?? 0);
            $pin = (int)($_POST['pin'] ?? 0);
            if ($id < 1 || !in_array($pin, [0, 1], true)) {
                throw new RuntimeException('Pin অনুরোধ সঠিক নয়।');
            }
            $stmt = $pdo->prepare("UPDATE job_circulars SET is_pinned=? WHERE id=?");
            $stmt->execute([$pin, $id]);
            redirectJobs();
        }

        if ($action === 'delete') {
            $id = (int)($_POST['id'] ?? 0);
            if ($id < 1) throw new RuntimeException('সার্কুলারের ID সঠিক নয়।');
            $stmt = $pdo->prepare("DELETE FROM job_circulars WHERE id=?");
            $stmt->execute([$id]);
            redirectJobs();
        }
    } catch (Throwable $ex) {
        error_log('Job Circular Admin: ' . $ex->getMessage());
        $error = $ex instanceof PDOException
            ? 'ডাটাবেজে সমস্যা হয়েছে। সার্ভার লগ পরীক্ষা করুন।'
            : $ex->getMessage();
    }
}

/* ---------- EDIT DATA ---------- */
$editItem = null;
if (isset($_GET['edit'])) {
    $id = (int)$_GET['edit'];
    if ($id > 0) {
        $stmt = $pdo->prepare("SELECT * FROM job_circulars WHERE id=?");
        $stmt->execute([$id]);
        $editItem = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }
}

/* ---------- SEARCH AND COUNTS ---------- */
$search = trim($_GET['search'] ?? '');
$sql = "SELECT * FROM job_circulars";
$params = [];
if ($search !== '') {
    $sql .= " WHERE title LIKE ? OR organization LIKE ? OR location LIKE ?";
    $term = '%' . $search . '%';
    $params = [$term, $term, $term];
}
$sql .= " ORDER BY is_pinned DESC, COALESCE(published_at,created_at) DESC, id DESC";
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$jobs = $stmt->fetchAll(PDO::FETCH_ASSOC);

$total = (int)$pdo->query("SELECT COUNT(*) FROM job_circulars")->fetchColumn();
$published = (int)$pdo->query("SELECT COUNT(*) FROM job_circulars WHERE status='published'")->fetchColumn();
$drafts = (int)$pdo->query("SELECT COUNT(*) FROM job_circulars WHERE status='draft'")->fetchColumn();
$pinned = (int)$pdo->query("SELECT COUNT(*) FROM job_circulars WHERE is_pinned=1")->fetchColumn();
?>
<!doctype html>
<html lang="bn">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>চাকরির সার্কুলার - Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#fff8f5;color:#30191b;font-family:Arial,"Noto Sans Bengali","SolaimanLipi",sans-serif}a{text-decoration:none;color:inherit}
.layout{display:flex;min-height:100vh}.sidebar{width:260px;flex-shrink:0;background:linear-gradient(180deg,#450b15,#6a111f);color:#fff;padding:22px 15px}
.brand{display:flex;align-items:center;gap:12px;margin-bottom:28px;padding:5px}.logo{width:58px;height:58px;object-fit:contain;border:2px solid white;border-radius:12px}
.brand-title{font-size:19px;font-weight:800}.brand-sub{color:#e0bfc2;font-size:13px;margin-top:4px}.nav{display:grid;gap:6px}
.nav a{padding:13px;border-radius:12px;color:#f5e4e5}.nav a:hover{background:#ffffff18}.nav a.active{background:#ffa400;color:#29170b;font-weight:bold}.nav a.logout{margin-top:12px;border:1px solid #ffffff55}
.main{flex:1;min-width:0;padding:28px}.header{display:flex;justify-content:space-between;align-items:center;gap:15px;margin-bottom:25px}
h1{margin:0 0 8px;font-size:29px}.sub{color:#8b7777}.btn{display:inline-block;border:0;border-radius:11px;background:#ffa400;color:#29170b;padding:11px 16px;font-weight:bold;cursor:pointer}
.btn.dark{background:#510d18;color:white}.btn.red{background:#b42318;color:white}.btn.gray{background:#eee3e0;color:#45252a}
.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:22px}.card,.panel{background:white;border:1px solid #f1ddd6;border-radius:17px;padding:19px}
.card-label{color:#8b7777}.card-value{font-size:30px;font-weight:900;color:#781523;margin-top:12px}.panel{margin-bottom:22px}.panel h2{font-size:21px;margin:0 0 18px}
.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.field{margin-bottom:4px}.field.full{grid-column:1/-1}
label{display:block;font-weight:bold;margin-bottom:7px}input,select,textarea{width:100%;border:1px solid #e9d8d3;border-radius:10px;padding:12px;font:inherit;background:#fff}
textarea{min-height:105px;resize:vertical}.paste-box{min-height:230px;background:#fffdfb;border:2px dashed #d7b9b3}.hint{font-size:13px;color:#806d6d;line-height:1.6;margin:7px 0}
.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}.alert{padding:13px;border-radius:10px;margin-bottom:15px;background:#e1f4e8;color:#176b3b}.alert.error{background:#ffe5e5;color:#a11919}
.searchbar{display:flex;gap:10px;margin-bottom:16px}.searchbar input{flex:1}.table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;min-width:850px}
th,td{padding:13px 10px;text-align:left;border-bottom:1px solid #f1e5e1;vertical-align:middle}th{color:#806d6d;background:#fffaf8}
.job-title{font-weight:bold}.organization{color:#806d6d;font-size:13px;margin-top:5px}.badge{display:inline-block;border-radius:30px;padding:6px 10px;font-size:12px;font-weight:bold}
.badge.published{background:#e1f4e8;color:#176b3b}.badge.draft{background:#fff0d6;color:#895500}.badge.archived{background:#eee3e0;color:#674d4d}.badge.pinned{background:#fff0c2;color:#805000}
.small-btn{display:inline-block;border:0;border-radius:8px;padding:8px 10px;cursor:pointer;font-weight:bold;font-size:12px}.pin-btn{background:#fff0c2;color:#805000}.edit-btn{background:#e9f1ff;color:#2452a0}.delete-btn{background:#ffe5e5;color:#a11919}
.inline-form{display:inline-block}.section-note{padding:12px;background:#fff5e6;border-radius:10px;color:#6d4a12;font-size:13px;line-height:1.6;margin-bottom:15px}
@media(max-width:1000px){.sidebar{width:220px}.cards{grid-template-columns:repeat(2,1fr)}}
@media(max-width:700px){.layout{display:block}.sidebar{width:100%;padding:14px}.nav{grid-template-columns:repeat(2,1fr)}.main{padding:17px 12px}.header{align-items:flex-start;flex-direction:column}.form-grid{grid-template-columns:1fr}.field.full{grid-column:auto}.cards{gap:9px}.card{padding:13px}.card-value{font-size:25px}.panel{padding:15px}.searchbar{flex-wrap:wrap}.searchbar input{flex-basis:100%}}

.parsed-summary{border:1px solid #e8d7cf;border-radius:14px;background:#fffaf6;padding:16px;margin-bottom:18px}
.parsed-summary h3{margin:0 0 12px;font-size:18px}
.parsed-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.parsed-item{background:white;border:1px solid #f0e3dc;border-radius:10px;padding:11px}
.parsed-item b{display:block;font-size:12px;color:#795e5e;margin-bottom:6px}
.parsed-item span{white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px}
.parsed-missing{color:#a11919;font-style:italic}
.parsed-sections{display:grid;gap:9px;margin-top:14px}
.parsed-sections details{background:white;border:1px solid #f0e3dc;border-radius:10px;padding:12px}
.parsed-sections summary{font-weight:bold;cursor:pointer}
.parsed-sections pre{font:inherit;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.65;margin:10px 0 0}
@media(max-width:700px){.parsed-grid{grid-template-columns:1fr}}
</style>
<link rel="stylesheet" href="assets/admin-unified.css">
</head>
<body>
<div class="layout">
<aside class="sidebar">
    <a href="fire_safety_job_prep_dashboard.php" class="brand">
        <img src="assets/fire-safety-bd-logo.png" class="logo" alt="Logo">
        <div><div class="brand-title">Fire Safety BD</div><div class="brand-sub">অ্যাডমিন প্যানেল</div></div>
    </a>
    <nav class="nav">
        <a href="fire_safety_job_prep_dashboard.php">▦ ড্যাশবোর্ড</a>
        <a href="questions.php">ⓘ প্রশ্ন ব্যাংক</a>
        <a href="model_tests.php">☑ মডেল টেস্ট</a>
        <a href="notes.php">◫ নোট</a>
        <a href="job_circulars.php" class="active">▣ চাকরির সার্কুলার</a>
        <a href="logout.php" class="logout">↪ লগ আউট</a>
    </nav>
</aside>

<main class="main">
    <div class="header">
        <div><h1>চাকরির সার্কুলার</h1><div class="sub">সম্পূর্ণ বিজ্ঞপ্তি পেস্ট করে তথ্য সাজান, যাচাই করুন এবং প্রকাশ করুন</div></div>
        <a href="fire_safety_job_prep_dashboard.php" class="btn gray">← ড্যাশবোর্ডে ফিরুন</a>
    </div>

    <?php if ($error): ?><div class="alert error"><?= e($error) ?></div><?php endif; ?>

    <section class="cards">
        <div class="card"><div class="card-label">মোট সার্কুলার</div><div class="card-value"><?= number_format($total) ?></div></div>
        <div class="card"><div class="card-label">প্রকাশিত</div><div class="card-value"><?= number_format($published) ?></div></div>
        <div class="card"><div class="card-label">ড্রাফট</div><div class="card-value"><?= number_format($drafts) ?></div></div>
        <div class="card"><div class="card-label">Pinned সার্কুলার</div><div class="card-value"><?= number_format($pinned) ?></div></div>
    </section>

    <section class="panel" id="add-form">
        <h2><?= $editItem ? 'সার্কুলার সম্পাদনা করুন' : 'নতুন সার্কুলার তৈরি করুন' ?></h2>

        <?php if (!$editItem): ?>
        <div class="field">
            <label for="source_text">সম্পূর্ণ চাকরির বিজ্ঞপ্তি কপি করে এখানে পেস্ট করুন</label>
            <textarea id="source_text" class="paste-box" placeholder="প্রতিষ্ঠানের নাম, পদের নাম, যোগ্যতা, বেতন, আবেদনের শেষ তারিখসহ সম্পূর্ণ বিজ্ঞপ্তি এখানে পেস্ট করুন..."></textarea>
            <p class="hint">“তথ্য সাজান” চাপলে Bdjobs-এর মতো বাংলা/ইংরেজি বিজ্ঞপ্তির Education, Experience, Responsibilities, Skills, Benefits, Location ইত্যাদি আলাদা করে Preview দেখাবে। বিজ্ঞপ্তিতে যে তথ্য নেই সেগুলোর ঘর খালি থাকবে—আপনি ম্যানুয়ালি লিখবেন। আবেদনের লিংক সবসময় নিজে দেবেন; এটি স্বয়ংক্রিয়ভাবে বসানো হবে না। সংরক্ষণের আগে অবশ্যই যাচাই করুন।</p>
            <div class="actions">
                <button type="button" class="btn dark" id="parseBtn">✦ তথ্য সাজান</button>
                <button type="button" class="btn gray" id="manualEntryBtn">＋ ম্যানুয়ালি সার্কুলার যোগ করুন</button>
            </div>
            <span id="parseStatus" class="hint" aria-live="polite"></span>
        </div>
        <?php endif; ?>

        <div id="previewArea" <?= $editItem ? '' : 'hidden' ?>>
            <div class="section-note"><strong>Preview ও সংশোধন:</strong> প্রতিটি শনাক্ত করা সেকশন নিচে আলাদা করে দেখানো হবে। মূল বিজ্ঞপ্তির সম্পূর্ণ লেখা বিবরণে রাখা হবে, যাতে কোনো তথ্য বাদ না যায়। অনুপস্থিত তথ্য নিজে পূরণ করুন এবং আবেদনের লিংক ম্যানুয়ালি লিখুন। আগে পূরণ করা ম্যানুয়াল তথ্য আবার “তথ্য সাজান” চাপলেও মুছে যাবে না। প্রথমে Draft রাখুন, যাচাই শেষে Published করুন।</div>
            <?php if (!$editItem): ?><div id="structuredPreview" class="parsed-summary" hidden aria-live="polite"></div><?php endif; ?>

            <form method="post" action="job_circulars.php<?= $editItem ? '?edit=' . (int)$editItem['id'] : '' ?>">
                <input type="hidden" name="csrf_token" value="<?= e($csrf) ?>">
                <input type="hidden" name="action" value="<?= $editItem ? 'edit' : 'add' ?>">
                <?php if ($editItem): ?><input type="hidden" name="id" value="<?= (int)$editItem['id'] ?>"><?php endif; ?>

                <div class="form-grid">
                    <div class="field"><label>পদের নাম *</label><input id="title" name="title" required maxlength="255" value="<?= e($editItem['title'] ?? '') ?>" placeholder="যেমন: Fire Safety Officer"></div>
                    <div class="field"><label>প্রতিষ্ঠানের নাম</label><input id="organization" name="organization" maxlength="200" value="<?= e($editItem['organization'] ?? '') ?>"></div>
                    <div class="field"><label>কর্মস্থল</label><input id="location" name="location" maxlength="200" value="<?= e($editItem['location'] ?? '') ?>"></div>
                    <div class="field"><label>চাকরির ধরন</label><input id="employment_type" name="employment_type" maxlength="100" value="<?= e($editItem['employment_type'] ?? '') ?>" placeholder="যেমন: ফুল টাইম"></div>
                    <div class="field"><label>বেতন</label><input id="salary" name="salary" maxlength="120" value="<?= e($editItem['salary'] ?? '') ?>"></div>
                    <div class="field"><label>পদসংখ্যা</label><input id="vacancies" name="vacancies" maxlength="80" value="<?= e($editItem['vacancies'] ?? '') ?>"></div>
                    <div class="field"><label>আবেদনের শেষ তারিখ</label><input id="application_deadline" type="date" name="application_deadline" value="<?= e($editItem['application_deadline'] ?? '') ?>"></div>
                    <div class="field"><label for="application_url">আবেদনের লিংক (ম্যানুয়ালি দিন)</label><input id="application_url" type="url" name="application_url" inputmode="url" value="<?= e($editItem['application_url'] ?? '') ?>" placeholder="https://example.com/apply"><p class="hint">এই লিংক আপনি নিজে দেবেন। স্বয়ংক্রিয়ভাবে কোনো লিংক বসানো হবে না।</p></div>
                    <div class="field full"><label>চাকরির বিবরণ *</label><textarea id="description" name="description" required placeholder="চাকরির বিস্তারিত বিবরণ"><?= e($editItem['description'] ?? '') ?></textarea></div>
                    <div class="field full"><label>যোগ্যতা ও শর্তাবলি</label><textarea id="requirements" name="requirements" placeholder="শিক্ষাগত যোগ্যতা, অভিজ্ঞতা ও অন্যান্য শর্ত"><?= e($editItem['requirements'] ?? '') ?></textarea></div>
                    <div class="field"><label>প্রকাশের অবস্থা</label><select name="status">
                        <option value="draft" <?= ($editItem['status'] ?? 'draft') === 'draft' ? 'selected' : '' ?>>Draft — খসড়া</option>
                        <option value="published" <?= ($editItem['status'] ?? '') === 'published' ? 'selected' : '' ?>>Published — প্রকাশিত</option>
                        <option value="archived" <?= ($editItem['status'] ?? '') === 'archived' ? 'selected' : '' ?>>Archived — আর্কাইভ</option>
                    </select></div>
                </div>
                <div class="actions">
                    <button type="submit" class="btn"><?= $editItem ? 'পরিবর্তন সংরক্ষণ করুন' : 'সার্কুলার সংরক্ষণ করুন' ?></button>
                    <?php if ($editItem): ?><a href="job_circulars.php" class="btn gray">বাতিল</a><?php else: ?><button type="button" class="btn gray" id="hidePreviewBtn">Preview বন্ধ করুন</button><?php endif; ?>
                </div>
            </form>
        </div>
    </section>

    <section class="panel">
        <h2>সকল সার্কুলার</h2>
        <form method="get" class="searchbar">
            <input type="search" name="search" value="<?= e($search) ?>" placeholder="পদের নাম, প্রতিষ্ঠান বা কর্মস্থল দিয়ে খুঁজুন...">
            <button class="btn dark" type="submit">খুঁজুন</button>
            <?php if ($search !== ''): ?><a href="job_circulars.php" class="btn gray">রিসেট</a><?php endif; ?>
        </form>
        <div class="table-wrap"><table>
            <thead><tr><th>সার্কুলার</th><th>শেষ তারিখ</th><th>স্ট্যাটাস</th><th>Pin</th><th>কার্যক্রম</th></tr></thead>
            <tbody>
            <?php if (!$jobs): ?><tr><td colspan="5">কোনো সার্কুলার পাওয়া যায়নি।</td></tr><?php endif; ?>
            <?php foreach ($jobs as $job): ?>
                <tr>
                    <td><div class="job-title"><?= e($job['title']) ?></div><div class="organization"><?= e($job['organization'] ?: 'প্রতিষ্ঠানের নাম দেওয়া হয়নি') ?><?= $job['location'] ? ' · ' . e($job['location']) : '' ?></div></td>
                    <td><?= $job['application_deadline'] ? e(date('d-m-Y', strtotime($job['application_deadline']))) : 'উল্লেখ নেই' ?></td>
                    <td><span class="badge <?= e($job['status']) ?>"><?= strtoupper(e($job['status'])) ?></span></td>
                    <td><?php if ((int)$job['is_pinned'] === 1): ?><span class="badge pinned">📌 Pinned</span><?php else: ?>সাধারণ<?php endif; ?></td>
                    <td><div class="actions">
                        <a class="small-btn edit-btn" href="job_circulars.php?edit=<?= (int)$job['id'] ?>#add-form">এডিট</a>
                        <form method="post" class="inline-form"><input type="hidden" name="csrf_token" value="<?= e($csrf) ?>"><input type="hidden" name="action" value="pin"><input type="hidden" name="id" value="<?= (int)$job['id'] ?>"><input type="hidden" name="pin" value="<?= (int)$job['is_pinned'] === 1 ? '0' : '1' ?>"><button type="submit" class="small-btn pin-btn"><?= (int)$job['is_pinned'] === 1 ? '📌 Unpin' : '📌 উপরে রাখুন' ?></button></form>
                        <form method="post" class="inline-form" onsubmit="return confirm('এই সার্কুলারটি স্থায়ীভাবে ডিলিট করবেন?');"><input type="hidden" name="csrf_token" value="<?= e($csrf) ?>"><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$job['id'] ?>"><button type="submit" class="small-btn delete-btn">ডিলিট</button></form>
                    </div></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table></div>
    </section>
</main>
</div>

<script>
/* Section-aware, offline parser for copied Bangla/English job notices.
 * It never invents absent fields and retains the complete source notice.
 */
function parseJobCircular(sourceText) {
    const source = String(sourceText || '').replace(/\r\n?/g, '\n').trim();
    const aliases = [
        ['additional_requirements', 'Additional Requirements', ['additional requirements','other requirements','অতিরিক্ত যোগ্যতা','অন্যান্য যোগ্যতা','অতিরিক্ত শর্ত']],
        ['responsibilities', 'Responsibilities & Context', ['responsibilities & context','responsibilities and context','job responsibilities','responsibilities','duties and responsibilities','দায়িত্ব ও কর্তব্য','দায়িত্ব ও কর্তব্য','কাজের দায়িত্ব','কাজের দায়িত্ব']],
        ['other_skills', 'Other Relevant Skills', ['other relevant skills','other skills','অন্যান্য দক্ষতা']],
        ['skills', 'Skills & Expertise', ['skills & expertise','skills and expertise','skills','দক্ষতা']],
        ['benefits', 'Compensation & Other Benefits', ['compensation & other benefits','compensation and other benefits','other benefits','benefits','সুযোগ সুবিধা','সুযোগ-সুবিধা','বেতন ও অন্যান্য সুবিধা']],
        ['education', 'Education', ['education','educational requirements','educational qualification','শিক্ষাগত যোগ্যতা','শিক্ষাগত যোগ্যতা ও প্রশিক্ষণ']],
        ['experience', 'Experience', ['experience','experience requirements','অভিজ্ঞতা']],
        ['workplace', 'Workplace', ['workplace','কর্মপদ্ধতি','কাজের ধরন']],
        ['employment', 'Employment Status', ['employment status','employment type','job type','চাকরির ধরন','নিয়োগের ধরন','নিয়োগের ধরন']],
        ['gender', 'Gender', ['gender','লিঙ্গ']],
        ['location', 'Job Location', ['job location','location','কর্মস্থল','কর্ম এলাকা','কর্মের স্থান']],
        ['salary', 'Salary', ['salary','monthly salary','বেতন','মাসিক বেতন']],
        ['vacancies', 'Vacancies', ['number of vacancies','no. of posts','vacancies','পদসংখ্যা','শূন্যপদ']],
        ['deadline', 'Application Deadline', ['application deadline','apply deadline','last date','deadline','আবেদনের শেষ তারিখ','আবেদনের শেষ সময়','আবেদনের শেষ সময়']],
        ['application_url', 'Application URL', ['application url','application link','apply link','আবেদনের লিংক','আবেদনের লিঙ্ক']],
        ['title', 'Job Title', ['job title','position','designation','post name','পদের নাম','নিয়োগের পদ','নিয়োগের পদ']],
        ['organization', 'Organization', ['organization','company name','employer','প্রতিষ্ঠানের নাম','নিয়োগকারী প্রতিষ্ঠান','নিয়োগকারী প্রতিষ্ঠান']]
    ];
    const labelMap = new Map();
    for (const [key, title, names] of aliases) for (const name of names) labelMap.set(name.toLowerCase(), {key, title});
    const stripMarkdown = line => line.trim()
        .replace(/^#{1,6}\s*/, '')
        .replace(/^\*\*(.*?)\*\*$/, '$1')
        .replace(/^__(.*?)__$/, '$1')
        .replace(/\*\*/g, '').trim();
    const isDivider = line => /^(?:-{3,}|\*{3,}|_{3,})$/.test(line.trim());
    const sections = [];
    const byKey = {};
    let active = null;
    const looseLines = [];
    const originalLines = source.split('\n');
    for (const originalLine of originalLines) {
        if (isDivider(originalLine)) continue;
        const line = stripMarkdown(originalLine);
        if (!line || /^[-*•]\s*$/.test(line)) continue;
        const header = line.match(/^([^:：]{2,70}?)(?:\s*[:：]\s*(.*))?$/);
        const name = header && header[1].trim().toLowerCase();
        const known = name && labelMap.get(name);
        if (known) {
            active = {key: known.key, title: known.title, lines: []};
            sections.push(active);
            if (!byKey[known.key]) byKey[known.key] = [];
            byKey[known.key].push(active);
            if (header[2] && header[2].trim()) active.lines.push(header[2].trim());
            continue;
        }
        // 'Requirements' is a parent heading in Bdjobs notices, not a job title.
        if (/^(requirements|job requirements|যোগ্যতা|শর্তাবলি)$/i.test(line)) {
            active = null;
            continue;
        }
        if (active) active.lines.push(line.replace(/^[-*•]\s+/, '• ').trim());
        else looseLines.push(line);
    }
    const sectionText = key => (byKey[key] || []).flatMap(s => s.lines).join('\n').trim();
    const scalar = key => {
        const s = sectionText(key).split('\n').find(Boolean);
        return s ? s.replace(/^•\s*/, '').trim() : '';
    };
    const explicit = key => {
        const entries = byKey[key] || [];
        return entries.map(s => s.lines.join(' ').replace(/^•\s*/, '').trim()).find(Boolean) || '';
    };
    // Fallback only for a recognizable non-heading title line; never use a section name.
    const title = explicit('title') || '';
    const organization = explicit('organization') || '';
    const location = scalar('location');
    const employment = scalar('employment');
    const salary = scalar('salary');
    const vacancies = scalar('vacancies');
    const workplace = scalar('workplace');
    const gender = scalar('gender');
    const rawDeadline = scalar('deadline');
    let deadline = '';
    const iso = rawDeadline.match(/\b(20\d{2})[\/.\-](\d{1,2})[\/.\-](\d{1,2})\b/);
    const dmy = rawDeadline.match(/\b(\d{1,2})[\/.\-](\d{1,2})[\/.\-](20\d{2})\b/);
    if (iso) deadline = `${iso[1]}-${iso[2].padStart(2,'0')}-${iso[3].padStart(2,'0')}`;
    else if (dmy) deadline = `${dmy[3]}-${dmy[2].padStart(2,'0')}-${dmy[1].padStart(2,'0')}`;
    else {
        const months = {'জানুয়ারি':'01','জানুয়ারি':'01','ফেব্রুয়ারি':'02','ফেব্রুয়ারি':'02','মার্চ':'03','এপ্রিল':'04','মে':'05','জুন':'06','জুলাই':'07','আগস্ট':'08','সেপ্টেম্বর':'09','অক্টোবর':'10','নভেম্বর':'11','ডিসেম্বর':'12'};
        const bn = rawDeadline.match(/(\d{1,2})\s*(জানুয়ারি|জানুয়ারি|ফেব্রুয়ারি|ফেব্রুয়ারি|মার্চ|এপ্রিল|মে|জুন|জুলাই|আগস্ট|সেপ্টেম্বর|অক্টোবর|নভেম্বর|ডিসেম্বর)\s*(20\d{2})/);
        if (bn) deadline = `${bn[3]}-${months[bn[2]]}-${bn[1].padStart(2,'0')}`;
    }
    if (deadline) {
        const d = new Date(`${deadline}T00:00:00Z`);
        if (Number.isNaN(d.getTime()) || d.toISOString().slice(0,10) !== deadline) deadline = '';
    }
    // Application URL is entered manually by the admin; do not auto-detect links.
    const url = '';
    const requirementsKeys = new Set(['education','experience','additional_requirements','skills','other_skills','gender']);
    const requirements = sections.filter(s => requirementsKeys.has(s.key) && s.lines.length)
        .map(s => `${s.title}\n${s.lines.join('\n')}`).join('\n\n');
    const presentSections = sections.filter(s => s.lines.length);
    return {title, organization, location, employment, salary, vacancies,
        deadline, url, workplace, gender, description: source, requirements,
        sections: presentSections, looseLines};
}

</script>
<script>
(function () {
    const parseButton = document.getElementById('parseBtn');
    if (!parseButton) return;
    const source = document.getElementById('source_text');
    const preview = document.getElementById('previewArea');
    const status = document.getElementById('parseStatus');
    const structured = document.getElementById('structuredPreview');
    // A second parse must never erase or replace an admin's manual edits.
    const manuallyEdited = new Set();
    const editableIds = ['title', 'organization', 'location', 'employment_type',
        'salary', 'vacancies', 'application_deadline', 'application_url',
        'description', 'requirements'];
    for (const id of editableIds) {
        const field = document.getElementById(id);
        if (field) field.addEventListener('input', () => manuallyEdited.add(id));
    }
    const setField = (id, value) => {
        const el = document.getElementById(id);
        if (el && !manuallyEdited.has(id)) el.value = value || '';
    };
    const make = (tag, className, value) => {
        const el = document.createElement(tag);
        if (className) el.className = className;
        if (value !== undefined) el.textContent = value;
        return el;
    };
    function renderStructured(result) {
        structured.replaceChildren();
        structured.appendChild(make('h3', '', 'শনাক্ত করা তথ্য — যাচাই করুন'));
        const grid = make('div', 'parsed-grid');
        const fields = [
            ['পদের নাম', result.title], ['প্রতিষ্ঠানের নাম', result.organization],
            ['কর্মস্থল', result.location], ['চাকরির ধরন', result.employment],
            ['কর্মপদ্ধতি', result.workplace], ['বেতন', result.salary],
            ['পদসংখ্যা', result.vacancies], ['আবেদনের শেষ তারিখ', result.deadline],
            ['আবেদনের লিংক (ম্যানুয়াল)', 'নিজে লিখুন'], ['লিঙ্গ', result.gender]
        ];
        for (const [label, value] of fields) {
            const item = make('div', 'parsed-item');
            item.appendChild(make('b', '', label));
            item.appendChild(make('span', value ? '' : 'parsed-missing', value || 'বিজ্ঞপ্তিতে উল্লেখ নেই'));
            grid.appendChild(item);
        }
        structured.appendChild(grid);
        const sectionWrap = make('div', 'parsed-sections');
        for (const section of result.sections) {
            const details = make('details');
            // Expand Education, Experience and Responsibilities by default.
            if (['education','experience','responsibilities'].includes(section.key)) details.open = true;
            details.appendChild(make('summary', '', `${section.title} (${section.lines.length}টি লাইন)`));
            details.appendChild(make('pre', '', section.lines.join('\n')));
            sectionWrap.appendChild(details);
        }
        structured.appendChild(sectionWrap);
        structured.hidden = false;
    }
    document.getElementById('manualEntryBtn')?.addEventListener('click', function () {
        preview.hidden = false;
        structured.hidden = true;
        status.textContent = 'ম্যানুয়াল ফর্ম খুলেছে। প্রয়োজনীয় তথ্য নিজে পূরণ করে সংরক্ষণ করুন।';
        preview.scrollIntoView({behavior:'smooth', block:'start'});
    });
    parseButton.addEventListener('click', function () {
        const text = source.value.trim();
        if (text.length < 20) {
            status.textContent = 'অনুগ্রহ করে সম্পূর্ণ বিজ্ঞপ্তিটি পেস্ট করুন।';
            return;
        }
        const result = parseJobCircular(text);
        setField('title', result.title);
        setField('organization', result.organization);
        setField('location', result.location);
        setField('employment_type', result.employment);
        setField('salary', result.salary);
        setField('vacancies', result.vacancies);
        // Application URL is exclusively manual. Never touch this field on parse.
        setField('application_deadline', result.deadline);
        setField('description', result.description);
        setField('requirements', result.requirements);
        renderStructured(result);
        preview.hidden = false;
        preview.scrollIntoView({behavior:'smooth', block:'start'});
        const missing = [!result.title && 'পদের নাম', !result.organization && 'প্রতিষ্ঠান', !result.salary && 'বেতন', !result.vacancies && 'পদসংখ্যা', !result.deadline && 'শেষ তারিখ'].filter(Boolean);
        status.textContent = `${result.sections.length}টি সেকশন শনাক্ত হয়েছে। ` +
            (missing.length ? `অনুপস্থিত তথ্য: ${missing.join(', ')} — নিজে পূরণ করতে পারবেন। ` : 'প্রতিটি ফিল্ড যাচাই করুন। ') + 'আবেদনের লিংক ম্যানুয়ালি দিন।';
    });
    document.getElementById('hidePreviewBtn')?.addEventListener('click', () => {
        preview.hidden = true;
        status.textContent = 'Preview বন্ধ করা হয়েছে।';
    });
})();
</script>
</body>
</html>
