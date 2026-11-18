<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
require_once __DIR__ . '/../../db.php';

const COMMUNITY_IMAGE_BASE = 'https://fire.manobikishwarganj.com/uploads/community/';
const COMMUNITY_MAX_IMAGE = 5242880; // 5 MiB
const COMMUNITY_MAX_TEXT = 3000;

function community_reply(int $status, array $body): void {
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function community_auth(PDO $pdo, bool $required = true): ?int {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!$header && function_exists('getallheaders')) {
        foreach (getallheaders() as $key => $value) {
            if (strcasecmp($key, 'Authorization') === 0) { $header = (string)$value; break; }
        }
    }
    if (!preg_match('/^Bearer\\s+([a-f0-9]{64})$/i', trim((string)$header), $m)) {
        if ($required) community_reply(401, ['success'=>false,'message'=>'পোস্ট করতে লগইন করুন।']);
        return null;
    }
    $q = $pdo->prepare('SELECT u.id FROM auth_sessions s JOIN users u ON u.id=s.user_id
                        WHERE s.token_hash=? AND s.expires_at>NOW() LIMIT 1');
    $q->execute([hash('sha256', $m[1])]);
    $id = $q->fetchColumn();
    if (!$id && $required) community_reply(401, ['success'=>false,'message'=>'সেশন শেষ হয়েছে। আবার লগইন করুন।']);
    return $id ? (int)$id : null;
}
function community_input(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || strlen($raw) > 8192) community_reply(413, ['success'=>false,'message'=>'অনুরোধ বড়।']);
    $data = json_decode($raw, true);
    if (!is_array($data)) community_reply(400, ['success'=>false,'message'=>'সঠিক JSON দিন।']);
    return $data;
}
function community_text(mixed $value, int $limit, bool $allowEmpty = false): string {
    if (!is_string($value)) community_reply(422, ['success'=>false,'message'=>'সঠিক লেখা দিন।']);
    $value = trim($value);
    $size = function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);
    if ($size > $limit || (!$allowEmpty && $size === 0)) {
        community_reply(422, ['success'=>false,'message'=>'লেখার দৈর্ঘ্য সঠিক নয়।']);
    }
    return $value;
}
function community_id(mixed $value): int {
    if (!is_scalar($value) || !preg_match('/^[1-9][0-9]*$/', (string)$value) ||
        (int)$value < 1) community_reply(422, ['success'=>false,'message'=>'সঠিক পোস্ট নির্বাচন করুন।']);
    return (int)$value;
}
function community_image_url(?string $path): ?string {
    if (!$path || !preg_match('/^[a-f0-9]{32}\\.(jpg|png|webp)$/', $path)) return null;
    return COMMUNITY_IMAGE_BASE . $path;
}
function community_upload_image(): ?string {
    if (!isset($_FILES['image']) || $_FILES['image']['error'] === UPLOAD_ERR_NO_FILE) return null;
    $file = $_FILES['image'];
    if (!is_array($file) || ($file['error'] ?? null) !== UPLOAD_ERR_OK ||
        !is_uploaded_file((string)($file['tmp_name'] ?? ''))) {
        community_reply(422, ['success'=>false,'message'=>'ছবি আপলোড করা যায়নি।']);
    }
    $size = (int)($file['size'] ?? 0);
    if ($size < 1 || $size > COMMUNITY_MAX_IMAGE) {
        community_reply(413, ['success'=>false,'message'=>'ছবি সর্বোচ্চ ৫ MB হতে পারবে।']);
    }
    $tmp = (string)$file['tmp_name'];
    $info = @getimagesize($tmp);
    if ($info === false || $info[0] < 1 || $info[1] < 1 ||
        $info[0] > 6000 || $info[1] > 6000) {
        community_reply(422, ['success'=>false,'message'=>'সঠিক ছবি নির্বাচন করুন।']);
    }
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($tmp);
    $ext = match ($mime) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        default => null
    };
    if ($ext === null || !in_array($info['mime'] ?? '', [$mime], true)) {
        community_reply(422, ['success'=>false,'message'=>'শুধু JPG, PNG বা WebP ছবি দিন।']);
    }
    $folder = __DIR__ . '/../../uploads/community';
    if (!is_dir($folder) && !mkdir($folder, 0755, true) && !is_dir($folder)) {
        throw new RuntimeException('Upload folder unavailable');
    }
    $name = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($tmp, $folder . '/' . $name)) {
        throw new RuntimeException('Image storage failed');
    }
    chmod($folder . '/' . $name, 0644);
    return $name;
}

try {
    if (!isset($pdo) || !($pdo instanceof PDO)) throw new RuntimeException('Database unavailable');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $action = (string)($_GET['action'] ?? 'feed');
    if ($method === 'GET' && $action === 'feed') {
        $userId = community_auth($pdo, false);
        $sort = ($_GET['sort'] ?? '') === 'popular' ? 'popular' : 'latest';
        $order = $sort === 'popular' ? 'likes_count DESC, p.created_at DESC' : 'p.created_at DESC';
        $stmt = $pdo->prepare(
            "SELECT p.id, p.body, p.image_path, p.created_at,
                    u.full_name AS author, u.profile_photo AS author_photo,
                    (SELECT COUNT(*) FROM community_post_likes l WHERE l.post_id=p.id) AS likes_count,
                    (SELECT COUNT(*) FROM community_comments c WHERE c.post_id=p.id AND c.status='visible') AS comments_count,
                    (SELECT COUNT(*) FROM community_post_likes mine WHERE mine.post_id=p.id AND mine.user_id=?) AS liked
             FROM community_posts p JOIN users u ON u.id=p.user_id
             WHERE p.status='approved' ORDER BY $order LIMIT 50"
        );
        $stmt->execute([$userId ?? 0]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as &$row) {
            $row['id'] = (int)$row['id'];
            $row['likes_count'] = (int)$row['likes_count'];
            $row['comments_count'] = (int)$row['comments_count'];
            $row['liked'] = (int)$row['liked'] > 0;
            $row['image_url'] = community_image_url($row['image_path']);
            unset($row['image_path']);
        }
        unset($row);
        community_reply(200, ['success'=>true,'data'=>$rows]);
    }
    if ($method === 'GET' && $action === 'comments') {
        $postId = community_id($_GET['post_id'] ?? null);
        $check = $pdo->prepare("SELECT id FROM community_posts WHERE id=? AND status='approved'");
        $check->execute([$postId]);
        if (!$check->fetchColumn()) community_reply(404, ['success'=>false,'message'=>'পোস্ট পাওয়া যায়নি।']);
        $q = $pdo->prepare(
            "SELECT c.id, c.body AS text, c.created_at, u.full_name AS author
             FROM community_comments c JOIN users u ON u.id=c.user_id
             WHERE c.post_id=? AND c.status='visible' ORDER BY c.id ASC LIMIT 100"
        );
        $q->execute([$postId]);
        community_reply(200, ['success'=>true,'data'=>$q->fetchAll(PDO::FETCH_ASSOC)]);
    }
    if ($method === 'POST' && $action === 'create') {
        $userId = community_auth($pdo);
        $body = community_text($_POST['body'] ?? '', COMMUNITY_MAX_TEXT, true);
        if ($body === '' && (!isset($_FILES['image']) ||
            ($_FILES['image']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE)) {
            community_reply(422, ['success'=>false,'message'=>'লেখা অথবা ছবি যোগ করুন।']);
        }
        $rate = $pdo->prepare('SELECT COUNT(*) FROM community_posts WHERE user_id=? AND created_at >= NOW()-INTERVAL 1 DAY');
        $rate->execute([$userId]);
        if ((int)$rate->fetchColumn() >= 5) {
            community_reply(429, ['success'=>false,'message'=>'২৪ ঘণ্টায় সর্বোচ্চ ৫টি পোস্ট করা যাবে।']);
        }
        $image = community_upload_image();
        try {
            $stmt = $pdo->prepare("INSERT INTO community_posts (user_id, title, body, image_path, status)
                                    VALUES (?, NULL, ?, ?, 'pending')");
            $stmt->execute([$userId, $body, $image]);
        } catch (Throwable $e) {
            if ($image !== null) @unlink(__DIR__ . '/../../uploads/community/' . $image);
            throw $e;
        }
        community_reply(201, ['success'=>true,'message'=>'পোস্ট জমা হয়েছে। অ্যাডমিন অনুমোদনের পর দেখা যাবে।',
                              'post_id'=>(int)$pdo->lastInsertId(), 'status'=>'pending']);
    }
    if ($method === 'POST' && $action === 'like') {
        $userId = community_auth($pdo);
        $data = community_input();
        $postId = community_id($data['post_id'] ?? null);
        $check = $pdo->prepare("SELECT id FROM community_posts WHERE id=? AND status='approved'");
        $check->execute([$postId]);
        if (!$check->fetchColumn()) community_reply(404, ['success'=>false,'message'=>'পোস্ট পাওয়া যায়নি।']);
        $stmt = $pdo->prepare('DELETE FROM community_post_likes WHERE post_id=? AND user_id=?');
        $stmt->execute([$postId, $userId]);
        $liked = false;
        if ($stmt->rowCount() === 0) {
            $stmt = $pdo->prepare('INSERT IGNORE INTO community_post_likes (post_id,user_id) VALUES (?,?)');
            $stmt->execute([$postId, $userId]);
            $liked = true;
        }
        $count = $pdo->prepare('SELECT COUNT(*) FROM community_post_likes WHERE post_id=?');
        $count->execute([$postId]);
        community_reply(200, ['success'=>true,'liked'=>$liked,'likes_count'=>(int)$count->fetchColumn()]);
    }
    if ($method === 'POST' && $action === 'comment') {
        $userId = community_auth($pdo);
        $data = community_input();
        $postId = community_id($data['post_id'] ?? null);
        $body = community_text($data['text'] ?? null, 1000);
        $check = $pdo->prepare("SELECT id FROM community_posts WHERE id=? AND status='approved'");
        $check->execute([$postId]);
        if (!$check->fetchColumn()) community_reply(404, ['success'=>false,'message'=>'পোস্ট পাওয়া যায়নি।']);
        $rate = $pdo->prepare('SELECT COUNT(*) FROM community_comments WHERE user_id=? AND created_at >= NOW()-INTERVAL 1 DAY');
        $rate->execute([$userId]);
        if ((int)$rate->fetchColumn() >= 30) {
            community_reply(429, ['success'=>false,'message'=>'২৪ ঘণ্টায় সর্বোচ্চ ৩০টি মন্তব্য করা যাবে।']);
        }
        $stmt = $pdo->prepare("INSERT INTO community_comments (post_id,user_id,body,status) VALUES (?, ?, ?, 'visible')");
        $stmt->execute([$postId, $userId, $body]);
        community_reply(201, ['success'=>true,'message'=>'মন্তব্য প্রকাশিত হয়েছে।']);
    }
    header('Allow: GET, POST');
    community_reply(405, ['success'=>false,'message'=>'Unsupported request.']);
} catch (PDOException $e) {
    error_log('Community database error: ' . $e->getMessage());
    community_reply(500, ['success'=>false,'message'=>'কমিউনিটি সার্ভারে সমস্যা হয়েছে।']);
} catch (Throwable $e) {
    error_log('Community error: ' . $e->getMessage());
    community_reply(500, ['success'=>false,'message'=>'অনুরোধটি সম্পন্ন হয়নি।']);
}
