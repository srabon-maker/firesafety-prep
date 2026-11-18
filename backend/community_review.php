<?php
declare(strict_types=1);
require_once __DIR__ . '/admin_helpers.php';
start_secure_session();
require_admin();
require_once __DIR__ . '/db.php';
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
header('Cache-Control: no-store');

function community_review_escape(mixed $value): string {
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
$error = '';
$saved = isset($_GET['saved']);
$csrf = csrf_token();
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    verify_csrf();
    $id = filter_var($_POST['post_id'] ?? null, FILTER_VALIDATE_INT, ['options'=>['min_range'=>1]]);
    $decision = (string)($_POST['decision'] ?? '');
    try {
        if (!$id || !in_array($decision, ['approve','reject','hide'], true)) {
            throw new InvalidArgumentException('অনুরোধটি সঠিক নয়।');
        }
        $pdo->beginTransaction();
        $q = $pdo->prepare('SELECT status FROM community_posts WHERE id=? FOR UPDATE');
        $q->execute([$id]);
        $current = $q->fetchColumn();
        if (!$current || ($current !== 'pending' && $decision !== 'hide') ||
            ($decision === 'hide' && $current !== 'approved')) {
            throw new InvalidArgumentException('এই পোস্টটির বর্তমান অবস্থা পরিবর্তিত হয়েছে।');
        }
        $next = ['approve'=>'approved','reject'=>'rejected','hide'=>'hidden'][$decision];
        $q = $pdo->prepare('UPDATE community_posts SET status=?, moderated_at=NOW() WHERE id=?');
        $q->execute([$next,$id]);
        $pdo->commit();
        header('Location: community_review.php?saved=1');
        exit;
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        $error = $e instanceof InvalidArgumentException ? $e->getMessage() : 'সিদ্ধান্ত সংরক্ষণ করা যায়নি।';
        if (!($e instanceof InvalidArgumentException)) error_log('Community review: '.$e->getMessage());
    }
}
$pending = $pdo->query(
    "SELECT p.id,p.body,p.image_path,p.created_at,u.full_name,u.email
     FROM community_posts p JOIN users u ON u.id=p.user_id
     WHERE p.status='pending' ORDER BY p.id ASC LIMIT 100"
)->fetchAll(PDO::FETCH_ASSOC);
$recent = $pdo->query(
    "SELECT p.id,p.body,p.status,p.created_at
     FROM community_posts p WHERE p.status<>'pending'
     ORDER BY p.id DESC LIMIT 40"
)->fetchAll(PDO::FETCH_ASSOC);
?>
<!doctype html>
<html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>কমিউনিটি পোস্ট অনুমোদন | Fire Safety BD</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f8f4f5;color:#27191b;font:15px Arial,sans-serif;line-height:1.6}
header{background:#36060d;color:white;padding:20px}header a{color:#fff}
main{max-width:950px;margin:22px auto;padding:0 15px}article,section{background:#fff;border:1px solid #eadbe0;border-radius:15px;padding:18px;margin:15px 0}
h1{margin:0 0 5px;font-size:22px}h2{font-size:20px}.muted{color:#65585c}.error{color:#ae1835}
.body{white-space:pre-wrap;overflow-wrap:anywhere}.photo{max-width:100%;max-height:350px;object-fit:contain;border-radius:12px}
button{background:#650d18;color:white;border:0;border-radius:9px;padding:11px 15px;margin:8px 8px 0 0;cursor:pointer}
button.reject{background:#666}button.hide{background:#a74a24}
</style>
<link rel="stylesheet" href="assets/admin-unified.css">
<script src="assets/admin-shell.js" defer></script></head><body>
<div class="fs-admin-shell">
<aside class="fs-admin-side" aria-label="অ্যাডমিন নেভিগেশন">
<a class="fs-admin-brand" href="fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo"><span><strong>Fire Safety BD</strong><small>অ্যাডমিন প্যানেল</small></span></a>
<nav class="fs-admin-menu"><a href="fire_safety_job_prep_dashboard.php">▦ ড্যাশবোর্ড</a>
<a href="questions.php">ⓘ প্রশ্ন ব্যাংক</a>
<a href="model_tests.php">☑ মডেল টেস্ট</a>
<a href="notes.php">◫ নোট</a>
<a href="job_circulars.php">▣ চাকরির সার্কুলার</a>
<a href="fire_safety_job_prep_dashboard.php?section=marketplace">▤ মার্কেটপ্লেস</a>
<a href="category_management.php">⊞ ক্যাটাগরি</a>
<a href="users.php">♙ ব্যবহারকারী</a>
<a href="fire_safety_job_prep_dashboard.php?section=community" aria-current="page">▱ কমিউনিটি</a>
<a href="logout.php">↪ লগ আউট</a></nav>
</aside>
<div class="fs-admin-content">
<a class="fs-admin-mobile-return" href="fire_safety_job_prep_dashboard.php">← ড্যাশবোর্ডে ফিরুন</a>

<header><h1>Fire Safety BD — কমিউনিটি পোস্ট অনুমোদন</h1>
<a href="job_submission_review.php">← Job Approval</a></header><main>
<?php if ($error): ?><p class="error"><?= community_review_escape($error) ?></p><?php endif; ?>
<?php if ($saved): ?><p>সিদ্ধান্ত সংরক্ষিত হয়েছে।</p><?php endif; ?>
<h2>Pending পোস্ট (<?= count($pending) ?>)</h2>
<?php if (!$pending): ?><section>বর্তমানে অনুমোদনের অপেক্ষায় কোনো পোস্ট নেই।</section><?php endif; ?>
<?php foreach ($pending as $p): ?>
<article>
<div class="muted">#<?= (int)$p['id'] ?> · <?= community_review_escape($p['full_name']) ?> · <?= community_review_escape($p['created_at']) ?></div>
<p class="body"><?= community_review_escape($p['body']) ?></p>
<?php if ($p['image_path'] && preg_match('/^[a-f0-9]{32}\\.(jpg|png|webp)$/', $p['image_path'])): ?>
<img class="photo" alt="পোস্টের ছবি" src="uploads/community/<?= community_review_escape($p['image_path']) ?>">
<?php endif; ?>
<form method="post" onsubmit="return confirm('এই সিদ্ধান্ত নিশ্চিত করবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="post_id" value="<?= (int)$p['id'] ?>">
<button type="submit" name="decision" value="approve">✓ Approve & Publish</button>
<button type="submit" name="decision" value="reject" class="reject">✕ Reject</button>
</form></article>
<?php endforeach; ?>
<h2>সাম্প্রতিক পোস্ট</h2>
<?php foreach ($recent as $p): ?>
<section><strong>#<?= (int)$p['id'] ?> — <?= community_review_escape($p['status']) ?></strong>
<p class="body"><?= community_review_escape(function_exists('mb_strimwidth') ? mb_strimwidth((string)$p['body'],0,220,'…','UTF-8') : substr((string)$p['body'],0,220)) ?></p>
<?php if ($p['status'] === 'approved'): ?>
<form method="post" onsubmit="return confirm('পোস্টটি লুকাবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="post_id" value="<?= (int)$p['id'] ?>">
<button type="submit" name="decision" value="hide" class="hide">Hide post</button></form>
<?php endif; ?></section>
<?php endforeach; ?>
</main></div>
</div>
</body></html>
