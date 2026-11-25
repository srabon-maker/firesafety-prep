<?php
declare(strict_types=1);
require_once __DIR__ . '/admin_helpers.php';
start_secure_session();
require_admin();
require_once __DIR__ . '/community_admin_delete.php';
require_once __DIR__ . '/db.php';
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
header('Cache-Control: no-store');
function community_review_escape(mixed $value): string {
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
$error = '';
$saved = isset($_GET['saved']);
$deleteFlash=(string)($_SESSION['community_delete_flash']??'');
unset($_SESSION['community_delete_flash']);
$csrf = csrf_token();
$reportsReady = true;
try { $pdo->query('SELECT 1 FROM community_reports LIMIT 1'); }
catch (Throwable $ignored) { $reportsReady = false; }
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    verify_csrf();
    $id = filter_var($_POST['post_id'] ?? null, FILTER_VALIDATE_INT, ['options'=>['min_range'=>1]]);
    $decision = (string)($_POST['decision'] ?? '');
    try {
        if ($decision==='delete_post') {
            if (!$id || ($_POST['confirm_delete']??'')!=='1') throw new InvalidArgumentException('সঠিক পোস্ট ও মোছার অনুমোদন দিন।');
            $_SESSION['community_delete_flash']=community_admin_delete_post($pdo,$id);
            header('Location: community_review.php',true,303); exit;
        }
        if (in_array($decision, ['hide_comment','resolve_report','dismiss_report','hide_report_target'], true)) {
            if (!$reportsReady) throw new InvalidArgumentException('প্রথমে রিপোর্ট migration চালান।');
            $pdo->beginTransaction();
            if ($decision === 'hide_comment') {
                $commentId = filter_var($_POST['comment_id'] ?? null, FILTER_VALIDATE_INT, ['options'=>['min_range'=>1]]);
                if (!$commentId) throw new InvalidArgumentException('সঠিক মন্তব্য নির্বাচন করুন।');
                $q = $pdo->prepare("UPDATE community_comments SET status='hidden' WHERE id=? AND status='visible'");
                $q->execute([$commentId]);
                $q = $pdo->prepare("UPDATE community_reports SET status='resolved',reviewed_at=NOW() WHERE target_type='comment' AND target_id=? AND status='open'");
                $q->execute([$commentId]);
            } else {
                $reportId = filter_var($_POST['report_id'] ?? null, FILTER_VALIDATE_INT, ['options'=>['min_range'=>1]]);
                if (!$reportId) throw new InvalidArgumentException('সঠিক রিপোর্ট নির্বাচন করুন।');
                $q = $pdo->prepare("SELECT * FROM community_reports WHERE id=? AND status='open' FOR UPDATE");
                $q->execute([$reportId]);
                $report = $q->fetch(PDO::FETCH_ASSOC);
                if (!$report) throw new InvalidArgumentException('রিপোর্টটি ইতিমধ্যে পর্যালোচনা করা হয়েছে।');
                if ($decision === 'hide_report_target') {
                    $sql = $report['target_type'] === 'post'
                        ? "UPDATE community_posts SET status='hidden',moderated_at=NOW() WHERE id=? AND status IN ('pending','approved','rejected')"
                        : "UPDATE community_comments SET status='hidden' WHERE id=? AND status='visible'";
                    $q = $pdo->prepare($sql);
                    $q->execute([$report['target_id']]);
                    $q = $pdo->prepare("UPDATE community_reports SET status='resolved',reviewed_at=NOW() WHERE target_type=? AND target_id=? AND status='open'");
                    $q->execute([$report['target_type'],$report['target_id']]);
                } else {
                    $next = $decision === 'dismiss_report' ? 'dismissed' : 'resolved';
                    $q = $pdo->prepare('UPDATE community_reports SET status=?,reviewed_at=NOW() WHERE id=?');
                    $q->execute([$next,$reportId]);
                }
            }
            $pdo->commit();
            header('Location: community_review.php?saved=1');
            exit;
        }
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
$reports = $reportsReady ? $pdo->query(
    "SELECT r.*, u.full_name AS reporter, p.body AS post_body, p.status AS post_status,
            c.body AS comment_body, c.status AS comment_status
     FROM community_reports r JOIN users u ON u.id=r.reporter_id
     JOIN community_posts p ON p.id=r.post_id
     LEFT JOIN community_comments c ON r.target_type='comment' AND c.id=r.target_id
     WHERE r.status='open' ORDER BY r.id ASC LIMIT 100"
)->fetchAll(PDO::FETCH_ASSOC) : [];
$comments = $reportsReady ? $pdo->query(
    "SELECT c.id,c.post_id,c.body,c.created_at,u.full_name
     FROM community_comments c JOIN users u ON u.id=c.user_id
     JOIN community_posts p ON p.id=c.post_id
     WHERE c.status='visible' AND p.status='approved' ORDER BY c.id DESC LIMIT 100"
)->fetchAll(PDO::FETCH_ASSOC) : [];
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
button.reject{background:#666}button.hide{background:#a74a24}button.delete{background:#b42332}
</style></head><body>
<header><h1>Fire Safety BD — কমিউনিটি পোস্ট অনুমোদন</h1>
<a href="job_submission_review.php">← Job Approval</a></header><main>
<?php if ($error): ?><p class="error"><?= community_review_escape($error) ?></p><?php endif; ?>
<?php if ($deleteFlash!==''): ?><p role="status"><?=community_review_escape($deleteFlash)?></p><?php endif; ?>
<?php if ($saved): ?><p>সিদ্ধান্ত সংরক্ষিত হয়েছে।</p><?php endif; ?>
<h2>Pending পোস্ট (<?= count($pending) ?>)</h2>
<?php if (!$pending): ?><section>বর্তমানে অনুমোদনের অপেক্ষায় কোনো পোস্ট নেই।</section><?php endif; ?>
<?php foreach ($pending as $p): ?>
<article>
<div class="muted">#<?= (int)$p['id'] ?> · <?= community_review_escape($p['full_name']) ?> · <?= community_review_escape($p['created_at']) ?></div>
<p class="body"><?= community_review_escape($p['body']) ?></p>
<?php if ($p['image_path'] && preg_match('/^[a-f0-9]{32}\.(jpg|png|webp)$/', $p['image_path'])): ?>
<img class="photo" alt="পোস্টের ছবি" src="uploads/community/<?= community_review_escape($p['image_path']) ?>">
<?php endif; ?>
<form method="post" onsubmit="return confirm('এই সিদ্ধান্ত নিশ্চিত করবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="post_id" value="<?= (int)$p['id'] ?>">
<button type="submit" name="decision" value="approve">✓ Approve & Publish</button>
<button type="submit" name="decision" value="reject" class="reject">✕ Reject</button>
</form>
<form method="post" onsubmit="return confirm('পোস্ট, মন্তব্য, লাইক ও রিপোর্ট স্থায়ীভাবে মুছে যাবে। ফিরিয়ে আনা যাবে না। নিশ্চিত করবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="post_id" value="<?= (int)$p['id'] ?>">
<input type="hidden" name="confirm_delete" value="1">
<button type="submit" name="decision" value="delete_post" class="delete">✕ ডিলিট করুন</button>
</form>
</article>
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
<?php endif; ?>
<form method="post" onsubmit="return confirm('পোস্ট, মন্তব্য, লাইক ও রিপোর্ট স্থায়ীভাবে মুছে যাবে। ফিরিয়ে আনা যাবে না। নিশ্চিত করবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="post_id" value="<?= (int)$p['id'] ?>">
<input type="hidden" name="confirm_delete" value="1">
<button type="submit" name="decision" value="delete_post" class="delete">✕ ডিলিট করুন</button>
</form>
</section>
<?php endforeach; ?>
<h2>Community Reports (<?= count($reports) ?>)</h2>
<?php if (!$reportsReady): ?><section>নতুন Community Moderation SQL migration চালানোর পর রিপোর্ট দেখা যাবে।</section>
<?php elseif (!$reports): ?><section>কোনো অপেক্ষমাণ রিপোর্ট নেই।</section><?php endif; ?>
<?php foreach ($reports as $r): ?>
<article>
<div class="muted">Report #<?= (int)$r['id'] ?> · <?= community_review_escape($r['target_type']) ?> #<?= (int)$r['target_id'] ?> · Post #<?= (int)$r['post_id'] ?></div>
<p>কারণ: <strong><?= community_review_escape($r['reason']) ?></strong> · রিপোর্টকারী: <?= community_review_escape($r['reporter']) ?></p>
<p class="body"><?= community_review_escape($r['details']) ?></p>
<p class="body"><?= community_review_escape($r['target_type'] === 'comment' ? ($r['comment_body'] ?? '[removed]') : $r['post_body']) ?></p>
<p class="muted">Status: <?= community_review_escape($r['target_type'] === 'comment' ? ($r['comment_status'] ?? 'removed') : $r['post_status']) ?></p>
<form method="post" onsubmit="return confirm('এই সিদ্ধান্ত নিশ্চিত করবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="report_id" value="<?= (int)$r['id'] ?>">
<button name="decision" value="hide_report_target" class="hide">Hide content &amp; resolve</button>
<button name="decision" value="resolve_report">Resolve without hiding</button>
<button name="decision" value="dismiss_report" class="reject">Dismiss</button>
</form></article>
<?php endforeach; ?>
<h2>সাম্প্রতিক দৃশ্যমান মন্তব্য (<?= count($comments) ?>)</h2>
<?php foreach ($comments as $c): ?>
<article>
<div class="muted">Comment #<?= (int)$c['id'] ?> · Post #<?= (int)$c['post_id'] ?> · <?= community_review_escape($c['full_name']) ?></div>
<p class="body"><?= community_review_escape($c['body']) ?></p>
<form method="post" onsubmit="return confirm('মন্তব্যটি লুকাবেন?');">
<input type="hidden" name="csrf_token" value="<?= community_review_escape($csrf) ?>">
<input type="hidden" name="comment_id" value="<?= (int)$c['id'] ?>">
<button name="decision" value="hide_comment" class="hide">Hide comment</button>
</form></article>
<?php endforeach; ?>
</main></body></html>
