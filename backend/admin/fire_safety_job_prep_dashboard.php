<?php
require_once __DIR__ . '/admin_helpers.php';

start_secure_session();
require_admin();

require_once __DIR__ . '/db.php';

if (!isset($pdo) || !($pdo instanceof PDO)) {
    http_response_code(500);
    exit('ডাটাবেজ সংযোগ পাওয়া যাচ্ছে না।');
}

$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

/* ---------- MARKETPLACE: INTEGRATED INTO THE EXISTING ADMIN DASHBOARD ---------- */
$isMarketplace = (($_GET['section'] ?? '') === 'marketplace');
$isCommunity = (($_GET['section'] ?? '') === 'community');
if ($isMarketplace) {
$tabs = ['products','services','categories','orders','requests'];
$tab = (string)($_GET['tab'] ?? 'products');
if (!in_array($tab,$tabs,true)) $tab = 'products';
$token = csrf_token();
$error = '';
function mk_strlen(string $v): int {
    if (function_exists('mb_strlen')) return mb_strlen($v, 'UTF-8');
    return preg_match_all('/./us', $v) ?: 0;
}
function mk_string(mixed $v, int $max, string $name, bool $required = true): string {
    if (!is_string($v)) throw new InvalidArgumentException("সঠিক তথ্য দিন: $name");
    $v = trim($v);
    if (($required && $v === '') || mk_strlen($v) > $max) throw new InvalidArgumentException("সঠিক তথ্য দিন: $name");
    return $v;
}
function mk_id(mixed $v, bool $optional = false): ?int {
    if ($optional && ($v === '' || $v === null)) return null;
    $id = filter_var($v,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if ($id === false) throw new InvalidArgumentException('সঠিক ক্রমিক নম্বর দিন');
    return $id;
}
function mk_money(mixed $v, bool $optional = false): ?string {
    if ($optional && ($v === '' || $v === null)) return null;
    if (!is_scalar($v) || !preg_match('/^\d{1,10}(?:\.\d{1,2})?$/D',(string)$v)) throw new InvalidArgumentException('সঠিক মূল্য লিখুন');
    return number_format((float)$v,2,'.','');
}
function mk_enum(mixed $v, array $allowed): string {
    if (!is_string($v) || !in_array($v,$allowed,true)) throw new InvalidArgumentException('সঠিক অবস্থা বা ধরন নির্বাচন করুন');
    return $v;
}
/**
 * Admin-only image upload. A new file gets a random name and a public HTTPS URL.
 * The uploaded file path is returned by reference so DB errors can remove it.
 */
function mk_upload_image(?array $file, ?string &$newImagePath): ?string {
    if ($file === null || ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) return null;
    if (!isset($file['error']) || is_array($file['error']) || $file['error'] !== UPLOAD_ERR_OK) {
        $error = $file['error'] ?? -1;
        if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
            throw new InvalidArgumentException('ছবিটি সার্ভারের অনুমোদিত সীমার চেয়ে বড়। সর্বোচ্চ ৫ মেগাবাইটের ছবি দিন।');
        }
        throw new InvalidArgumentException('ছবি আপলোড করা যায়নি। আবার চেষ্টা করুন।');
    }
    $temp = $file['tmp_name'] ?? null;
    $size = $file['size'] ?? null;
    if (!is_string($temp) || !is_uploaded_file($temp) || !is_int($size) || $size < 1 || $size > 5 * 1024 * 1024) {
        throw new InvalidArgumentException('শুধু সর্বোচ্চ ৫ মেগাবাইটের ছবি আপলোড করুন।');
    }
    if (!function_exists('finfo_open') || !function_exists('getimagesize')) {
        throw new RuntimeException('সার্ভারে ছবি যাচাইয়ের প্রয়োজনীয় PHP সুবিধা চালু নেই।');
    }
    $mimeInfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $mimeInfo->file($temp);
    $types = ['image/jpeg'=>['jpg', IMAGETYPE_JPEG], 'image/png'=>['png', IMAGETYPE_PNG], 'image/webp'=>['webp', IMAGETYPE_WEBP]];
    if (!is_string($mime) || !isset($types[$mime])) {
        throw new InvalidArgumentException('শুধু JPG, PNG অথবা WEBP ছবি নির্বাচন করুন।');
    }
    $dimensions = @getimagesize($temp);
    if ($dimensions === false || ($dimensions[2] ?? 0) !== $types[$mime][1]) {
        throw new InvalidArgumentException('ফাইলটি সঠিক ছবি নয়। অন্য ছবি নির্বাচন করুন।');
    }
    $width = (int)$dimensions[0];
    $height = (int)$dimensions[1];
    if ($width < 1 || $height < 1 || $width > 6000 || $height > 6000 || $width * $height > 20000000) {
        throw new InvalidArgumentException('ছবির আকার অনেক বড়। ছোট ছবি ব্যবহার করুন।');
    }
    $directory = __DIR__ . '/uploads/marketplace';
    if (!is_dir($directory) || !is_writable($directory)) {
        throw new RuntimeException('ছবি রাখার ফোল্ডার পাওয়া যায়নি বা লেখার অনুমতি নেই: uploads/marketplace');
    }
    $filename = bin2hex(random_bytes(16)) . '.' . $types[$mime][0];
    $destination = $directory . '/' . $filename;
    if (!move_uploaded_file($temp, $destination)) {
        throw new RuntimeException('ছবি সার্ভারে সংরক্ষণ করা যায়নি। ফোল্ডারের অনুমতি পরীক্ষা করুন।');
    }
    $newImagePath = $destination;
    @chmod($destination, 0644);
    return 'https://fire.manobikishwarganj.com/uploads/marketplace/' . $filename;
}
function mk_existing_image(PDO $pdo, string $table, ?int $id): ?string {
    if ($id === null) return null;
    // Only the two fixed marketplace tables may be queried.
    if (!in_array($table, ['market_products','market_services'], true)) {
        throw new LogicException('অননুমোদিত তথ্যের ধরন');
    }
    $stmt = $pdo->prepare("SELECT image_url FROM `$table` WHERE id=?");
    $stmt->execute([$id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row === false) throw new InvalidArgumentException('সম্পাদনার জন্য পণ্য বা সেবাটি পাওয়া যায়নি।');
    return $row['image_url'] === null ? null : (string)$row['image_url'];
}
/**
 * Create a unique slug on first save; never change it when editing an existing row.
 * Bangla-only names get a safe English prefix plus a random suffix.
 * The existing unique database index remains the final concurrency safeguard.
 */
function mk_auto_slug(PDO $pdo, string $table, string $name, ?int $id): string {
    $prefixes = [
        'market_products' => 'product',
        'market_services' => 'service',
        'market_categories' => 'category',
    ];
    if (!isset($prefixes[$table])) throw new LogicException('অননুমোদিত তথ্যের ধরন');

    if ($id !== null) {
        $stmt = $pdo->prepare("SELECT slug FROM `$table` WHERE id=?");
        $stmt->execute([$id]);
        $existing = $stmt->fetchColumn();
        if ($existing === false) throw new InvalidArgumentException('সম্পাদনার তথ্য পাওয়া যায়নি।');
        return (string)$existing;
    }

    // Use readable English words when present; Bengali names use a safe prefix.
    $base = strtolower($name);
    $base = trim((string)preg_replace('/[^a-z0-9]+/', '-', $base), '-');
    if ($base === '') $base = $prefixes[$table];
    $base = substr($base, 0, 140);
    $base = rtrim($base, '-');
    $check = $pdo->prepare("SELECT 1 FROM `$table` WHERE slug=? LIMIT 1");
    for ($attempt = 0; $attempt < 10; $attempt++) {
        $candidate = $base . '-' . bin2hex(random_bytes(8));
        $check->execute([$candidate]);
        if ($check->fetchColumn() === false) return $candidate;
    }
    throw new RuntimeException('নতুন স্লাগ তৈরি করা যায়নি। আবার চেষ্টা করুন।');
}
function mk_flash(string $tab): never {
    header('Location: fire_safety_job_prep_dashboard.php?section=marketplace&tab=' . urlencode($tab) . '&saved=1',true,303);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    verify_csrf();
    $newImagePath = null;
    try {
        $action = (string)($_POST['action'] ?? '');
        $id = mk_id($_POST['id'] ?? null, true);
        if ($action === 'save_product') {
            $name = mk_string($_POST['name'] ?? null,200,'name');
            $slug = mk_auto_slug($pdo, 'market_products', $name, $id);
            $category = mk_id($_POST['category_id'] ?? null,true);
            $sku = mk_string($_POST['sku'] ?? '',100,'SKU',false);
            $description = mk_string($_POST['description'] ?? '',50000,'description',false);
            $price = mk_money($_POST['price'] ?? null);
            $compare = mk_money($_POST['compare_price'] ?? '',true);
            $stock = filter_var($_POST['stock_quantity'] ?? null,FILTER_VALIDATE_INT,['options'=>['min_range'=>0,'max_range'=>100000000]]);
            if ($stock === false) throw new InvalidArgumentException('সঠিক মজুতের পরিমাণ লিখুন');
            $previousImage = mk_existing_image($pdo, 'market_products', $id);
            $uploadedImage = mk_upload_image($_FILES['image_file'] ?? null, $newImagePath);
            $image = $uploadedImage ?? $previousImage;
            $status = mk_enum($_POST['status'] ?? '', ['draft','published','archived']);
            $featured = isset($_POST['is_featured']) ? 1 : 0;
            $values = [$category,$name,$slug,$sku === '' ? null : $sku,$description,$price,$compare,$stock,$image,$status,$featured];
            if ($id === null) {
                $stmt = $pdo->prepare('INSERT INTO market_products (category_id,name,slug,sku,description,price,compare_price,stock_quantity,image_url,status,is_featured) VALUES (?,?,?,?,?,?,?,?,?,?,?)');
            } else {
                $stmt = $pdo->prepare('UPDATE market_products SET category_id=?,name=?,slug=?,sku=?,description=?,price=?,compare_price=?,stock_quantity=?,image_url=?,status=?,is_featured=? WHERE id=?');
                $values[] = $id;
            }
            $stmt->execute($values);
            mk_flash('products');
        }
        if ($action === 'save_service') {
            $name = mk_string($_POST['name'] ?? null,200,'name');
            $slug = mk_auto_slug($pdo, 'market_services', $name, $id);
            $category = mk_id($_POST['category_id'] ?? null,true);
            $description = mk_string($_POST['description'] ?? '',50000,'description',false);
            $pricing = mk_enum($_POST['pricing_type'] ?? '', ['fixed','starting','quote']);
            $price = mk_money($_POST['price'] ?? '',true);
            if ($pricing === 'fixed' && $price === null) throw new InvalidArgumentException('নির্ধারিত মূল্যের সেবায় মূল্য লিখতে হবে');
            $previousImage = mk_existing_image($pdo, 'market_services', $id);
            $uploadedImage = mk_upload_image($_FILES['image_file'] ?? null, $newImagePath);
            $image = $uploadedImage ?? $previousImage;
            $status = mk_enum($_POST['status'] ?? '', ['draft','published','archived']);
            $featured = isset($_POST['is_featured']) ? 1 : 0;
            $values = [$category,$name,$slug,$description,$pricing,$price,$image,$status,$featured];
            if ($id === null) $stmt = $pdo->prepare('INSERT INTO market_services (category_id,name,slug,description,pricing_type,price,image_url,status,is_featured) VALUES (?,?,?,?,?,?,?,?,?)');
            else { $stmt = $pdo->prepare('UPDATE market_services SET category_id=?,name=?,slug=?,description=?,pricing_type=?,price=?,image_url=?,status=?,is_featured=? WHERE id=?'); $values[] = $id; }
            $stmt->execute($values);
            mk_flash('services');
        }
        if ($action === 'save_category') {
            $name = mk_string($_POST['name'] ?? null,150,'name');
            $slug = mk_auto_slug($pdo, 'market_categories', $name, $id);
            $type = mk_enum($_POST['category_type'] ?? '', ['product','service','both']);
            $description = mk_string($_POST['description'] ?? '',10000,'description',false);
            $sort = filter_var($_POST['sort_order'] ?? 0,FILTER_VALIDATE_INT);
            if ($sort === false) throw new InvalidArgumentException('সঠিক প্রদর্শনের ক্রম লিখুন');
            $active = isset($_POST['is_active']) ? 1 : 0;
            $values = [$name,$slug,$type,$description,$sort,$active];
            if ($id === null) $stmt = $pdo->prepare('INSERT INTO market_categories (name,slug,category_type,description,sort_order,is_active) VALUES (?,?,?,?,?,?)');
            else { $stmt = $pdo->prepare('UPDATE market_categories SET name=?,slug=?,category_type=?,description=?,sort_order=?,is_active=? WHERE id=?'); $values[] = $id; }
            $stmt->execute($values);
            mk_flash('categories');
        }
        if ($action === 'order_status') {
            if ($id === null) throw new InvalidArgumentException('অর্ডার নম্বর প্রয়োজন');
            $status = mk_enum($_POST['order_status'] ?? '', ['pending','confirmed','processing','shipped','delivered','cancelled']);
            // Do not automatically restock on cancellation: admin must reconcile stock separately.
            $stmt = $pdo->prepare('UPDATE market_orders SET order_status=? WHERE id=?');
            $stmt->execute([$status,$id]);
            mk_flash('orders');
        }
        if ($action === 'request_status') {
            if ($id === null) throw new InvalidArgumentException('অনুরোধ নম্বর প্রয়োজন');
            $status = mk_enum($_POST['status'] ?? '', ['pending','reviewing','approved','completed','rejected','cancelled']);
            $stmt = $pdo->prepare('UPDATE market_service_requests SET status=? WHERE id=?');
            $stmt->execute([$status,$id]);
            mk_flash('requests');
        }
        throw new InvalidArgumentException('অনুমোদিত কাজ নির্বাচন করুন');
    } catch (InvalidArgumentException $e) { if ($newImagePath !== null) @unlink($newImagePath); $error = $e->getMessage(); }
    catch (PDOException $e) { if ($newImagePath !== null) @unlink($newImagePath); error_log('Marketplace admin DB: '.$e->getMessage()); $error = 'ডাটাবেজে তথ্য সংরক্ষণ করা যায়নি। একই পণ্যের কোড আগে আছে কি না দেখুন।'; }
    catch (Throwable $e) { if ($newImagePath !== null) @unlink($newImagePath); error_log('Marketplace admin: '.$e->getMessage()); $error = 'পরিবর্তন সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।'; }
}

$categories = $pdo->query('SELECT id,name,category_type FROM market_categories ORDER BY name')->fetchAll();
$edit = null;
if (isset($_GET['edit']) && in_array($tab,['products','services','categories'],true)) {
    $editId = filter_var($_GET['edit'],FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if ($editId !== false) {
        $table = ['products'=>'market_products','services'=>'market_services','categories'=>'market_categories'][$tab];
        $stmt = $pdo->prepare("SELECT * FROM $table WHERE id=?");
        $stmt->execute([$editId]);
        $edit = $stmt->fetch() ?: null;
    }
}
function field(array|null $edit,string $name,string $fallback = ''): string { return h((string)($edit[$name] ?? $fallback)); }
function selected(array|null $edit,string $name,string $value,string $default = ''): string { return (string)($edit[$name] ?? $default) === $value ? ' selected' : ''; }
function checked(array|null $edit,string $name,bool $default = false): string { return (int)($edit[$name] ?? ($default ? 1 : 0)) === 1 ? ' checked' : ''; }
function mk_bn_label(?string $value): string {
    $labels = [
        'draft'=>'খসড়া', 'published'=>'প্রকাশিত', 'archived'=>'আর্কাইভ',
        'product'=>'পণ্য', 'service'=>'সেবা', 'both'=>'উভয়',
        'fixed'=>'নির্ধারিত মূল্য', 'starting'=>'শুরু মূল্য', 'quote'=>'আলোচনা সাপেক্ষে',
        'pending'=>'অপেক্ষমাণ', 'confirmed'=>'নিশ্চিত', 'processing'=>'প্রস্তুত হচ্ছে',
        'shipped'=>'পাঠানো হয়েছে', 'delivered'=>'ডেলিভারি সম্পন্ন', 'cancelled'=>'বাতিল',
        'reviewing'=>'যাচাই চলছে', 'approved'=>'অনুমোদিত', 'completed'=>'সম্পন্ন',
        'rejected'=>'প্রত্যাখ্যাত', 'cod'=>'ক্যাশ অন ডেলিভারি', 'paid'=>'পরিশোধিত',
        'refunded'=>'ফেরত দেওয়া হয়েছে'
    ];
    return $labels[$value ?? ''] ?? ($value ?? '—');
}
function mk_bn_num(mixed $value): string {
    return strtr((string)$value, ['0'=>'০','1'=>'১','2'=>'২','3'=>'৩','4'=>'৪','5'=>'৫','6'=>'৬','7'=>'৭','8'=>'৮','9'=>'৯']);
}
$marketStats = ['products'=>0, 'services'=>0, 'categories'=>0, 'orders'=>0, 'requests'=>0];
foreach (['products'=>'market_products','services'=>'market_services','categories'=>'market_categories','orders'=>'market_orders','requests'=>'market_service_requests'] as $statKey => $statTable) {
    try { $marketStats[$statKey] = (int)$pdo->query("SELECT COUNT(*) FROM `$statTable`")->fetchColumn(); }
    catch (Throwable $e) { error_log('Marketplace count: '.$e->getMessage()); }
}

}


/* ---------- DATABASE HELPERS ---------- */

if (!function_exists('hasTable')) {
    function hasTable(PDO $pdo, string $name): bool {
        // SHOW TABLES LIKE ? is not reliably supported by all MySQL/PDO
        // prepared-statement configurations. Test table accessibility directly.
        if (!preg_match('/^[a-zA-Z0-9_]+$/D', $name)) {
            return false;
        }
        try {
            // LIMIT 0 validates the table without fetching any user data.
            $pdo->query('SELECT 1 FROM `' . $name . '` LIMIT 0');
            return true;
        } catch (Throwable $e) {
            error_log('Admin dashboard table check (' . $name . '): ' . $e->getMessage());
            return false;
        }
    }
}

if (!function_exists('optionalCount')) {
    function optionalCount(PDO $pdo, array $tables): ?int {
        foreach ($tables as $table) {
            if (hasTable($pdo, $table)) {
                try {
                    return (int)$pdo->query(
                        "SELECT COUNT(*) FROM `$table`"
                    )->fetchColumn();
                } catch (Throwable $e) {
                    return null;
                }
            }
        }
        return null;
    }
}

/* ---------- COMMUNITY: INTEGRATED ADMIN MODERATION ---------- */
$communityError = '';
$communitySaved = isset($_GET['saved']);
$communityDeleteFlash = '';
$communityTab = (($_GET['view'] ?? '') === 'comments') ? 'comments' : 'posts';
$communityStatus = is_string($_GET['status'] ?? null) ? $_GET['status'] : 'all';
$communityAllowedStatuses = $communityTab === 'posts'
    ? ['all', 'pending', 'approved', 'rejected', 'hidden']
    : ['all', 'visible', 'hidden', 'deleted'];
if (!in_array($communityStatus, $communityAllowedStatuses, true)) $communityStatus = 'all';
$communitySearch = is_string($_GET['q'] ?? null) ? trim($_GET['q']) : '';
if (function_exists('mb_substr')) $communitySearch = mb_substr($communitySearch, 0, 80, 'UTF-8');
else $communitySearch = substr($communitySearch, 0, 160);
$communityPage = filter_var($_GET['page'] ?? 1, FILTER_VALIDATE_INT, ['options' => ['min_range'=>1, 'max_range'=>10000]]);
if ($communityPage === false) $communityPage = 1;
$communityPerPage = 20;
$communityRows = [];
$communityTotalResults = 0;
$communityStats = ['total'=>0, 'pending'=>0, 'approved'=>0, 'rejected'=>0, 'hidden'=>0];
$communityCommentStats = ['total'=>0, 'visible'=>0, 'hidden'=>0, 'deleted'=>0];
$communityHasPosts = false;
$communityHasComments = false;
$communityHasImages = false;
$communityToken = null;

if ($isCommunity) {
    require_once __DIR__.'/community_admin_delete.php';
    $communityDeleteFlash = (string)($_SESSION['community_delete_flash']??'');
    unset($_SESSION['community_delete_flash']);
    header('Cache-Control: no-store, private');
    $communityToken = csrf_token();
    $communityHasPosts = hasTable($pdo, 'community_posts');
    $communityHasComments = hasTable($pdo, 'community_comments');
    if ($communityHasPosts) {
        try {
            $column = $pdo->query("SHOW COLUMNS FROM community_posts LIKE 'image_path'");
            $communityHasImages = (bool)$column->fetch(PDO::FETCH_ASSOC);
        } catch (Throwable $e) {
            error_log('Community image column check: ' . $e->getMessage());
        }
    }

    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
        verify_csrf();
        try {
            $action = (string)($_POST['community_action'] ?? '');
            $id = filter_var($_POST['item_id'] ?? null, FILTER_VALIDATE_INT, ['options'=>['min_range'=>1]]);
            if ($id === false || $id === null) throw new InvalidArgumentException('সঠিক পোস্ট বা মন্তব্য নির্বাচন করুন।');
            if ($action==='delete_post' && $communityTab==='posts' && $communityHasPosts) {
                if (($_POST['confirm_delete']??'')!=='1') throw new InvalidArgumentException('পোস্ট মোছার অনুমোদন দিন।');
                $_SESSION['community_delete_flash']=community_admin_delete_post($pdo,$id);
                header('Location: fire_safety_job_prep_dashboard.php?section=community&view=posts',true,303);
                exit;
            }
            $postTransitions = [
                'approve'=>['pending', 'approved'],
                'reject'=>['pending', 'rejected'],
                'hide_post'=>['approved', 'hidden'],
                'restore_post'=>['hidden', 'approved'],
            ];
            $commentTransitions = [
                'hide_comment'=>['visible', 'hidden'],
                'restore_comment'=>['hidden', 'visible'],
            ];
            if (isset($postTransitions[$action]) && $communityHasPosts) {
                [$from, $to] = $postTransitions[$action];
                $table = 'community_posts';
                $column = 'id';
            } elseif (isset($commentTransitions[$action]) && $communityHasComments) {
                [$from, $to] = $commentTransitions[$action];
                $table = 'community_comments';
                $column = 'id';
            } else {
                throw new InvalidArgumentException('এই কাজটি অনুমোদিত নয়।');
            }
            $pdo->beginTransaction();
            $stmt = $pdo->prepare("SELECT status FROM `$table` WHERE `$column`=? FOR UPDATE");
            $stmt->execute([$id]);
            $current = $stmt->fetchColumn();
            if ($current !== $from) throw new InvalidArgumentException('পোস্ট বা মন্তব্যটির অবস্থা ইতিমধ্যে পরিবর্তিত হয়েছে। পেজ রিফ্রেশ করুন।');
            $stmt = $pdo->prepare("UPDATE `$table` SET status=?, moderated_at=NOW() WHERE `$column`=? AND status=?");
            $stmt->execute([$to, $id, $from]);
            if ($stmt->rowCount() !== 1) throw new RuntimeException('Community moderation update did not affect one row');
            $pdo->commit();
            $redirectView = isset($postTransitions[$action]) ? 'posts' : 'comments';
            header('Location: fire_safety_job_prep_dashboard.php?section=community&view=' . $redirectView . '&saved=1', true, 303);
            exit;
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            $communityError = $e instanceof InvalidArgumentException ? $e->getMessage() : 'পরিবর্তন সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';
            if (!($e instanceof InvalidArgumentException)) error_log('Community moderation: ' . $e->getMessage());
        }
    }

    if ($communityHasPosts) {
        try {
            foreach ($pdo->query('SELECT status, COUNT(*) AS total FROM community_posts GROUP BY status')->fetchAll(PDO::FETCH_ASSOC) as $stat) {
                if (isset($communityStats[$stat['status']])) $communityStats[$stat['status']] = (int)$stat['total'];
                $communityStats['total'] += (int)$stat['total'];
            }
            if ($communityHasComments) {
                foreach ($pdo->query('SELECT status, COUNT(*) AS total FROM community_comments GROUP BY status')->fetchAll(PDO::FETCH_ASSOC) as $stat) {
                    if (isset($communityCommentStats[$stat['status']])) $communityCommentStats[$stat['status']] = (int)$stat['total'];
                    $communityCommentStats['total'] += (int)$stat['total'];
                }
            }
            if ($communityTab === 'posts' || $communityHasComments) {
                $where = [];
                $params = [];
                if ($communityStatus !== 'all') {
                    $where[] = 'p.status = :status';
                    $params[':status'] = $communityStatus;
                }
                if ($communitySearch !== '') {
                    $where[] = '(p.body LIKE :search OR u.full_name LIKE :name OR u.email LIKE :email)';
                    $searchTerm = '%' . $communitySearch . '%';
                    $params[':search'] = $searchTerm;
                    $params[':name'] = $searchTerm;
                    $params[':email'] = $searchTerm;
                }
                $whereSql = $where ? ' WHERE ' . implode(' AND ', $where) : '';
                if ($communityTab === 'posts') {
                    $fromSql = ' FROM community_posts p LEFT JOIN users u ON u.id=p.user_id';
                    $fields = 'p.id, p.body, p.status, p.created_at, u.full_name, u.email' . ($communityHasImages ? ', p.image_path' : '');
                } else {
                    $fromSql = ' FROM community_comments p LEFT JOIN users u ON u.id=p.user_id';
                    $fields = 'p.id, p.post_id, p.body, p.status, p.created_at, u.full_name, u.email';
                }
                $countQuery = $pdo->prepare('SELECT COUNT(*)' . $fromSql . $whereSql);
                foreach ($params as $key=>$value) $countQuery->bindValue($key, $value, PDO::PARAM_STR);
                $countQuery->execute();
                $communityTotalResults = (int)$countQuery->fetchColumn();
                $maxPage = max(1, (int)ceil($communityTotalResults / $communityPerPage));
                $communityPage = min($communityPage, $maxPage);
                $listQuery = $pdo->prepare('SELECT ' . $fields . $fromSql . $whereSql . ' ORDER BY p.id DESC LIMIT :limit OFFSET :offset');
                foreach ($params as $key=>$value) $listQuery->bindValue($key, $value, PDO::PARAM_STR);
                $listQuery->bindValue(':limit', $communityPerPage, PDO::PARAM_INT);
                $listQuery->bindValue(':offset', ($communityPage-1)*$communityPerPage, PDO::PARAM_INT);
                $listQuery->execute();
                $communityRows = $listQuery->fetchAll(PDO::FETCH_ASSOC);
            }
        } catch (Throwable $e) {
            error_log('Community dashboard load: ' . $e->getMessage());
            $communityError = 'কমিউনিটির তথ্য লোড করা যায়নি। ডাটাবেজের টেবিল ও সংযোগ পরীক্ষা করুন।';
        }
    }
}

/* ---------- DASHBOARD DATA ---------- */

$totalQuestions = 0;
$totalCategories = 0;
$categoryStats = [];
$recent = [];
$notice = '';

try {
    $totalQuestions = (int)$pdo
        ->query("SELECT COUNT(*) FROM questions")
        ->fetchColumn();

    $categoryStats = $pdo->query("
        SELECT
            COALESCE(NULLIF(TRIM(category), ''), 'অন্যান্য')
                AS category_name,
            COUNT(*) AS total
        FROM questions
        GROUP BY COALESCE(NULLIF(TRIM(category), ''), 'অন্যান্য')
        ORDER BY total DESC
        LIMIT 8
    ")->fetchAll(PDO::FETCH_ASSOC);

    $totalCategories = (int)$pdo->query("
        SELECT COUNT(
            DISTINCT COALESCE(NULLIF(TRIM(category), ''), 'অন্যান্য')
        )
        FROM questions
    ")->fetchColumn();

    $recent = $pdo->query("
        SELECT id, category, question
        FROM questions
        ORDER BY id DESC
        LIMIT 7
    ")->fetchAll(PDO::FETCH_ASSOC);

} catch (Throwable $e) {
    error_log('Dashboard question error: ' . $e->getMessage());
    $notice = 'প্রশ্নের তথ্য লোড করতে সমস্যা হয়েছে।';
}

/* ---------- OPTIONAL COUNTS ---------- */

$users = optionalCount($pdo, ['users', 'app_users', 'user_accounts']);
$notes = optionalCount($pdo, ['notes', 'study_notes']);
$tests = optionalCount($pdo, ['model_tests', 'tests', 'model_test']);

/* ---------- JOB CIRCULAR COUNTS ---------- */

$jobTotal = 0;
$jobPublished = 0;
$jobPinned = 0;
$jobDraft = 0;

if (hasTable($pdo, 'job_circulars')) {
    try {
        $jobTotal = (int)$pdo->query("
            SELECT COUNT(*) FROM job_circulars
        ")->fetchColumn();

        $jobPublished = (int)$pdo->query("
            SELECT COUNT(*) FROM job_circulars
            WHERE status = 'published'
        ")->fetchColumn();

        $jobPinned = (int)$pdo->query("
            SELECT COUNT(*) FROM job_circulars
            WHERE is_pinned = 1
        ")->fetchColumn();

        $jobDraft = (int)$pdo->query("
            SELECT COUNT(*) FROM job_circulars
            WHERE status = 'draft'
        ")->fetchColumn();

    } catch (Throwable $e) {
        error_log('Dashboard job circular error: ' . $e->getMessage());
    }
}

/* ---------- CATEGORY CHART ---------- */

$max = 1;

foreach ($categoryStats as $category) {
    $max = max($max, (int)$category['total']);
}

$colors = [
    '#c52c12',
    '#176b3b',
    '#13718b',
    '#6b28b8',
    '#d97706',
    '#b42318',
    '#2563eb',
    '#64748b'
];
?>

<!doctype html>
<html lang="bn">

<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title><?= $isCommunity ? 'কমিউনিটি ব্যবস্থাপনা' : ($isMarketplace ? 'মার্কেটপ্লেস' : 'ড্যাশবোর্ড') ?> — Fire Safety BD</title>

<style>
:root {
    --maroon: #510d18;
    --maroon-dark: #450b15;
    --orange: #ffa400;
    --paper: #fff8f5;
    --ink: #30191b;
    --muted: #8b7777;
    --line: #f1ddd6;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: var(--paper);
    color: var(--ink);
    font-family: Arial, "Noto Sans Bengali", "SolaimanLipi", sans-serif;
}

a {
    color: inherit;
    text-decoration: none;
}

.app {
    min-height: 100vh;
    display: flex;
}

/* SIDEBAR */

.sidebar {
    width: 280px;
    flex: 0 0 280px;
    background: linear-gradient(180deg, #450b15, #6a111f);
    color: #f9e9e7;
    padding: 24px 16px;
    min-height: 100vh;
}

.brand {
    display: flex;
    align-items: center;
    gap: 13px;
    padding: 4px 9px 26px;
}

/* Keep the sidebar brand links free from the browser's default blue underline. */
.brand a,
.brand a:link,
.brand a:visited,
.brand a:hover,
.brand a:focus,
.brand a:active {
    color: inherit;
    text-decoration: none !important;
}
.brand-name,
.brand-sub {
    text-decoration: none !important;
}

.logo {
    width: 65px;
    height: 65px;
    border: 2px solid white;
    border-radius: 13px;
    background: #510d18;
    object-fit: contain;
    display: block;
    flex-shrink: 0;
}

.brand-name {
    font-size: 20px;
    font-weight: 800;
    color: white;
    line-height: 1.25;
}

.brand-sub {
    font-size: 14px;
    color: #e0bfc2;
    margin-top: 5px;
}

.nav {
    display: grid;
    gap: 5px;
}

.nav a {
    display: flex;
    align-items: center;
    gap: 13px;
    padding: 13px 15px;
    border-radius: 14px;
    font-size: 16px;
    color: #f4dfe0;
}

.nav a:hover {
    background: #ffffff12;
}

.nav a.active {
    background: var(--orange);
    color: #29170b;
    font-weight: 800;
}

.ico {
    width: 22px;
    text-align: center;
    font-size: 20px;
}

.nav a.logout {
    margin-top: 15px;
    border: 1px solid #ffffff40;
    color: #ffd6d6;
}

.nav a.logout:hover {
    background: #a31919;
    color: white;
}

/* MAIN */

.main {
    flex: 1;
    min-width: 0;
    padding: 32px;
}

.topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 18px;
    margin-bottom: 28px;
}

.page-title {
    font-size: 32px;
    font-weight: 900;
    margin: 0 0 8px;
}

.subtitle {
    color: var(--muted);
    font-size: 16px;
}

.top-actions {
    display: flex;
    align-items: center;
    gap: 14px;
}

.search {
    width: min(340px, 30vw);
    height: 52px;
    border: 1px solid var(--line);
    border-radius: 17px;
    background: white;
    padding: 0 17px;
    font: inherit;
}

.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: 0;
    border-radius: 15px;
    padding: 14px 20px;
    background: var(--orange);
    color: #2b1808;
    font: inherit;
    font-weight: 800;
    white-space: nowrap;
}

/* STATISTICS */

.stats {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 18px;
    margin-bottom: 24px;
}

.stat {
    background: white;
    border: 1px solid var(--line);
    border-radius: 22px;
    padding: 22px 20px;
    min-height: 155px;
}

.stat-label {
    color: var(--muted);
    font-size: 16px;
}

.stat-value {
    font-size: 35px;
    font-weight: 900;
    color: #781523;
    margin: 22px 0 13px;
}

.stat-foot {
    font-size: 13px;
    color: #176b3b;
    font-weight: 700;
}

/* SHORTCUTS */

.shortcuts {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
    margin-bottom: 24px;
}

.shortcut {
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
    background: white;
    border: 1px solid var(--line);
    border-radius: 16px;
    padding: 15px 10px;
    color: #791623;
    font-weight: 800;
}

.shortcut:hover {
    background: #fff0e7;
}

/* PANELS */

.content-grid {
    display: grid;
    grid-template-columns: minmax(0, 2fr) minmax(270px, 1fr);
    gap: 18px;
    align-items: start;
}

.panel {
    background: white;
    border: 1px solid var(--line);
    border-radius: 22px;
    padding: 22px;
}

.panel-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 18px;
}

.panel-title {
    font-size: 21px;
    font-weight: 900;
    margin: 0;
}

.panel-link {
    color: #791623;
    font-weight: 800;
}

.table-wrap {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
    min-width: 480px;
}

th {
    text-align: left;
    color: var(--muted);
    font-weight: 700;
    padding: 12px 8px;
    border-bottom: 1px solid var(--line);
}

td {
    padding: 14px 8px;
    border-bottom: 1px solid #f5e7e2;
    vertical-align: middle;
}

tr:last-child td {
    border-bottom: 0;
}

.q-title {
    max-width: 300px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.pill {
    display: inline-block;
    padding: 7px 12px;
    border-radius: 999px;
    background: #e1f4e8;
    color: #176b3b;
    font-weight: 700;
    font-size: 13px;
}

.edit {
    border: 1px solid var(--line);
    border-radius: 10px;
    padding: 8px 11px;
    color: #791623;
    display: inline-block;
}

/* CATEGORY CHART */

.cat-row {
    margin: 18px 0;
}

.cat-meta {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 9px;
}

.cat-name {
    font-weight: 700;
}

.cat-count {
    color: var(--muted);
}

.bar {
    height: 9px;
    background: #f5e2de;
    border-radius: 99px;
    overflow: hidden;
}

.bar span {
    height: 100%;
    display: block;
    border-radius: 99px;
}

.alert {
    background: #fff0d6;
    color: #7a4200;
    padding: 12px 14px;
    border-radius: 12px;
    margin-bottom: 18px;
}

.empty {
    color: var(--muted);
    padding: 20px 0;
}

/* RESPONSIVE */

.mobile-toggle {
    display: none;
    background: var(--maroon);
    color: white;
    border: 0;
    border-radius: 10px;
    padding: 9px 12px;
    font-size: 20px;
}

@media (max-width: 1250px) {
    .sidebar {
        width: 245px;
        flex-basis: 245px;
    }

    .main {
        padding: 24px;
    }

    .stats {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .shortcuts {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .content-grid {
        grid-template-columns: minmax(0, 1.5fr) minmax(240px, 1fr);
    }
}

@media (max-width: 900px) {
    .topbar {
        align-items: flex-start;
        flex-direction: column;
    }

    .top-actions {
        width: 100%;
    }

    .search {
        width: 100%;
        flex: 1;
    }

    .content-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 640px) {
    .app {
        display: block;
    }

    .sidebar {
        display: none;
        width: 100%;
        min-height: auto;
        padding: 14px;
    }

    .sidebar.open {
        display: block;
    }

    .brand {
        padding-bottom: 12px;
    }

    .nav {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .nav a {
        font-size: 14px;
        padding: 10px;
    }

    .main {
        padding: 18px 14px 28px;
    }

    .mobile-toggle {
        display: inline-block;
    }

    .topline {
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .page-title {
        font-size: 27px;
    }

    .top-actions {
        align-items: stretch;
        flex-direction: column;
    }

    .search {
        width: 100%;
        min-height: 48px;
    }

    .btn {
        width: 100%;
    }

    .stats {
        gap: 10px;
    }

    .stat {
        padding: 15px 13px;
        min-height: 130px;
        border-radius: 17px;
    }

    .stat-label {
        font-size: 13px;
    }

    .stat-value {
        font-size: 28px;
        margin: 17px 0 9px;
    }

    .stat-foot {
        font-size: 11px;
    }

    .shortcuts {
        gap: 9px;
    }

    .shortcut {
        font-size: 13px;
        padding: 12px 6px;
    }

    .panel {
        padding: 15px;
        border-radius: 17px;
    }

    .panel-title {
        font-size: 19px;
    }

    .q-title {
        max-width: 160px;
    }
}

/* মার্কেটপ্লেস: মূল ড্যাশবোর্ডের একই রং, কার্ড, বোতাম ও ফর্ম */
.marketplace-content { max-width: 1450px; }
.marketplace-content .market-stats { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:14px; margin-bottom:22px; }
.marketplace-content .market-stat { display:block; background:white; border:1px solid var(--line); border-radius:22px; padding:20px 18px; text-decoration:none; transition:background .2s, transform .2s; }
.marketplace-content .market-stat:hover { background:#fff0e7; transform:translateY(-2px); }
.marketplace-content .market-stat.active { border-color:#e9ac64; box-shadow:inset 0 0 0 1px #f3d4b3; }
.marketplace-content .market-stat .stat-label { display:block; font-size:15px; }
.marketplace-content .market-stat .stat-value { display:block; margin:12px 0 4px; font-size:31px; }
.marketplace-content .market-stat .stat-foot { display:block; color:#7c5c58; }
.marketplace-content .market-tabs { display:flex; flex-wrap:wrap; gap:10px; margin:0 0 22px; }
.marketplace-content .market-tabs a { display:inline-flex; align-items:center; padding:12px 17px; background:white; border:1px solid var(--line); border-radius:14px; color:#791623; font-weight:800; text-decoration:none; }
.marketplace-content .market-tabs a:hover { background:#fff0e7; }
.marketplace-content .market-tabs a.active { background:var(--orange); border-color:var(--orange); color:#29170b; }
.marketplace-content .panel { margin-bottom:22px; }
.marketplace-content .market-panel-title { font-size:21px; font-weight:900; margin:0; }
.marketplace-content .market-panel-head { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:18px; }
.marketplace-content .market-help { color:var(--muted); font-size:14px; margin:6px 0 18px; line-height:1.7; }
.marketplace-content form.grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:17px 20px; }
.marketplace-content form.grid label { font-size:15px; font-weight:700; color:var(--ink); display:block; }
.marketplace-content form.grid input:not([type=checkbox]), .marketplace-content form.grid select, .marketplace-content form.grid textarea,
.marketplace-content .market-inline-form select { display:block; width:100%; margin-top:8px; padding:13px 14px; border:1px solid var(--line); border-radius:14px; font:inherit; background:#fff; color:var(--ink); min-height:48px; outline-offset:2px; }
.marketplace-content form.grid input:focus, .marketplace-content form.grid select:focus, .marketplace-content form.grid textarea:focus { border-color:#b35c45; outline:2px solid #ffe0c2; }
.marketplace-content form.grid textarea { min-height:115px; resize:vertical; }
.marketplace-content form.grid .wide { grid-column:1/-1; }
.marketplace-content .market-check { display:flex!important; gap:10px; align-items:center; }
.marketplace-content .market-check input { accent-color:#781523; width:18px; height:18px; }
.marketplace-content .market-upload { background:#fffaf6; border:2px dashed #d8b7a4; border-radius:17px; padding:18px; }
.marketplace-content .market-upload input[type=file] { background:white; cursor:pointer; }
.marketplace-content .market-upload-help { font-size:13px; color:var(--muted); display:block; margin-top:8px; font-weight:400; }
.marketplace-content .market-image-preview { display:flex; align-items:center; gap:14px; flex-wrap:wrap; margin-top:14px; }
.marketplace-content .market-image-preview img { width:108px; height:108px; object-fit:contain; background:white; border:1px solid var(--line); border-radius:12px; }
.marketplace-content .market-image-preview span { font-size:13px; color:var(--muted); }
.marketplace-content .market-image-preview[hidden] { display:none !important; }
.marketplace-content .market-form-actions { display:flex; flex-wrap:wrap; align-items:center; gap:12px; }
.marketplace-content .market-submit { background:var(--orange); color:#29170b; border:0; border-radius:15px; padding:13px 22px; cursor:pointer; font:inherit; font-weight:800; }
.marketplace-content .market-submit:hover { background:#ffb72c; }
.marketplace-content .market-secondary { display:inline-flex; border:1px solid var(--line); padding:12px 17px; border-radius:14px; color:#791623; font-weight:700; }
.marketplace-content .market-table-wrap { overflow-x:auto; }
.marketplace-content .market-table { min-width:700px; font-size:14px; }
.marketplace-content .market-table th { white-space:nowrap; }
.marketplace-content .market-table td { line-height:1.6; }
.marketplace-content .market-table .edit { text-decoration:none; }
.marketplace-content .market-table .edit:hover { background:#fff0e7; }
.marketplace-content .market-table small { color:var(--muted); }
.marketplace-content .market-badge { display:inline-block; padding:5px 11px; border-radius:99px; background:#fff0d6; color:#814b00; font-weight:800; font-size:12px; white-space:nowrap; }
.marketplace-content .market-badge.is-published, .marketplace-content .market-badge.is-delivered, .marketplace-content .market-badge.is-completed, .marketplace-content .market-badge.is-approved { background:#e1f4e8; color:#176b3b; }
.marketplace-content .market-badge.is-archived, .marketplace-content .market-badge.is-cancelled, .marketplace-content .market-badge.is-rejected { background:#f1e9e9; color:#775d5d; }
.marketplace-content .market-inline-form { display:flex; align-items:center; gap:8px; min-width:230px; }
.marketplace-content .market-inline-form select { margin:0; padding:9px; min-height:39px; border-radius:10px; }
.marketplace-content .market-inline-form .market-submit { padding:10px 12px; border-radius:10px; white-space:nowrap; }
.marketplace-content .market-notice { padding:14px 17px; border-radius:13px; margin:0 0 18px; line-height:1.6; }
.marketplace-content .market-notice.error { background:#ffe8e8; color:#8b2323; }
.marketplace-content .market-notice.success { background:#e1f4e8; color:#176b3b; }
.marketplace-content .market-footnote { color:var(--muted); line-height:1.7; font-size:13px; }
@media(max-width:1250px) { .marketplace-content .market-stats { grid-template-columns:repeat(3,minmax(0,1fr)); } }
@media(max-width:750px) { .marketplace-content .market-stats { grid-template-columns:repeat(2,minmax(0,1fr)); gap:10px; } .marketplace-content .market-stat { padding:14px; border-radius:17px; } .marketplace-content .market-stat .stat-value { font-size:27px; } .marketplace-content form.grid { grid-template-columns:1fr; } .marketplace-content form.grid .wide { grid-column:1; } .marketplace-content .market-tabs a { padding:10px 12px; font-size:14px; } }

/* Community moderation — matches existing Fire Safety BD admin design */
.community-content {max-width:1500px;margin:auto}
.community-heading {display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:22px}
.community-heading h2 {margin:0 0 6px;font-size:22px}
.community-heading p {margin:0;color:var(--muted);line-height:1.6}
.community-quicklink {display:inline-flex;align-items:center;gap:8px;background:#fff;border:1px solid var(--line);border-radius:14px;padding:12px 17px;color:#791623;font-weight:800}
.community-stats {display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:13px;margin-bottom:24px}
.community-stat {background:#fff;border:1px solid var(--line);border-radius:20px;padding:19px 16px;display:block;transition:transform .15s,border-color .15s}
.community-stat:hover {transform:translateY(-2px);border-color:#dbac9f}
.community-stat.active {border-color:#d88451;box-shadow:inset 0 0 0 1px #e6b190}
.community-stat .number {display:block;font-size:31px;font-weight:900;color:#781523;margin:12px 0 4px}
.community-stat .caption {font-size:13px;color:var(--muted)}
.community-stat .label {font-weight:700;color:#655055}
.community-tabs {display:flex;gap:10px;flex-wrap:wrap;margin-bottom:18px}
.community-tabs a {display:inline-flex;padding:12px 18px;border:1px solid var(--line);border-radius:13px;background:#fff;color:#791623;font-weight:800}
.community-tabs a.active {background:var(--orange);border-color:var(--orange);color:#29170b}
.community-toolbar {display:flex;align-items:end;gap:12px;flex-wrap:wrap;margin-bottom:22px;background:#fff;padding:17px;border:1px solid var(--line);border-radius:18px}
.community-toolbar label {display:grid;gap:7px;font-size:13px;font-weight:700;color:#68575a}
.community-toolbar input,.community-toolbar select {min-height:45px;min-width:165px;border:1px solid #ead6d0;border-radius:11px;padding:10px 12px;font:inherit;background:#fff;color:var(--ink)}
.community-toolbar input {min-width:250px;flex:1}
.community-toolbar button {min-height:45px;border:0;background:#781523;color:white;border-radius:11px;padding:10px 20px;font:inherit;font-weight:800;cursor:pointer}
.community-results {display:flex;justify-content:space-between;gap:10px;align-items:center;margin:0 0 12px;color:#7b6467;font-size:14px}
.community-list {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
.community-card {border:1px solid var(--line);border-radius:20px;background:#fff;padding:20px;min-width:0;box-shadow:0 5px 20px #450b1507}
.community-author {display:flex;align-items:center;gap:12px;min-width:0}
.community-avatar {display:grid;place-items:center;flex:0 0 44px;height:44px;border-radius:15px;background:#fff0e7;color:#781523;font-weight:900;font-size:18px}
.community-author-info {min-width:0;flex:1}
.community-author-info strong {display:block;overflow-wrap:anywhere}
.community-meta {font-size:12px;color:#8b7777;overflow-wrap:anywhere;margin-top:4px}
.community-status {display:inline-flex;align-items:center;padding:6px 10px;border-radius:999px;font-size:12px;font-weight:800;white-space:nowrap;background:#f7e8e1;color:#6b3440}
.community-status.approved,.community-status.visible {background:#e1f4e8;color:#176b3b}
.community-status.pending {background:#fff1d4;color:#88540a}
.community-status.rejected,.community-status.deleted {background:#f5e8e8;color:#8d3443}
.community-status.hidden {background:#eae9ed;color:#5b5367}
.community-body {white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.85;margin:18px 0;color:#352629;font-size:15px}
.community-photo {display:block;max-width:100%;max-height:360px;width:auto;border-radius:13px;border:1px solid #eee4e0;object-fit:contain;margin:12px 0;background:#fbf8f7}
.community-actions {border-top:1px solid #f1e5e2;padding-top:15px;display:flex;gap:9px;flex-wrap:wrap;margin-top:18px}
.community-actions form {display:inline-flex}
.community-action {border:0;border-radius:11px;padding:11px 15px;font:inherit;font-weight:800;cursor:pointer;background:#176b3b;color:white}
.community-action.reject {background:#f5e7e7;color:#8e263c}
.community-action.hide {background:#8b5660;color:white}
.community-action.delete {background:#b42332;color:white}
.community-action.restore {background:#f8eddc;color:#6c481d}
.community-empty {background:white;border:1px dashed #d9bdb7;border-radius:18px;padding:45px 18px;text-align:center;color:var(--muted);line-height:1.8}
.community-pagination {display:flex;justify-content:center;align-items:center;gap:12px;margin-top:22px}
.community-pagination a {background:white;border:1px solid var(--line);border-radius:11px;padding:10px 15px;color:#791623;font-weight:800}
.community-notice {border-radius:13px;padding:13px 17px;margin-bottom:18px;line-height:1.7;background:#e1f4e8;color:#176b3b}
.community-notice.error {background:#ffe8e8;color:#8b2323}
@media(max-width:1200px){.community-stats{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:850px){.community-list{grid-template-columns:1fr}}
@media(max-width:640px){.community-stats{grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.community-stat{padding:13px;border-radius:15px}.community-stat .number{font-size:25px}.community-toolbar{display:grid;grid-template-columns:1fr 1fr}.community-toolbar label:first-of-type{grid-column:1/-1}.community-toolbar input,.community-toolbar select{min-width:0;width:100%}.community-toolbar button{grid-column:1/-1}.community-card{padding:15px}.community-heading h2{font-size:20px}}
</style>
</head>

<body>

<div class="app">

<!-- SIDEBAR -->

<aside class="sidebar" id="sidebar">

    <div class="brand">

        <a href="fire_safety_job_prep_dashboard.php">
            <img
                src="assets/fire-safety-bd-logo.png"
                alt="Fire Safety BD Logo"
                class="logo"
            >
        </a>

        <div>
            <a href="fire_safety_job_prep_dashboard.php">
                <div class="brand-name">Fire Safety BD</div>
                <div class="brand-sub">অ্যাডমিন প্যানেল</div>
            </a>
        </div>

    </div>

    <nav class="nav">

        <a class="<?= (!$isMarketplace && !$isCommunity) ? 'active' : '' ?>" href="fire_safety_job_prep_dashboard.php">
            <span class="ico">▦</span> ড্যাশবোর্ড
        </a>

        <a href="questions.php">
            <span class="ico">ⓘ</span> প্রশ্ন ব্যাংক
        </a>

        <a href="model_tests.php">
            <span class="ico">☑</span> মডেল টেস্ট
        </a>

        <a href="notes.php">
            <span class="ico">◫</span> নোট
        </a>

        <!-- NEW JOB CIRCULAR LINK -->
        <a href="job_circulars.php">
            <span class="ico">▣</span> চাকরির সার্কুলার
        </a>

        <a class="<?= $isMarketplace ? 'active' : '' ?>" href="fire_safety_job_prep_dashboard.php?section=marketplace">
            <span class="ico">🛒</span> মার্কেটপ্লেস
        </a>

        <a href="category_management.php">
            <span class="ico">⊞</span> ক্যাটাগরি
        </a>

        <a href="questions.php">
            <span class="ico">♙</span> ব্যবহারকারী
        </a>

        <a href="homepage_admin.php">
            <span class="ico">⌂</span> হোমপেজ ব্যবস্থাপনা
        </a>

        <a href="interview_admin.php">
            <span class="ico">▤</span> ইন্টারভিউ ব্যবস্থাপনা
        </a>

        <a href="notifications_admin.php">
            <span class="ico">♧</span> নোটিফিকেশন
        </a>

        <a class="<?= $isCommunity ? 'active' : '' ?>" href="fire_safety_job_prep_dashboard.php?section=community" <?= $isCommunity ? 'aria-current="page"' : '' ?>>
            <span class="ico">▱</span> কমিউনিটি
        </a>

        <a href="settings_admin.php">
            <span class="ico">☼</span> সেটিংস
        </a>

        <a href="analytics_admin.php">
            <span class="ico">▥</span> অ্যানালিটিক্স
        </a>

        <a href="logout.php" class="logout">
            <span class="ico">↪</span> লগ আউট
        </a>

    </nav>

</aside>

<!-- MAIN CONTENT -->

<main class="main">

    <div class="topbar">

        <div class="topline">

            <button
                class="mobile-toggle"
                onclick="document.getElementById('sidebar').classList.toggle('open')"
                aria-label="মেনু"
            >☰</button>

            <div>
                <h1 class="page-title"><?= $isCommunity ? 'কমিউনিটি' : ($isMarketplace ? 'মার্কেটপ্লেস' : 'ড্যাশবোর্ড') ?></h1>
                <div class="subtitle">
                    <?= $isCommunity ? 'পোস্ট, ছবি ও মন্তব্য পর্যালোচনা এবং অনুমোদন' : ($isMarketplace ? 'পণ্য, সেবা, ক্যাটাগরি, অর্ডার ও সেবার অনুরোধ ব্যবস্থাপনা' : 'Fire Safety BD — কনটেন্টের সারসংক্ষেপ') ?>
                </div>
            </div>

        </div>

        <?php if (!$isMarketplace && !$isCommunity): ?>
        <div class="top-actions">

            <input
                id="search"
                class="search"
                type="search"
                placeholder="প্রশ্ন খুঁজুন..."
            >

            <a class="btn" href="questions.php">
                ＋ প্রশ্ন ব্যবস্থাপনা
            </a>

        </div>
        <?php endif; ?>

    </div>

    <?php if ($isMarketplace): ?>
    <section class="marketplace-content" aria-label="মার্কেটপ্লেস ব্যবস্থাপনা">
        <?php if ($error !== ''): ?><div class="market-notice error" role="alert"><?= h($error) ?></div><?php endif; ?>
        <?php if (isset($_GET['saved'])): ?><div class="market-notice success" role="status">তথ্য সফলভাবে সংরক্ষণ করা হয়েছে।</div><?php endif; ?>

        <div class="market-stats" aria-label="মার্কেটপ্লেসের সারসংক্ষেপ">
        <?php foreach (['products'=>['পণ্য','▣'], 'services'=>['সেবা','♧'], 'categories'=>['ক্যাটাগরি','⊞'], 'orders'=>['অর্ডার','▤'], 'requests'=>['সেবার অনুরোধ','☑']] as $key=>$meta): ?>
            <a class="market-stat <?= $tab === $key ? 'active' : '' ?>" href="?section=marketplace&amp;tab=<?= h($key) ?>">
                <span class="stat-label"><?= h($meta[0]) ?></span>
                <span class="stat-value"><?= mk_bn_num($marketStats[$key]) ?></span>
                <span class="stat-foot">বিস্তারিত দেখুন</span>
            </a>
        <?php endforeach; ?>
        </div>

        <nav class="market-tabs" aria-label="মার্কেটপ্লেস বিভাগ">
        <?php foreach (['products'=>'পণ্য', 'services'=>'সেবা', 'categories'=>'ক্যাটাগরি', 'orders'=>'অর্ডার', 'requests'=>'সেবার অনুরোধ'] as $key=>$label): ?>
            <a class="<?= $tab === $key ? 'active' : '' ?>" <?= $tab === $key ? 'aria-current="page"' : '' ?> href="?section=marketplace&amp;tab=<?= h($key) ?>"><?= h($label) ?></a>
        <?php endforeach; ?>
        </nav>

        <?php if (in_array($tab,['products','services','categories'],true)): ?>
        <section class="panel">
            <div class="market-panel-head"><h2 class="market-panel-title"><?= $edit ? 'সম্পাদনা করুন: ' : 'নতুন ' ?><?= h(['products'=>'পণ্য', 'services'=>'সেবা', 'categories'=>'ক্যাটাগরি'][$tab]) ?><?= $edit ? '' : ' যোগ করুন' ?></h2></div>
            <p class="market-help">তারকা (*) চিহ্নিত তথ্য অবশ্যই পূরণ করতে হবে। প্রকাশিত পণ্য ও সেবা অ্যাপে দেখা যাবে।</p>
            <form method="post" class="grid" enctype="multipart/form-data">
                <input type="hidden" name="csrf_token" value="<?= h($token) ?>">
                <input type="hidden" name="action" value="save_<?= h(['products'=>'product','services'=>'service','categories'=>'category'][$tab]) ?>">
                <input type="hidden" name="id" value="<?= field($edit,'id') ?>">
                <label>নাম *<input name="name" maxlength="<?= $tab === 'categories' ? 150 : 200 ?>" required value="<?= field($edit,'name') ?>" placeholder="নাম লিখুন"></label>
                <p class="wide market-help">স্লাগ স্বয়ংক্রিয়ভাবে তৈরি ও সংরক্ষিত হবে। আপনাকে কিছু লিখতে হবে না।</p>
                <?php if ($tab === 'categories'): ?>
                    <label>ক্যাটাগরির ধরন<select name="category_type">
                    <?php foreach (['both'=>'পণ্য ও সেবা উভয়ই', 'product'=>'শুধু পণ্য', 'service'=>'শুধু সেবা'] as $value=>$label): ?>
                        <option value="<?= h($value) ?>"<?= selected($edit,'category_type',$value,'both') ?>><?= h($label) ?></option>
                    <?php endforeach; ?></select></label>
                    <label>প্রদর্শনের ক্রম<input type="number" name="sort_order" value="<?= field($edit,'sort_order','0') ?>"></label>
                    <label class="wide market-check"><input type="checkbox" name="is_active" value="1"<?= checked($edit,'is_active',true) ?>> সক্রিয় রাখুন</label>
                <?php else: ?>
                    <label>ক্যাটাগরি<select name="category_id"><option value="">ক্যাটাগরি নির্বাচন করা হয়নি</option>
                    <?php foreach ($categories as $c): if ($c['category_type'] !== 'both' && $c['category_type'] !== ($tab === 'products' ? 'product' : 'service')) continue; ?>
                        <option value="<?= (int)$c['id'] ?>"<?= (string)($edit['category_id'] ?? '') === (string)$c['id'] ? ' selected' : '' ?>><?= h($c['name']) ?></option>
                    <?php endforeach; ?></select></label>
                    <div class="wide market-upload">
                        <label for="market-image-file">পণ্য বা সেবার ছবি আপলোড করুন
                            <input id="market-image-file" name="image_file" type="file" accept="image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp" aria-describedby="market-image-help">
                        </label>
                        <span class="market-upload-help" id="market-image-help">মোবাইল বা কম্পিউটার থেকে ছবি বেছে নিন। JPG, PNG বা WEBP • সর্বোচ্চ ৫ মেগাবাইট। নতুন ছবি না দিলে আগের ছবি থাকবে।</span>
                        <div class="market-image-preview" id="market-image-preview" <?= empty($edit['image_url']) ? 'hidden' : '' ?>>
                            <img id="market-image-preview-img" <?= empty($edit['image_url']) ? '' : 'src="' . field($edit,'image_url') . '"' ?> alt="নির্বাচিত বা বর্তমান ছবি" loading="lazy">
                            <span id="market-image-preview-caption"><?= empty($edit['image_url']) ? 'নতুন ছবি' : 'বর্তমান ছবি' ?></span>
                        </div>
                    </div>
                    <label>প্রকাশের অবস্থা<select name="status">
                    <?php foreach (['draft','published','archived'] as $status): ?>
                        <option value="<?= h($status) ?>"<?= selected($edit,'status',$status,'draft') ?>><?= h(mk_bn_label($status)) ?></option>
                    <?php endforeach; ?></select></label>
                    <label>মূল্য (টাকা)<?= $tab === 'services' ? ' — ঐচ্ছিক' : ' *' ?><input name="price" inputmode="decimal" value="<?= field($edit,'price', $tab === 'products' ? '0.00' : '') ?>" placeholder="0.00"<?= $tab === 'products' ? ' required' : '' ?>></label>
                    <?php if ($tab === 'products'): ?>
                        <label>পণ্যের কোড (SKU)<input name="sku" maxlength="100" value="<?= field($edit,'sku') ?>"></label>
                        <label>আগের মূল্য (ঐচ্ছিক)<input name="compare_price" inputmode="decimal" value="<?= field($edit,'compare_price') ?>" placeholder="0.00"></label>
                        <label>মজুতের পরিমাণ *<input name="stock_quantity" type="number" min="0" required value="<?= field($edit,'stock_quantity','0') ?>"></label>
                    <?php else: ?>
                        <label>মূল্য নির্ধারণের ধরন<select name="pricing_type">
                        <?php foreach (['quote','fixed','starting'] as $type): ?>
                            <option value="<?= h($type) ?>"<?= selected($edit,'pricing_type',$type,'quote') ?>><?= h(mk_bn_label($type)) ?></option>
                        <?php endforeach; ?></select></label>
                    <?php endif; ?>
                    <label class="wide market-check"><input type="checkbox" name="is_featured" value="1"<?= checked($edit,'is_featured') ?>> বিশেষভাবে প্রদর্শন করুন</label>
                <?php endif; ?>
                <label class="wide">বিস্তারিত বিবরণ<textarea name="description" placeholder="বিস্তারিত তথ্য লিখুন"><?= field($edit,'description') ?></textarea></label>
                <div class="wide market-form-actions"><button class="market-submit" type="submit">তথ্য সংরক্ষণ করুন</button><a class="market-secondary" href="?section=marketplace&amp;tab=<?= h($tab) ?>">ফর্ম খালি করুন</a></div>
            </form>
        </section>
        <?php endif; ?>

        <section class="panel">
            <div class="market-panel-head"><h2 class="market-panel-title"><?= h(['products'=>'পণ্যের তালিকা','services'=>'সেবার তালিকা','categories'=>'ক্যাটাগরির তালিকা','orders'=>'অর্ডারের তালিকা','requests'=>'সেবার অনুরোধের তালিকা'][$tab]) ?></h2></div>
            <div class="market-table-wrap"><table class="market-table"><thead><tr>
            <?php if ($tab === 'products'): ?><th>ক্রমিক</th><th>পণ্যের নাম</th><th>মূল্য</th><th>মজুত</th><th>অবস্থা</th><th>ব্যবস্থা</th>
            <?php elseif ($tab === 'services'): ?><th>ক্রমিক</th><th>সেবার নাম</th><th>মূল্য নির্ধারণ</th><th>অবস্থা</th><th>ব্যবস্থা</th>
            <?php elseif ($tab === 'categories'): ?><th>ক্রমিক</th><th>ক্যাটাগরির নাম</th><th>ধরন</th><th>সক্রিয়</th><th>ব্যবস্থা</th>
            <?php elseif ($tab === 'orders'): ?><th>অর্ডার</th><th>ক্রেতা</th><th>মোট মূল্য</th><th>পেমেন্ট</th><th>অবস্থা পরিবর্তন</th><th>পণ্য</th>
            <?php else: ?><th>অনুরোধ</th><th>সেবা</th><th>গ্রাহক</th><th>ঠিকানা</th><th>অবস্থা পরিবর্তন</th><?php endif; ?>
            </tr></thead><tbody>
            <?php
            $table = ['products'=>'market_products','services'=>'market_services','categories'=>'market_categories','orders'=>'market_orders','requests'=>'market_service_requests'][$tab];
            $rows = $pdo->query("SELECT * FROM $table ORDER BY id DESC LIMIT 200")->fetchAll();
            $itemQuery = $pdo->prepare('SELECT product_name,quantity,unit_price,total_price FROM market_order_items WHERE order_id=? ORDER BY id');
            foreach ($rows as $r): ?>
                <tr>
                <?php if ($tab === 'products'): ?>
                    <td><?= mk_bn_num($r['id']) ?></td><td><?= h($r['name']) ?><br><small><?= h($r['sku']) ?></small></td><td>৳<?= mk_bn_num(h($r['price'])) ?></td><td><?= mk_bn_num($r['stock_quantity']) ?></td><td><span class="market-badge is-<?= h($r['status']) ?>"><?= h(mk_bn_label($r['status'])) ?></span></td><td><a class="edit" href="?section=marketplace&amp;tab=products&amp;edit=<?= (int)$r['id'] ?>">সম্পাদনা</a></td>
                <?php elseif ($tab === 'services'): ?>
                    <td><?= mk_bn_num($r['id']) ?></td><td><?= h($r['name']) ?></td><td><?= h(mk_bn_label($r['pricing_type'])) ?><?= $r['price'] === null ? '' : ' / ৳'.mk_bn_num(h($r['price'])) ?></td><td><span class="market-badge is-<?= h($r['status']) ?>"><?= h(mk_bn_label($r['status'])) ?></span></td><td><a class="edit" href="?section=marketplace&amp;tab=services&amp;edit=<?= (int)$r['id'] ?>">সম্পাদনা</a></td>
                <?php elseif ($tab === 'categories'): ?>
                    <td><?= mk_bn_num($r['id']) ?></td><td><?= h($r['name']) ?></td><td><?= h(mk_bn_label($r['category_type'])) ?></td><td><?= (int)$r['is_active'] ? 'হ্যাঁ' : 'না' ?></td><td><a class="edit" href="?section=marketplace&amp;tab=categories&amp;edit=<?= (int)$r['id'] ?>">সম্পাদনা</a></td>
                <?php elseif ($tab === 'orders'): ?>
                    <td><?= h($r['order_number']) ?><br><small><?= h($r['created_at']) ?></small></td>
                    <td><?= h($r['customer_name']) ?><br><?= h($r['mobile_number']) ?><br><?= h($r['delivery_address']) ?></td>
                    <td>৳<?= mk_bn_num(h($r['total_amount'])) ?></td><td><?= h(mk_bn_label($r['payment_method'])) ?> / <?= h(mk_bn_label($r['payment_status'])) ?></td>
                    <td><form method="post" class="market-inline-form"><input type="hidden" name="csrf_token" value="<?= h($token) ?>"><input type="hidden" name="action" value="order_status"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>"><select name="order_status" aria-label="অর্ডারের অবস্থা"><?php foreach (['pending','confirmed','processing','shipped','delivered','cancelled'] as $status): ?><option value="<?= h($status) ?>"<?= $r['order_status'] === $status ? ' selected' : '' ?>><?= h(mk_bn_label($status)) ?></option><?php endforeach; ?></select><button class="market-submit" type="submit">আপডেট</button></form></td>
                    <td><?php $itemQuery->execute([(int)$r['id']]); foreach ($itemQuery->fetchAll() as $line): ?><?= h($line['product_name']) ?> × <?= mk_bn_num($line['quantity']) ?><br><?php endforeach; ?></td>
                <?php else: ?>
                    <td><?= h($r['request_number']) ?><br><small><?= h($r['created_at']) ?></small></td><td>#<?= mk_bn_num($r['service_id'] ?? '—') ?><br><?= h($r['request_details']) ?></td><td><?= h($r['customer_name']) ?><br><?= h($r['mobile_number']) ?><br><?= h($r['company_name']) ?></td><td><?= h($r['service_location']) ?><br><?= h($r['preferred_date']) ?></td>
                    <td><form method="post" class="market-inline-form"><input type="hidden" name="csrf_token" value="<?= h($token) ?>"><input type="hidden" name="action" value="request_status"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>"><select name="status" aria-label="সেবার অনুরোধের অবস্থা"><?php foreach (['pending','reviewing','approved','completed','rejected','cancelled'] as $status): ?><option value="<?= h($status) ?>"<?= $r['status'] === $status ? ' selected' : '' ?>><?= h(mk_bn_label($status)) ?></option><?php endforeach; ?></select><button class="market-submit" type="submit">আপডেট</button></form></td>
                <?php endif; ?>
                </tr>
            <?php endforeach; ?>
            <?php if (!$rows): ?><tr><td colspan="7" class="empty">এখনো কোনো তথ্য যোগ করা হয়নি।</td></tr><?php endif; ?>
            </tbody></table></div>
        </section>
        <p class="market-footnote">অর্ডার বাতিল করলে মজুত স্বয়ংক্রিয়ভাবে ফেরত আসে না। প্রয়োজন হলে যাচাই করে মজুত পরিবর্তন করুন। বর্তমানে শুধু ক্যাশ অন ডেলিভারি চালু আছে।</p>
    </section>
    <?php elseif ($isCommunity): ?>
    <section class="community-content" aria-label="কমিউনিটি ব্যবস্থাপনা">
        <div class="community-heading">
            <div>
                <h2>কমিউনিটি ম্যানেজমেন্ট</h2>
                <p>সদস্যদের পোস্ট ও ছবি যাচাই করুন, প্রকাশিত কনটেন্ট নিয়ন্ত্রণ করুন এবং মন্তব্য মডারেট করুন।</p>
            </div>
            <a class="community-quicklink" href="community_review.php">↗ আলাদা রিভিউ পেজ</a>
        </div>
        <?php if ($communityError !== ''): ?><div class="community-notice error" role="alert"><?= h($communityError) ?></div><?php endif; ?>
        <?php if ($communityDeleteFlash !== ''): ?><div class="community-notice" role="status"><?= h($communityDeleteFlash) ?></div><?php endif; ?>
        <?php if ($communitySaved): ?><div class="community-notice" role="status">✓ আপনার সিদ্ধান্ত সফলভাবে সংরক্ষিত হয়েছে।</div><?php endif; ?>
        <?php if (!$communityHasPosts): ?>
            <div class="community-empty"><strong>কমিউনিটি পোস্ট টেবিল পাওয়া যায়নি।</strong><br>সঠিক ডাটাবেজ নির্বাচন করা আছে কি না এবং Community Backend ইনস্টল হয়েছে কি না পরীক্ষা করুন।</div>
        <?php else: ?>
            <div class="community-stats">
                <?php foreach ([
                    'all'=>['সব পোস্ট',$communityStats['total']],
                    'pending'=>['অনুমোদনের অপেক্ষায়',$communityStats['pending']],
                    'approved'=>['প্রকাশিত পোস্ট',$communityStats['approved']],
                    'rejected'=>['বাতিল পোস্ট',$communityStats['rejected']],
                    'hidden'=>['লুকানো পোস্ট',$communityStats['hidden']]
                ] as $statusKey=>$meta): ?>
                    <a class="community-stat <?= $communityTab === 'posts' && $communityStatus === $statusKey ? 'active' : '' ?>" href="?section=community&amp;view=posts&amp;status=<?= h($statusKey) ?>">
                        <span class="label"><?= h($meta[0]) ?></span>
                        <span class="number"><?= number_format((int)$meta[1]) ?></span>
                        <span class="caption">বিস্তারিত দেখুন</span>
                    </a>
                <?php endforeach; ?>
            </div>
            <nav class="community-tabs" aria-label="কমিউনিটি মডারেশন বিভাগ">
                <a class="<?= $communityTab === 'posts' ? 'active' : '' ?>" href="?section=community&amp;view=posts" <?= $communityTab === 'posts' ? 'aria-current="page"' : '' ?>>▣ পোস্ট ব্যবস্থাপনা</a>
                <?php if ($communityHasComments): ?>
                    <a class="<?= $communityTab === 'comments' ? 'active' : '' ?>" href="?section=community&amp;view=comments" <?= $communityTab === 'comments' ? 'aria-current="page"' : '' ?>>▤ মন্তব্য (<?= number_format($communityCommentStats['total']) ?>)</a>
                <?php endif; ?>
            </nav>
            <?php if ($communityTab === 'comments' && !$communityHasComments): ?>
                <div class="community-empty">মন্তব্যের ডাটাবেজ টেবিল পাওয়া যায়নি।</div>
            <?php else: ?>
                <form method="get" class="community-toolbar" aria-label="পোস্ট ও মন্তব্য ফিল্টার">
                    <input type="hidden" name="section" value="community">
                    <input type="hidden" name="view" value="<?= h($communityTab) ?>">
                    <label>নাম, ইমেইল বা লেখা দিয়ে খুঁজুন
                        <input type="search" name="q" maxlength="80" value="<?= h($communitySearch) ?>" placeholder="সার্চ করুন...">
                    </label>
                    <label>অবস্থা
                        <select name="status">
                            <?php foreach (($communityTab === 'posts' ? [
                                'all'=>'সব পোস্ট','pending'=>'অপেক্ষমাণ','approved'=>'প্রকাশিত','rejected'=>'বাতিল','hidden'=>'লুকানো'
                            ] : [
                                'all'=>'সব মন্তব্য','visible'=>'দৃশ্যমান','hidden'=>'লুকানো','deleted'=>'মুছে ফেলা'
                            ]) as $key=>$label): ?>
                                <option value="<?= h($key) ?>" <?= $communityStatus === $key ? 'selected' : '' ?>><?= h($label) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <button type="submit">⌕ খুঁজুন</button>
                </form>
                <div class="community-results">
                    <strong><?= $communityTab === 'posts' ? 'পোস্টের তালিকা' : 'মন্তব্যের তালিকা' ?></strong>
                    <span>মোট <?= number_format($communityTotalResults) ?> টি ফলাফল</span>
                </div>
                <?php if (!$communityRows): ?>
                    <div class="community-empty">এই ফিল্টারে কোনো <?= $communityTab === 'posts' ? 'পোস্ট' : 'মন্তব্য' ?> পাওয়া যায়নি।</div>
                <?php else: ?>
                    <div class="community-list">
                        <?php foreach ($communityRows as $item): ?>
                            <?php
                            $displayName = trim((string)($item['full_name'] ?? '')) ?: 'অজ্ঞাত সদস্য';
                            $displayInitial = function_exists('mb_substr') ? mb_substr($displayName,0,1,'UTF-8') : '#';
                            $statusText = [
                                'pending'=>'অপেক্ষমাণ','approved'=>'প্রকাশিত','rejected'=>'বাতিল',
                                'hidden'=>'লুকানো','visible'=>'দৃশ্যমান','deleted'=>'মুছে ফেলা'
                            ][$item['status']] ?? (string)$item['status'];
                            ?>
                            <article class="community-card">
                                <div class="community-author">
                                    <span class="community-avatar" aria-hidden="true"><?= h($displayInitial) ?></span>
                                    <div class="community-author-info">
                                        <strong><?= h($displayName) ?></strong>
                                        <div class="community-meta">#<?= (int)$item['id'] ?> · <?= h($item['created_at'] ?? '—') ?><?php if ($communityTab === 'comments'): ?> · পোস্ট #<?= (int)$item['post_id'] ?><?php endif; ?></div>
                                        <?php if (!empty($item['email'])): ?><div class="community-meta"><?= h($item['email']) ?></div><?php endif; ?>
                                    </div>
                                    <span class="community-status <?= h($item['status']) ?>"><?= h($statusText) ?></span>
                                </div>
                                <div class="community-body"><?= h($item['body']) ?></div>
                                <?php if ($communityTab === 'posts' && $communityHasImages && !empty($item['image_path']) && preg_match('/\A[a-f0-9]{32}\.(?:jpg|png|webp)\z/D', (string)$item['image_path'])): ?>
                                    <a href="uploads/community/<?= h($item['image_path']) ?>" target="_blank" rel="noopener noreferrer" aria-label="পোস্টের সম্পূর্ণ ছবি দেখুন">
                                        <img class="community-photo" src="uploads/community/<?= h($item['image_path']) ?>" alt="পোস্টের সংযুক্ত ছবি" loading="lazy">
                                    </a>
                                <?php endif; ?>
                                <?php
                                $actions = $communityTab === 'posts' ? match($item['status']) {
                                    'pending'=>['approve'=>'✓ অনুমোদন','reject'=>'✕ বাতিল'],
                                    'approved'=>['hide_post'=>'◉ লুকান'],
                                    'hidden'=>['restore_post'=>'↺ আবার প্রকাশ করুন'],
                                    default=>[],
                                } : match($item['status']) {
                                    'visible'=>['hide_comment'=>'◉ মন্তব্য লুকান'],
                                    'hidden'=>['restore_comment'=>'↺ মন্তব্য ফিরিয়ে আনুন'],
                                    default=>[],
                                };
                                if ($communityTab==='posts') $actions['delete_post']='✕ ডিলিট করুন';
                                ?>
                                <?php if ($actions): ?>
                                    <div class="community-actions">
                                        <?php foreach ($actions as $action=>$label): ?>
                                            <form method="post" action="?section=community&amp;view=<?= h($communityTab) ?>" onsubmit="return confirm('<?= $action==='delete_post'?'পোস্ট, মন্তব্য, লাইক ও রিপোর্ট স্থায়ীভাবে মুছে যাবে। ফিরিয়ে আনা যাবে না। নিশ্চিত করবেন?':'আপনি কি এই সিদ্ধান্ত নিশ্চিত করতে চান?' ?>');">
                                                <input type="hidden" name="csrf_token" value="<?= h($communityToken) ?>">
                                                <input type="hidden" name="item_id" value="<?= (int)$item['id'] ?>">
                                                <?php if($action==='delete_post'): ?><input type="hidden" name="confirm_delete" value="1"><?php endif; ?>
                                                <button class="community-action <?= $action==='delete_post' ? 'delete' : (str_contains($action,'restore') ? 'restore' : (str_contains($action,'hide') ? 'hide' : ($action === 'reject' ? 'reject' : ''))) ?>" type="submit" name="community_action" value="<?= h($action) ?>"><?= h($label) ?></button>
                                            </form>
                                        <?php endforeach; ?>
                                    </div>
                                <?php endif; ?>
                            </article>
                        <?php endforeach; ?>
                    </div>
                    <?php if ($communityTotalResults > $communityPerPage): ?>
                        <?php $queryArgs = ['section'=>'community','view'=>$communityTab,'status'=>$communityStatus,'q'=>$communitySearch]; ?>
                        <nav class="community-pagination" aria-label="পেজ পরিবর্তন">
                            <?php if ($communityPage > 1): ?><a href="?<?= h(http_build_query($queryArgs + ['page'=>$communityPage-1])) ?>">← আগের পেজ</a><?php endif; ?>
                            <span>পৃষ্ঠা <?= number_format($communityPage) ?> / <?= number_format((int)ceil($communityTotalResults/$communityPerPage)) ?></span>
                            <?php if ($communityPage*$communityPerPage < $communityTotalResults): ?><a href="?<?= h(http_build_query($queryArgs + ['page'=>$communityPage+1])) ?>">পরের পেজ →</a><?php endif; ?>
                        </nav>
                    <?php endif; ?>
                <?php endif; ?>
            <?php endif; ?>
        <?php endif; ?>
    </section>
    <?php else: ?>

    <?php if ($notice !== ''): ?>
        <div class="alert"><?= h($notice) ?></div>
    <?php endif; ?>

    <!-- STATISTICS -->

    <section class="stats">

        <article class="stat">
            <div class="stat-label">মোট ব্যবহারকারী</div>

            <div class="stat-value">
                <?= $users === null ? '—' : number_format($users) ?>
            </div>

            <div class="stat-foot">
                <?= $users === null
                    ? 'ব্যবহারকারী টেবিল সংযুক্ত নয়'
                    : 'ডেটাবেজের হিসাব' ?>
            </div>
        </article>

        <article class="stat">
            <div class="stat-label">মোট প্রশ্ন</div>

            <div class="stat-value">
                <?= number_format($totalQuestions) ?>
            </div>

            <div class="stat-foot">প্রশ্ন ব্যাংকে সংরক্ষিত</div>
        </article>

        <article class="stat">
            <div class="stat-label">মডেল টেস্ট</div>

            <div class="stat-value">
                <?= $tests === null ? '—' : number_format($tests) ?>
            </div>

            <div class="stat-foot">ডেটাবেজের হিসাব</div>
        </article>

        <article class="stat">
            <div class="stat-label">মোট নোট</div>

            <div class="stat-value">
                <?= $notes === null ? '—' : number_format($notes) ?>
            </div>

            <div class="stat-foot">নোট ম্যানেজমেন্ট</div>
        </article>

        <article class="stat">
            <div class="stat-label">মোট চাকরির সার্কুলার</div>

            <div class="stat-value">
                <?= number_format($jobTotal) ?>
            </div>

            <div class="stat-foot">সকল সার্কুলার</div>
        </article>

        <article class="stat">
            <div class="stat-label">প্রকাশিত সার্কুলার</div>

            <div class="stat-value">
                <?= number_format($jobPublished) ?>
            </div>

            <div class="stat-foot">Published</div>
        </article>

        <article class="stat">
            <div class="stat-label">Pinned সার্কুলার</div>

            <div class="stat-value">
                <?= number_format($jobPinned) ?>
            </div>

            <div class="stat-foot">উপরে রাখা হয়েছে</div>
        </article>

        <article class="stat">
            <div class="stat-label">Draft সার্কুলার</div>

            <div class="stat-value">
                <?= number_format($jobDraft) ?>
            </div>

            <div class="stat-foot">এখনো প্রকাশিত নয়</div>
        </article>

    </section>

    <!-- SHORTCUTS -->

    <section class="shortcuts">

        <a class="shortcut" href="questions.php">
            প্রশ্ন যোগ করুন
        </a>

        <a class="shortcut" href="notes.php">
            নোট যোগ করুন
        </a>

        <a class="shortcut" href="job_circulars.php">
            ＋ চাকরির সার্কুলার যোগ করুন
        </a>

        <a class="shortcut" href="job_circulars.php">
            সার্কুলার ব্যবস্থাপনা
        </a>

        <a class="shortcut" href="fire_safety_job_prep_dashboard.php?section=marketplace">
            🛒 মার্কেটপ্লেস ব্যবস্থাপনা
        </a>

    </section>

    <!-- RECENT QUESTIONS AND CATEGORIES -->

    <div class="content-grid">

        <section class="panel">

            <div class="panel-head">
                <h2 class="panel-title">সাম্প্রতিক প্রশ্ন</h2>
                <a class="panel-link" href="questions.php">সব দেখুন</a>
            </div>

            <?php if (!$recent): ?>

                <div class="empty">
                    এখনো কোনো প্রশ্ন নেই, অথবা প্রশ্নের তথ্য পাওয়া যায়নি।
                </div>

            <?php else: ?>

                <div class="table-wrap">

                    <table id="recent">

                        <thead>
                            <tr>
                                <th>প্রশ্ন</th>
                                <th>ক্যাটাগরি</th>
                                <th>অবস্থা</th>
                                <th>কাজ</th>
                            </tr>
                        </thead>

                        <tbody>

                        <?php foreach ($recent as $q): ?>

                            <tr>

                                <td
                                    class="q-title"
                                    title="<?= h($q['question']) ?>"
                                >
                                    <?= h($q['question']) ?>
                                </td>

                                <td>
                                    <?= h($q['category'] ?: 'অন্যান্য') ?>
                                </td>

                                <td>
                                    <span class="pill">সংরক্ষিত</span>
                                </td>

                                <td>
                                    <a class="edit" href="questions.php">
                                        দেখুন
                                    </a>
                                </td>

                            </tr>

                        <?php endforeach; ?>

                        </tbody>

                    </table>

                </div>

            <?php endif; ?>

        </section>

        <section class="panel">

            <div class="panel-head">
                <h2 class="panel-title">ক্যাটাগরি অনুযায়ী প্রশ্ন</h2>
            </div>

            <?php if (!$categoryStats): ?>

                <div class="empty">
                    ক্যাটাগরির তথ্য পাওয়া যায়নি।
                </div>

            <?php else: ?>

                <?php foreach ($categoryStats as $i => $c):

                    $n = (int)$c['total'];
                    $width = max(3, round($n / $max * 100));

                ?>

                    <div class="cat-row">

                        <div class="cat-meta">

                            <span class="cat-name">
                                <?= h($c['category_name']) ?>
                            </span>

                            <span class="cat-count">
                                <?= number_format($n) ?>
                            </span>

                        </div>

                        <div class="bar">

                            <span
                                style="
                                    width:<?= $width ?>%;
                                    background:<?= h($colors[$i % count($colors)]) ?>
                                "
                            ></span>

                        </div>

                    </div>

                <?php endforeach; ?>

            <?php endif; ?>

        </section>

    </div>

    <?php endif; ?>

</main>

</div>

<script>
(function () {

    const search = document.getElementById('search');
    const table = document.getElementById('recent');

    if (search && table) {

        search.addEventListener('input', function () {

            const value = this.value.toLocaleLowerCase();

            table.querySelectorAll('tbody tr').forEach(function (row) {

                row.style.display =
                    row.textContent.toLocaleLowerCase().includes(value)
                        ? ''
                        : 'none';

            });

        });

    }

})();
</script>

<script>
(function () {
    const input = document.getElementById('market-image-file');
    const wrap = document.getElementById('market-image-preview');
    const img = document.getElementById('market-image-preview-img');
    const caption = document.getElementById('market-image-preview-caption');
    if (!input || !wrap || !img || !caption) return;
    let temporaryUrl = null;
    const originalSrc = img.getAttribute('src');
    function resetPreview() {
        if (originalSrc) img.src = originalSrc;
        else img.removeAttribute('src');
        caption.textContent = originalSrc ? 'বর্তমান ছবি' : 'নতুন ছবি';
        wrap.hidden = !originalSrc;
    }
    input.addEventListener('change', function () {
        if (temporaryUrl) { URL.revokeObjectURL(temporaryUrl); temporaryUrl = null; }
        const file = input.files && input.files[0];
        if (!file) { resetPreview(); return; }
        if (!['image/jpeg','image/png','image/webp'].includes(file.type)) {
            input.value = ''; resetPreview(); alert('শুধু JPG, PNG অথবা WEBP ছবি নির্বাচন করুন।'); return;
        }
        if (file.size > 5 * 1024 * 1024) {
            input.value = ''; resetPreview(); alert('ছবির আকার সর্বোচ্চ ৫ মেগাবাইট হতে হবে।'); return;
        }
        temporaryUrl = URL.createObjectURL(file);
        img.src = temporaryUrl;
        caption.textContent = 'নতুন ছবি: ' + file.name;
        wrap.hidden = false;
    });
    window.addEventListener('pagehide', function () { if (temporaryUrl) URL.revokeObjectURL(temporaryUrl); });
})();
</script>
</body>
</html>
