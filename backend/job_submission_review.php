<?php
declare(strict_types=1);

// Same admin login as the existing Fire Safety BD dashboard.
require_once __DIR__ . '/admin_helpers.php';
start_secure_session();
require_admin();
require_once __DIR__ . '/db.php';

if (!isset($pdo) || !($pdo instanceof PDO)) {
    http_response_code(500);
    exit('Database unavailable.');
}
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
header('Cache-Control: no-store');

function review_h(mixed $value): string {
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
$error = '';
$success = isset($_GET['saved']) ? 'সিদ্ধান্ত সংরক্ষিত হয়েছে।' : '';
$csrf = csrf_token();

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    verify_csrf();
    $id = filter_var($_POST['submission_id'] ?? null, FILTER_VALIDATE_INT, [
        'options' => ['min_range' => 1]
    ]);
    $decision = (string)($_POST['decision'] ?? '');
    $note = trim((string)($_POST['admin_note'] ?? ''));
    try {
        if ($id === false || $id === null ||
            !in_array($decision, ['approve', 'reject'], true) ||
            strlen($note) > 1000) {
            throw new InvalidArgumentException('অনুরোধ সঠিক নয়।');
        }
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('SELECT * FROM job_submissions WHERE id = ? FOR UPDATE');
        $stmt->execute([$id]);
        $submission = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$submission || $submission['status'] !== 'pending') {
            throw new InvalidArgumentException('এই সার্কুলারটি আর Pending নেই।');
        }
        if ($decision === 'approve') {
            $insert = $pdo->prepare(
                'INSERT INTO job_circulars
                 (category_id, title, organization, location, employment_type,
                  salary, vacancies, description, requirements, application_url,
                  application_deadline, published_at, status, is_pinned)
                 VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), "published", 0)'
            );
            $insert->execute([
                $submission['title'], $submission['organization'],
                $submission['location'], $submission['employment_type'],
                $submission['salary'], $submission['vacancies'],
                $submission['description'], $submission['requirements'],
                $submission['application_url'], $submission['application_deadline']
            ]);
            $jobId = (int)$pdo->lastInsertId();
            $update = $pdo->prepare(
                'UPDATE job_submissions
                 SET status = "approved", published_job_id = ?,
                     admin_note = ?, reviewed_at = NOW() WHERE id = ?'
            );
            $update->execute([$jobId, $note === '' ? null : $note, $id]);
        } else {
            $update = $pdo->prepare(
                'UPDATE job_submissions
                 SET status = "rejected", admin_note = ?, reviewed_at = NOW()
                 WHERE id = ?'
            );
            $update->execute([$note === '' ? null : $note, $id]);
        }
        $pdo->commit();
        header('Location: job_submission_review.php?saved=1');
        exit;
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if ($e instanceof InvalidArgumentException) {
            $error = $e->getMessage();
        } else {
            error_log('Job submission moderation: ' . $e->getMessage());
            $error = 'সিদ্ধান্ত সংরক্ষণ করা যায়নি।';
        }
    }
}
$pending = $pdo->query(
    'SELECT s.*, u.full_name AS submitter_name, u.email AS submitter_email
     FROM job_submissions s LEFT JOIN users u ON u.id = s.user_id
     WHERE s.status = "pending" ORDER BY s.id ASC LIMIT 100'
)->fetchAll(PDO::FETCH_ASSOC);
$history = $pdo->query(
    'SELECT id, title, organization, status, admin_note, published_job_id, reviewed_at
     FROM job_submissions WHERE status <> "pending"
     ORDER BY reviewed_at DESC, id DESC LIMIT 40'
)->fetchAll(PDO::FETCH_ASSOC);
?>
<!doctype html>
<html lang="bn"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ইউজার সার্কুলার অনুমোদন | Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f8f4f5;color:#26181b;font:15px Arial,sans-serif;line-height:1.55}
header{background:#36060d;color:white;padding:20px}header a{color:#fff}
main{max-width:1050px;margin:20px auto;padding:0 16px}
article,section{background:white;padding:20px;margin:15px 0;border:1px solid #eadbe0;border-radius:14px}
h1{font-size:22px;margin:0 0 6px}h2{font-size:19px}h3{margin:0 0 8px}
label{display:block;margin:12px 0 5px;font-weight:bold}
textarea{width:100%;min-height:72px;padding:10px;border:1px solid #bbb;border-radius:7px;font:inherit}
button{padding:10px 16px;border:0;border-radius:8px;color:white;cursor:pointer;background:#650d18;margin:6px 6px 0 0}
button.reject{background:#6d6366}.muted{color:#6b5960}.error{color:#a90021}.success{color:#157b3d}
.notice{white-space:pre-wrap;overflow-wrap:anywhere;background:#faf7f7;padding:14px;border-radius:8px;max-height:340px;overflow:auto}
.info{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:6px}
table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:10px;border-bottom:1px solid #eee}
.scroll{overflow:auto}
</style>
<link rel="stylesheet" href="assets/admin-unified.css"></head><body>
<div class="fs-admin-shell">
<aside class="fs-admin-side" aria-label="অ্যাডমিন নেভিগেশন">
<a class="fs-admin-brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo"><span><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></span></a>
<nav class="fs-admin-menu"><a href="fire_safety_job_prep_dashboard.php">▦ ড্যাশবোর্ড</a>
<a href="questions.php">ⓘ প্রশ্ন ব্যাংক</a>
<a href="model_tests.php">☑ মডেল টেস্ট</a>
<a href="notes.php">◫ নোট</a>
<a href="job_circulars.php" aria-current="page">▣ চাকরির সার্কুলার</a>
<a href="fire_safety_job_prep_dashboard.php?section=marketplace">▤ মার্কেটপ্লেস</a>
<a href="category_management.php">⊞ ক্যাটাগরি</a>
<a href="users.php">♙ ব্যবহারকারী</a>
<a href="fire_safety_job_prep_dashboard.php?section=community">▱ কমিউনিটি</a>
<a href="logout.php">↪ লগ আউট</a></nav>
</aside>
<div class="fs-admin-content">
<a class="fs-admin-mobile-return" href="fire_safety_job_prep_dashboard.php">← ড্যাশবোর্ডে ফিরুন</a>

<header><h1>Fire Safety BD — ইউজার সার্কুলার অনুমোদন</h1>
<a href="job_circulars.php">← Job Circular Admin</a> &nbsp; | &nbsp; <a href="community_review.php">কমিউনিটি পোস্ট অনুমোদন</a></header>
<main>
<?php if ($error !== ''): ?><p class="error"><?= review_h($error) ?></p><?php endif; ?>
<?php if ($success !== ''): ?><p class="success"><?= review_h($success) ?></p><?php endif; ?>
<h2>Pending সার্কুলার (<?= count($pending) ?>)</h2>
<?php if (!$pending): ?><section>বর্তমানে কোনো Pending সার্কুলার নেই।</section><?php endif; ?>
<?php foreach ($pending as $s): ?>
<article>
<h3>#<?= (int)$s['id'] ?> — <?= review_h($s['title']) ?></h3>
<div class="info">
<div><strong>প্রতিষ্ঠান:</strong> <?= review_h($s['organization']) ?></div>
<div><strong>দিয়েছেন:</strong> <?= review_h($s['submitter_name']) ?> (<?= review_h($s['submitter_email']) ?>)</div>
<div><strong>মোবাইল:</strong> <?= review_h($s['mobile_number']) ?></div>
<div><strong>WhatsApp:</strong> <?= review_h($s['whatsapp_number']) ?></div>
<div><strong>নম্বর প্রকাশের সম্মতি:</strong> <?= (int)$s['public_contact'] ? 'হ্যাঁ' : 'না' ?></div>
<div><strong>কর্মস্থল:</strong> <?= review_h($s['location']) ?></div>
<div><strong>চাকরির ধরন:</strong> <?= review_h($s['employment_type']) ?></div>
<div><strong>বেতন:</strong> <?= review_h($s['salary']) ?></div>
<div><strong>পদসংখ্যা:</strong> <?= review_h($s['vacancies']) ?></div>
<div><strong>শেষ তারিখ:</strong> <?= review_h($s['application_deadline']) ?></div>
<div><strong>আবেদনের লিংক:</strong> <?= review_h($s['application_url']) ?></div>
<div><strong>জমার সময়:</strong> <?= review_h($s['created_at']) ?></div>
</div>
<h4>চাকরির বিবরণ</h4><div class="notice"><?= review_h($s['description']) ?></div>
<?php if (trim((string)$s['requirements']) !== ''): ?>
<h4>যোগ্যতা</h4><div class="notice"><?= review_h($s['requirements']) ?></div>
<?php endif; ?>
<form method="post" onsubmit="return confirm('এই সিদ্ধান্ত নিশ্চিত করবেন?');">
<input type="hidden" name="csrf_token" value="<?= review_h($csrf) ?>">
<input type="hidden" name="submission_id" value="<?= (int)$s['id'] ?>">
<label for="note<?= (int)$s['id'] ?>">Admin Note (ঐচ্ছিক; Reject করলে কারণ লিখুন)</label>
<textarea id="note<?= (int)$s['id'] ?>" name="admin_note" maxlength="1000"></textarea>
<button type="submit" name="decision" value="approve">✓ Approve & Publish</button>
<button type="submit" name="decision" value="reject" class="reject">✕ Reject</button>
</form>
</article>
<?php endforeach; ?>
<section><h2>সাম্প্রতিক সিদ্ধান্ত</h2><div class="scroll"><table>
<thead><tr><th>ID</th><th>পদ</th><th>প্রতিষ্ঠান</th><th>অবস্থা</th><th>Admin Note</th><th>Published Job</th></tr></thead>
<tbody><?php foreach ($history as $s): ?><tr>
<td><?= (int)$s['id'] ?></td><td><?= review_h($s['title']) ?></td>
<td><?= review_h($s['organization']) ?></td><td><?= review_h($s['status']) ?></td>
<td><?= review_h($s['admin_note']) ?></td>
<td><?php if ($s['published_job_id']): ?>
<a href="job_circulars.php?edit=<?= (int)$s['published_job_id'] ?>">#<?= (int)$s['published_job_id'] ?></a>
<?php endif; ?></td></tr><?php endforeach; ?></tbody>
</table></div></section>
</main></div>
</div>
</body></html>
