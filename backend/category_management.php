<?php
declare(strict_types=1);

require_once __DIR__ . '/admin_helpers.php';
require_admin();
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/category_labels.php';

if (!isset($pdo) || !$pdo instanceof PDO) {
    http_response_code(500);
    exit('Database connection unavailable.');
}

$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

function ch($value): string {
    return htmlspecialchars(
        (string)($value ?? ''),
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );
}

function slugify(string $value): string {
    $value = strtolower(trim($value));
    $value = preg_replace('/[^a-z0-9]+/', '-', $value) ?? '';
    return trim($value, '-') ?: 'category-' . bin2hex(random_bytes(3));
}

$msg = '';
$err = '';
$token = csrf_token();
$labelsReady = category_labels_ready($pdo);

$type = (string)($_GET['type'] ?? 'question');

if (!in_array($type, ['question', 'note', 'test'], true)) {
    $type = 'question';
}

/* =========================
   FORM ACTIONS
========================= */

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        verify_csrf();

        $action = (string)($_POST['action'] ?? '');
        $id = (int)($_POST['id'] ?? 0);

        if ($action === 'save_labels') {
            if (!$labelsReady) throw new RuntimeException('Bilingual SQL migration আগে চালান।');
            if ($id<1) throw new RuntimeException('সঠিক ক্যাটাগরি নির্বাচন করুন।');
            $bn=trim((string)($_POST['name_bn']??''));
            $en=trim((string)($_POST['name_en']??''));
            if ($bn===''||$en===''||mb_strlen($bn,'UTF-8')>120||mb_strlen($en,'UTF-8')>120) {
                throw new RuntimeException('বাংলা ও ইংরেজি নাম দিন (সর্বোচ্চ ১২০ অক্ষর)।');
            }
            $pdo->prepare('UPDATE categories SET name_bn=?,name_en=? WHERE id=?')->execute([$bn,$en,$id]);
            $msg='বাংলা ও ইংরেজি প্রদর্শন নাম সংরক্ষিত হয়েছে।';
        } elseif ($action === 'create_shared') {
            // Keep the legacy typed IDs and text-based question lookup. Create
            // the missing root categories together, without renaming existing ones.
            $name = trim((string)($_POST['shared_name'] ?? ''));
            if ($name === '' || mb_strlen($name, 'UTF-8') > 100) {
                throw new RuntimeException('বিষয়ের নাম দিন (সর্বোচ্চ ১০০ অক্ষর)।');
            }
            $pdo->beginTransaction();
            $find = $pdo->prepare('SELECT id,parent_id,is_active FROM categories WHERE category_type=? AND name=? FOR UPDATE');
            $insert = $pdo->prepare('INSERT INTO categories(name,slug,category_type,parent_id,sort_order,is_active) VALUES(?,?,?,NULL,0,1)');
            $created = 0;
            foreach (['question','note','test'] as $kind) {
                $find->execute([$kind,$name]);
                $matches = $find->fetchAll(PDO::FETCH_ASSOC);
                if ($matches) {
                    if (count($matches) !== 1 || $matches[0]['parent_id'] !== null || !(int)$matches[0]['is_active']) {
                        throw new RuntimeException('একই নামের নিষ্ক্রিয় বা সাব-ক্যাটাগরি আছে। সংশ্লিষ্ট ট্যাব থেকে আগে ঠিক করুন।');
                    }
                    continue;
                }
                $base = substr(slugify($name), 0, 75);
                $insert->execute([$name,$base.'-'.$kind.'-'.bin2hex(random_bytes(4)),$kind]);
                ++$created;
            }
            $pdo->commit();
            $msg = $created > 0
                ? 'তিন সেকশনের জন্য বিষয় প্রস্তুত। নতুন ক্যাটাগরি: '.$created
                : 'এই বিষয়টি তিন সেকশনেই আগে থেকে আছে।';
        } elseif ($action === 'save') {

            $name = trim((string)($_POST['name'] ?? ''));
            $categoryType = (string)($_POST['category_type'] ?? '');
            $parent = (int)($_POST['parent_id'] ?? 0);
            $sort = (int)($_POST['sort_order'] ?? 0);

            if ($name === '' || mb_strlen($name, 'UTF-8') > 120) {
                throw new RuntimeException(
                    'ক্যাটাগরির নাম দিন (সর্বোচ্চ ১২০ অক্ষর)।'
                );
            }

            if (in_array($categoryType, ['question','test'], true) && mb_strlen($name,'UTF-8') > 100) {
                throw new RuntimeException('প্রশ্ন ও পরীক্ষার ক্যাটাগরি সর্বোচ্চ ১০০ অক্ষর।');
            }
            if (!in_array($categoryType, ['question', 'note', 'test'], true)) {
                throw new RuntimeException('ক্যাটাগরির ধরন সঠিক নয়।');
            }

            // Parent validation
            if ($parent > 0) {
                $p = $pdo->prepare("
                    SELECT category_type
                    FROM categories
                    WHERE id = ?
                    AND is_active = 1
                    AND parent_id IS NULL
                ");

                $p->execute([$parent]);

                if ($p->fetchColumn() !== $categoryType) {
                    throw new RuntimeException(
                        'একই ধরনের সক্রিয় Parent নির্বাচন করুন।'
                    );
                }

                if ($id === $parent) {
                    throw new RuntimeException(
                        'নিজেকে Parent করা যাবে না।'
                    );
                }
            }

            // Duplicate category check
            $sql = "
                SELECT id
                FROM categories
                WHERE category_type = ?
                AND name = ?
                AND " . ($parent ? "parent_id = ?" : "parent_id IS NULL") . "
                AND id <> ?
                LIMIT 1
            ";

            $params = [$categoryType, $name];

            if ($parent) {
                $params[] = $parent;
            }

            $params[] = $id;

            $duplicate = $pdo->prepare($sql);
            $duplicate->execute($params);

            if ($duplicate->fetchColumn()) {
                throw new RuntimeException(
                    'এই Parent-এর অধীনে একই নামের ক্যাটাগরি আছে।'
                );
            }

            if ($id > 0) {

                $old = $pdo->prepare("
                    SELECT category_type,name
                    FROM categories
                    WHERE id = ?
                ");

                $old->execute([$id]);
                $oldRow = $old->fetch(PDO::FETCH_ASSOC);
                $oldType = $oldRow['category_type'] ?? null;

                if (!$oldType) {
                    throw new RuntimeException('ক্যাটাগরি পাওয়া যায়নি।');
                }

                if ($oldType !== $categoryType) {
                    throw new RuntimeException(
                        'ক্যাটাগরির ধরন পরিবর্তন করা যাবে না।'
                    );
                }

                if ($oldRow['name'] !== $name && in_array($oldType,['question','test'],true)) {
                    $linked = $pdo->prepare('SELECT COUNT(*) FROM questions WHERE category=?');
                    $linked->execute([$oldRow['name']]);
                    if ((int)$linked->fetchColumn() > 0) {
                        throw new RuntimeException('এই নামে প্রশ্ন রয়েছে। ডেটা সংযোগ রক্ষায় নতুন ক্যাটাগরি তৈরি করুন; নাম পরিবর্তন করা যাবে না।');
                    }
                    if ($oldType === 'test') {
                        $linked = $pdo->prepare('SELECT COUNT(*) FROM model_tests WHERE category_id=?');
                        $linked->execute([$id]);
                        if ((int)$linked->fetchColumn() > 0) throw new RuntimeException('এই ক্যাটাগরিতে মডেল টেস্ট আছে; নাম পরিবর্তন করা যাবে না।');
                    }
                }
                if ($parent > 0) {
                    $childCheck = $pdo->prepare('SELECT COUNT(*) FROM categories WHERE parent_id=?');
                    $childCheck->execute([$id]);
                    if ((int)$childCheck->fetchColumn() > 0) throw new RuntimeException('সাব-ক্যাটাগরি আছে এমন ক্যাটাগরিকে অন্য Parent-এর নিচে নেওয়া যাবে না।');
                }

                $update = $pdo->prepare("
                    UPDATE categories
                    SET name = ?,
                        slug = ?,
                        parent_id = ?,
                        sort_order = ?
                    WHERE id = ?
                ");

                $update->execute([
                    $name,
                    slugify($name),
                    $parent ?: null,
                    $sort,
                    $id
                ]);

                $msg = 'ক্যাটাগরি আপডেট হয়েছে।';

            } else {

                $insert = $pdo->prepare("
                    INSERT INTO categories
                    (
                        name,
                        slug,
                        category_type,
                        parent_id,
                        sort_order,
                        is_active
                    )
                    VALUES (?, ?, ?, ?, ?, 1)
                ");

                $insert->execute([
                    $name,
                    slugify($name),
                    $categoryType,
                    $parent ?: null,
                    $sort
                ]);

                $msg = 'নতুন ক্যাটাগরি তৈরি হয়েছে।';
            }

        } elseif ($action === 'toggle') {

            if (!$id) {
                throw new RuntimeException('সঠিক ক্যাটাগরি নির্বাচন করুন।');
            }

            $toggle = $pdo->prepare("
                UPDATE categories
                SET is_active = IF(is_active = 1, 0, 1)
                WHERE id = ?
            ");

            $toggle->execute([$id]);

            $msg = 'Active status পরিবর্তন হয়েছে।';

        } elseif ($action === 'delete') {

            $find = $pdo->prepare("
                SELECT name, category_type
                FROM categories
                WHERE id = ?
            ");

            $find->execute([$id]);
            $category = $find->fetch(PDO::FETCH_ASSOC);

            if (!$category) {
                throw new RuntimeException('ক্যাটাগরি পাওয়া যায়নি।');
            }

            // Child category check
            $children = $pdo->prepare("
                SELECT COUNT(*)
                FROM categories
                WHERE parent_id = ?
            ");

            $children->execute([$id]);

            if ((int)$children->fetchColumn() > 0) {
                throw new RuntimeException(
                    'সাব-ক্যাটাগরি আছে; আগে সেগুলো সরান।'
                );
            }

            // Content check
            if ($category['category_type'] === 'note') {

                $content = $pdo->prepare("
                    SELECT COUNT(*)
                    FROM notes
                    WHERE category_id = ?
                ");

                $content->execute([$id]);

            } elseif ($category['category_type'] === 'test') {
                $content = $pdo->prepare('SELECT COUNT(*) FROM model_tests WHERE category_id=?');
                $content->execute([$id]);

            } else {

                $content = $pdo->prepare("
                    SELECT COUNT(*)
                    FROM questions
                    WHERE category = ?
                ");

                $content->execute([$category['name']]);
            }

            if ((int)$content->fetchColumn() > 0) {
                throw new RuntimeException(
                    'এই ক্যাটাগরিতে কনটেন্ট আছে। ডেটা রক্ষায় Delete নয়, Inactive করুন।'
                );
            }

            $delete = $pdo->prepare("
                DELETE FROM categories
                WHERE id = ?
            ");

            $delete->execute([$id]);

            $msg = 'ক্যাটাগরি মুছে ফেলা হয়েছে।';
        }

    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        $err = $e instanceof PDOException ? 'ক্যাটাগরি সংরক্ষণ হয়নি। ডেটাবেসের কাঠামো যাচাই করুন।' : $e->getMessage();
        if ($e instanceof PDOException) error_log('Category management: '.$e->getMessage());
    }
}

/* =========================
   LOAD CATEGORY DATA
========================= */

// Edit category
$edit = null;

if (isset($_GET['edit'])) {
    $statement = $pdo->prepare("
        SELECT *
        FROM categories
        WHERE id = ?
    ");

    $statement->execute([(int)$_GET['edit']]);
    $edit = $statement->fetch(PDO::FETCH_ASSOC) ?: null;

    if ($edit) {
        $type = $edit['category_type'];
    }
}

// Category list
$statement = $pdo->prepare("
    SELECT
        c.*,
        p.name AS parent_name,
        (
            SELECT COUNT(*)
            FROM categories x
            WHERE x.parent_id = c.id
        ) AS child_count
    FROM categories c
    LEFT JOIN categories p ON p.id = c.parent_id
    WHERE c.category_type = ?
    ORDER BY
        COALESCE(c.parent_id, c.id),
        c.parent_id IS NOT NULL,
        c.sort_order,
        c.name
");

$statement->execute([$type]);
$rows = $statement->fetchAll(PDO::FETCH_ASSOC);

// Parent categories
$statement = $pdo->prepare("
    SELECT id, name
    FROM categories
    WHERE category_type = ?
    AND parent_id IS NULL
    AND is_active = 1
    ORDER BY sort_order, name
");

$statement->execute([$type]);
$parents = $statement->fetchAll(PDO::FETCH_ASSOC);

// Statistics
$statement = $pdo->query("
    SELECT
        category_type,
        COUNT(*) AS total,
        SUM(is_active = 1) AS active
    FROM categories
    WHERE category_type IN ('question', 'note', 'test')
    GROUP BY category_type
");

$counts = [
    'question' => [0, 0],
    'note' => [0, 0],
    'test' => [0, 0]
];

foreach ($statement->fetchAll(PDO::FETCH_ASSOC) as $row) {
    $counts[$row['category_type']] = [
        (int)$row['total'],
        (int)$row['active']
    ];
}
?>

<!DOCTYPE html>
<html lang="bn">

<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Category Management | Fire Safety BD</title>

<style>

:root {
    --maroon: #58101d;
    --maroon-dark: #420b16;
    --orange: #e87524;
    --background: #f5f6fa;
    --white: #ffffff;
    --text: #292632;
    --muted: #7b7b85;
    --border: #e7e7ed;
    --green: #198754;
    --red: #c0392b;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: var(--background);
    color: var(--text);
    font-family: Arial, "Noto Sans Bengali", sans-serif;
}

.layout {
    min-height: 100vh;
    display: grid;
    grid-template-columns: 258px minmax(0, 1fr);
}

/* SIDEBAR */

.sidebar {
    background: var(--maroon);
    color: white;
    padding: 24px 16px;
    min-height: 100vh;
}

.brand {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 5px 9px 25px;
    text-decoration: none;
    color: white;
}

.brand img {
    width: 45px;
    height: 45px;
    object-fit: contain;
    border-radius: 9px;
    background: white;
}

.brand-name {
    font-size: 19px;
    font-weight: 800;
}

.brand-sub {
    font-size: 11px;
    color: #e9cbd1;
    margin-top: 4px;
}

.nav-title {
    font-size: 10px;
    letter-spacing: 1.2px;
    color: #d8b8bf;
    padding: 12px 11px;
    font-weight: bold;
}

.nav-list {
    display: flex;
    flex-direction: column;
    gap: 5px;
}

.nav-link {
    display: flex;
    align-items: center;
    gap: 11px;
    padding: 12px 13px;
    color: #fff;
    text-decoration: none;
    border-radius: 8px;
    font-size: 13px;
    transition: .2s;
}

.nav-link:hover {
    background: rgba(255,255,255,.12);
}

.nav-link.active {
    background: var(--orange);
    color: white;
    font-weight: bold;
}

.sidebar-bottom {
    margin-top: 35px;
    padding: 15px 10px;
    border-top: 1px solid rgba(255,255,255,.15);
    color: #e5c6cd;
    font-size: 11px;
    line-height: 1.7;
}

/* MAIN AREA */

.main {
    width: 100%;
    max-width: 1550px;
    padding: 28px;
    margin: 0 auto;
}

.topbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 15px;
    margin-bottom: 23px;
}

.eyebrow {
    color: var(--muted);
    font-size: 11px;
    margin-bottom: 7px;
}

.page-title {
    font-size: 26px;
    color: var(--maroon);
    margin: 0;
}

.page-description {
    font-size: 12px;
    color: var(--muted);
    margin-top: 7px;
}

.top-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

/* BUTTONS */

.btn {
    display: inline-flex;
    justify-content: center;
    align-items: center;
    border: none;
    border-radius: 7px;
    padding: 10px 13px;
    font-size: 12px;
    font-weight: bold;
    text-decoration: none;
    cursor: pointer;
    white-space: nowrap;
}

.btn-orange {
    background: var(--orange);
    color: white;
}

.btn-maroon {
    background: var(--maroon);
    color: white;
}

.btn-light {
    background: #f3edf0;
    color: var(--maroon);
}

.btn-red {
    background: var(--red);
    color: white;
}

.btn:hover {
    opacity: .88;
}

/* ALERT */

.alert {
    padding: 13px 15px;
    border-radius: 8px;
    margin-bottom: 16px;
    font-size: 13px;
}

.alert-success {
    background: #e6f6ec;
    color: #17663b;
}

.alert-error {
    background: #fff0f0;
    color: #a21d2b;
}

/* STATISTICS */

.stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 15px;
    margin-bottom: 20px;
}

.stat-card {
    background: white;
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 19px;
    box-shadow: 0 3px 12px rgba(0,0,0,.025);
}

.stat-label {
    color: var(--muted);
    font-size: 12px;
}

.stat-value {
    color: var(--maroon);
    font-size: 29px;
    font-weight: 800;
    margin: 9px 0 5px;
}

.stat-note {
    font-size: 11px;
    color: var(--green);
}

/* TABS */

.tabs {
    display: flex;
    gap: 8px;
    margin-bottom: 17px;
}

.tab {
    padding: 10px 16px;
    border-radius: 7px;
    background: #eee9ec;
    color: var(--maroon);
    text-decoration: none;
    font-size: 13px;
    font-weight: bold;
}

.tab.active {
    background: var(--maroon);
    color: white;
}

/* CONTENT GRID */

.content-grid {
    display: grid;
    grid-template-columns: minmax(280px, .8fr) minmax(420px, 1.5fr);
    gap: 17px;
    align-items: start;
}

.panel {
    background: white;
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 3px 12px rgba(0,0,0,.025);
}

.panel-title {
    color: var(--maroon);
    font-size: 17px;
    font-weight: bold;
    margin: 0 0 17px;
}

/* FORM */

label {
    display: block;
    font-size: 12px;
    font-weight: bold;
    margin: 13px 0 7px;
}

input,
select {
    width: 100%;
    padding: 11px 12px;
    border: 1px solid #d9d9e0;
    border-radius: 7px;
    outline: none;
    background: white;
    color: var(--text);
    font-size: 13px;
}

input:focus,
select:focus {
    border-color: var(--orange);
    box-shadow: 0 0 0 3px rgba(232,117,36,.10);
}

.form-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-top: 17px;
}

.help-text {
    font-size: 11px;
    color: var(--muted);
    line-height: 1.7;
    margin-top: 14px;
}

/* TABLE */

.table-wrap {
    width: 100%;
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
    min-width: 610px;
}

th,
td {
    padding: 12px 10px;
    border-bottom: 1px solid var(--border);
    text-align: left;
    font-size: 12px;
    vertical-align: middle;
}

th {
    background: #faf6f7;
    color: var(--maroon);
    font-weight: bold;
}

td {
    color: #444;
}

.category-name {
    font-weight: bold;
    color: #302b31;
}

.child-category {
    padding-left: 24px;
    color: #666;
}

.parent-info {
    color: var(--muted);
    font-size: 10px;
    margin-top: 4px;
}

.status {
    display: inline-block;
    padding: 5px 9px;
    border-radius: 20px;
    background: #e5f6eb;
    color: #17663b;
    font-size: 10px;
    font-weight: bold;
}

.status.inactive {
    background: #f4e8eb;
    color: #8b3447;
}

.action-group {
    display: flex;
    gap: 5px;
    flex-wrap: wrap;
}

.action-group form {
    display: inline;
}

.empty-state {
    text-align: center;
    padding: 30px 12px;
    color: var(--muted);
}

/* RESPONSIVE */

@media (max-width: 1050px) {

    .layout {
        grid-template-columns: 1fr;
    }

    .sidebar {
        min-height: auto;
        padding: 13px;
    }

    .brand {
        padding: 3px 7px 12px;
    }

    .nav-title,
    .sidebar-bottom {
        display: none;
    }

    .nav-list {
        display: flex;
        flex-direction: row;
        overflow-x: auto;
        gap: 5px;
        padding-bottom: 4px;
    }

    .nav-link {
        white-space: nowrap;
        padding: 10px 12px;
    }

    .main {
        padding: 20px 15px;
    }

    .content-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 600px) {

    .page-title {
        font-size: 21px;
    }

    .stats {
        grid-template-columns: 1fr 1fr;
        gap: 9px;
    }

    .stat-card {
        padding: 13px;
    }

    .stat-value {
        font-size: 23px;
    }

    .panel {
        padding: 14px;
    }

    .topbar {
        align-items: flex-start;
    }

    .top-actions {
        width: 100%;
    }
}

</style>
</head>

<body>

<div class="layout">

    <!-- SIDEBAR -->

    <aside class="sidebar">

        <a class="brand"
           href="fire_safety_job_prep_dashboard.php">

            <img
                src="assets/fire-safety-bd-logo.png?v=177"
                alt="Fire Safety BD Logo"
                onerror="this.style.display='none'"
            >

            <div>
                <div class="brand-name">Fire Safety BD</div>
                <div class="brand-sub">Admin Control Panel</div>
            </div>

        </a>

        <div class="nav-title">MAIN MENU</div>

        <nav class="nav-list">

            <a class="nav-link"
               href="fire_safety_job_prep_dashboard.php">
                ▦ Dashboard
            </a>

            <a class="nav-link" href="questions.php">
                ▤ Question Bank
            </a>

            <a class="nav-link" href="model_tests.php">
                ☑ Model Tests
            </a>

            <a class="nav-link" href="notes.php">
                ▤ Notes
            </a>

            <a class="nav-link" href="job_circulars.php">
                ▣ Job Circulars
            </a>

            <a class="nav-link active"
               href="category_management.php">
                ▦ Categories
            </a>

            <a class="nav-link" href="logout.php">
                ↪ Logout
            </a>

        </nav>

        <div class="sidebar-bottom">
            Fire Safety BD<br>
            Admin Management System
        </div>

    </aside>


    <!-- MAIN CONTENT -->

    <main class="main">

        <!-- HEADER -->

        <header class="topbar">

            <div>

                <div class="eyebrow">
                    Admin / Category Management
                </div>

                <h1 class="page-title">
                    ক্যাটাগরি ব্যবস্থাপনা
                </h1>

                <div class="page-description">
                    Question Bank, Notes ও Model Test-এর Category এবং Sub-category এক জায়গা থেকে পরিচালনা করুন।
                </div>

            </div>

            <div class="top-actions">

                <a class="btn btn-light"
                   href="fire_safety_job_prep_dashboard.php">
                    ← Dashboard
                </a>

            </div>

        </header>


        <!-- NOTIFICATIONS -->

        <?php if ($msg): ?>

            <div class="alert alert-success">
                <?= ch($msg) ?>
            </div>

        <?php endif; ?>


        <?php if ($err): ?>

            <div class="alert alert-error">
                <?= ch($err) ?>
            </div>

        <?php endif; ?>


        <!-- STATISTICS -->

        <section class="stats">

            <div class="stat-card">

                <div class="stat-label">
                    Question Categories
                </div>

                <div class="stat-value">
                    <?= $counts['question'][0] ?>
                </div>

                <div class="stat-note">
                    <?= $counts['question'][1] ?> Active Categories
                </div>

            </div>


            <div class="stat-card">

                <div class="stat-label">
                    Notes Categories
                </div>

                <div class="stat-value">
                    <?= $counts['note'][0] ?>
                </div>

                <div class="stat-note">
                    <?= $counts['note'][1] ?> Active Categories
                </div>

            </div>

            <div class="stat-card">
                <div class="stat-label">Model Test Categories</div>
                <div class="stat-value"><?= $counts['test'][0] ?></div>
                <div class="stat-note"><?= $counts['test'][1] ?> Active Categories</div>
            </div>
        </section>

        <section class="panel" style="margin:16px 0">
            <h2 class="panel-title">একই বিষয় তিন সেকশনে তৈরি করুন</h2>
            <form method="post">
                <input type="hidden" name="csrf_token" value="<?= ch($token) ?>">
                <input type="hidden" name="action" value="create_shared">
                <label>বিষয়ের নাম (Question Bank + Notes + Model Test)</label>
                <input type="text" name="shared_name" maxlength="100" required placeholder="যেমন: NFPA 10">
                <div class="form-actions"><button class="btn btn-orange" type="submit">Create in all three sections</button></div>
            </form>
            <p class="help-text">বিদ্যমান সক্রিয় মূল ক্যাটাগরি পুনরায় তৈরি হবে না। প্রতিটি সেকশনের নিজস্ব ID অক্ষত থাকবে। একই নামের প্রশ্ন থেকে Model Test তৈরি করা যাবে। প্রকাশিত কনটেন্টের অবস্থা সংশ্লিষ্ট কনটেন্ট পেজ থেকে পরিচালনা করুন।</p>
        </section>

        <!-- CATEGORY TABS -->

        <div class="tabs">

            <a
                class="tab <?= $type === 'question' ? 'active' : '' ?>"
                href="?type=question"
            >
                Question Categories
            </a>

            <a
                class="tab <?= $type === 'note' ? 'active' : '' ?>"
                href="?type=note"
            >
                Notes Categories
            </a>
            <a class="tab <?= $type === 'test' ? 'active' : '' ?>" href="?type=test">
                Model Test Categories
            </a>

        </div>


        <!-- FORM AND CATEGORY LIST -->

        <div class="content-grid">


            <!-- CATEGORY FORM -->

            <section class="panel">

                <h2 class="panel-title">

                    <?= $edit
                        ? 'ক্যাটাগরি সম্পাদনা'
                        : 'নতুন ক্যাটাগরি তৈরি'
                    ?>

                </h2>


                <form method="post">

                    <input
                        type="hidden"
                        name="csrf_token"
                        value="<?= ch($token) ?>"
                    >

                    <input
                        type="hidden"
                        name="action"
                        value="save"
                    >

                    <input
                        type="hidden"
                        name="id"
                        value="<?= (int)($edit['id'] ?? 0) ?>"
                    >


                    <label>
                        ক্যাটাগরির ধরন
                    </label>

                    <select
                        name="category_type"
                        <?= $edit ? 'disabled' : '' ?>
                    >

                        <option
                            value="question"
                            <?= $type === 'question' ? 'selected' : '' ?>
                        >
                            Questions
                        </option>

                        <option
                            value="note"
                            <?= $type === 'note' ? 'selected' : '' ?>
                        >
                            Notes
                        </option>
                        <option value="test" <?= $type === 'test' ? 'selected' : '' ?>>Model Tests</option>

                    </select>


                    <?php if ($edit): ?>

                        <input
                            type="hidden"
                            name="category_type"
                            value="<?= ch($edit['category_type']) ?>"
                        >

                    <?php endif; ?>


                    <label>
                        ক্যাটাগরির নাম
                    </label>

                    <input
                        type="text"
                        name="name"
                        maxlength="120"
                        required
                        value="<?= ch($edit['name'] ?? '') ?>"
                        placeholder="যেমন: NFPA 10"
                    >


                    <label>
                        Parent Category (ঐচ্ছিক)
                    </label>

                    <select name="parent_id">

                        <option value="0">
                            মূল ক্যাটাগরি
                        </option>

                        <?php foreach ($parents as $parent): ?>

                            <?php
                            if (
                                (int)$parent['id'] ===
                                (int)($edit['id'] ?? 0)
                            ) {
                                continue;
                            }
                            ?>

                            <option
                                value="<?= (int)$parent['id'] ?>"
                                <?= (
                                    (int)($edit['parent_id'] ?? 0) ===
                                    (int)$parent['id']
                                ) ? 'selected' : '' ?>
                            >

                                <?= ch($parent['name']) ?>

                            </option>

                        <?php endforeach; ?>

                    </select>


                    <label>
                        Sort Order
                    </label>

                    <input
                        type="number"
                        name="sort_order"
                        value="<?= (int)($edit['sort_order'] ?? 0) ?>"
                    >


                    <div class="form-actions">

                        <button
                            class="btn btn-orange"
                            type="submit"
                        >

                            <?= $edit ? 'Update Category' : '+ Create Category' ?>

                        </button>


                        <?php if ($edit): ?>

                            <a
                                class="btn btn-light"
                                href="?type=<?= ch($type) ?>"
                            >
                                বাতিল
                            </a>

                        <?php endif; ?>

                    </div>

                </form>


                <?php if ($edit && $labelsReady): ?>
                <form method="post" style="margin-top:16px">
                    <input type="hidden" name="csrf_token" value="<?= ch($token) ?>">
                    <input type="hidden" name="action" value="save_labels">
                    <input type="hidden" name="id" value="<?= (int)$edit['id'] ?>">
                    <h3>বাংলা / English প্রদর্শন নাম</h3>
                    <label>বাংলা নাম</label>
                    <input name="name_bn" maxlength="120" required value="<?= ch($edit['name_bn'] ?: $edit['name']) ?>">
                    <label>English name</label>
                    <input name="name_en" maxlength="120" required value="<?= ch($edit['name_en'] ?: $edit['name']) ?>">
                    <div class="form-actions"><button class="btn btn-orange" type="submit">Save display names</button></div>
                    <p class="help-text">মূল name/ID পরিবর্তন হবে না। NFPA, BNBC, RSC-এর মতো নাম ইংরেজিতে রাখুন।</p>
                </form>
                <?php elseif (!$labelsReady): ?>
                    <p class="help-text">দ্বিভাষিক নাম চালু করতে Bilingual SQL migration চালান।</p>
                <?php endif; ?>
                <p class="help-text">

                    <strong>নির্দেশনা:</strong><br>

                    Parent Category নির্বাচন না করলে এটি মূল ক্যাটাগরি হবে।
                    Parent নির্বাচন করলে এটি Sub-category হিসেবে তৈরি হবে।

                </p>

            </section>



            <!-- CATEGORY TABLE -->

            <section class="panel">

                <h2 class="panel-title">

                    <?= ch(['question'=>'Questions','note'=>'Notes','test'=>'Model Tests'][$type] ?? 'Questions') ?>
                    ক্যাটাগরি তালিকা

                </h2>


                <div class="table-wrap">

                    <table>

                        <thead>

                            <tr>

                                <th>Category Name</th>
                                <th>Type</th>
                                <th>Order</th>
                                <th>Status</th>
                                <th>Action</th>

                            </tr>

                        </thead>


                        <tbody>

                            <?php if (!$rows): ?>

                                <tr>

                                    <td colspan="5">

                                        <div class="empty-state">

                                            এখনো কোনো ক্যাটাগরি তৈরি করা হয়নি।

                                        </div>

                                    </td>

                                </tr>

                            <?php endif; ?>


                            <?php foreach ($rows as $row): ?>

                                <tr>

                                    <td>

                                        <div class="category-name <?= $row['parent_id'] ? 'child-category' : '' ?>">

                                            <?= $row['parent_id'] ? '↳ ' : '' ?>

                                            <?= ch($row['name']) ?>
                                            <?php if($labelsReady): ?><div class="parent-info">বাংলা: <?= ch($row['name_bn'] ?: '—') ?> · English: <?= ch($row['name_en'] ?: '—') ?></div><?php endif; ?>

                                        </div>


                                        <?php if ($row['parent_name']): ?>

                                            <div class="parent-info">

                                                Parent:
                                                <?= ch($row['parent_name']) ?>

                                            </div>

                                        <?php endif; ?>

                                    </td>


                                    <td>

                                        <?= $row['parent_id']
                                            ? 'Sub-category'
                                            : 'Main Category'
                                        ?>

                                    </td>


                                    <td>
                                        <?= (int)$row['sort_order'] ?>
                                    </td>


                                    <td>

                                        <span class="status <?= $row['is_active'] ? '' : 'inactive' ?>">

                                            <?= $row['is_active']
                                                ? 'Active'
                                                : 'Inactive'
                                            ?>

                                        </span>

                                    </td>


                                    <td>

                                        <div class="action-group">


                                            <!-- EDIT -->

                                            <a
                                                class="btn btn-light"
                                                href="?type=<?= ch($type) ?>&edit=<?= (int)$row['id'] ?>"
                                            >
                                                Edit
                                            </a>


                                            <!-- ENABLE / DISABLE -->

                                            <form method="post">

                                                <input
                                                    type="hidden"
                                                    name="csrf_token"
                                                    value="<?= ch($token) ?>"
                                                >

                                                <input
                                                    type="hidden"
                                                    name="action"
                                                    value="toggle"
                                                >

                                                <input
                                                    type="hidden"
                                                    name="id"
                                                    value="<?= (int)$row['id'] ?>"
                                                >

                                                <button
                                                    class="btn btn-maroon"
                                                    type="submit"
                                                >

                                                    <?= $row['is_active']
                                                        ? 'Disable'
                                                        : 'Enable'
                                                    ?>

                                                </button>

                                            </form>


                                            <!-- DELETE -->

                                            <form
                                                method="post"
                                                onsubmit="return confirm('আপনি কি নিশ্চিতভাবে এই ক্যাটাগরি Delete করতে চান?');"
                                            >

                                                <input
                                                    type="hidden"
                                                    name="csrf_token"
                                                    value="<?= ch($token) ?>"
                                                >

                                                <input
                                                    type="hidden"
                                                    name="action"
                                                    value="delete"
                                                >

                                                <input
                                                    type="hidden"
                                                    name="id"
                                                    value="<?= (int)$row['id'] ?>"
                                                >

                                                <button
                                                    class="btn btn-red"
                                                    type="submit"
                                                >
                                                    Delete
                                                </button>

                                            </form>


                                        </div>

                                    </td>

                                </tr>

                            <?php endforeach; ?>

                        </tbody>

                    </table>

                </div>

            </section>


        </div>

    </main>

</div>

</body>
</html>