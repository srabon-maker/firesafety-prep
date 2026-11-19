<?php
require_once __DIR__ . '/admin_helpers.php';
require_admin();
require_once __DIR__ . '/db.php';

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

if (!isset($pdo) || !($pdo instanceof PDO)) {
    die('Database connection not found. Please check db.php.');
}

$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

if (empty($_SESSION['notes_csrf_token'])) {
    $_SESSION['notes_csrf_token'] = bin2hex(random_bytes(32));
}

function nh($value): string
{
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES, 'UTF-8');
}

function notesDateInput($value): string
{
    if (!$value) {
        return '';
    }

    $timestamp = strtotime($value);
    return $timestamp ? date('Y-m-d\TH:i', $timestamp) : '';
}


/** Sanitize HTML produced by the Notes rich-text editor. */
function notesSanitizeHtml(string $html): string
{
    $html = strip_tags($html, '<p><br><strong><b><em><i><u><s><h1><h2><h3><h4><ol><ul><li><blockquote><pre><code><a><img><table><thead><tbody><tr><th><td>');
    $html = preg_replace('/\s+on[a-z]+\s*=\s*("[^"]*"|\'[^\']*\'|[^\s>]+)/i', '', $html);
    $html = preg_replace('/(href|src)\s*=\s*(["\'])(?!https?:\/\/|\/?uploads\/notes\/)[^"\']*\2/i', '$1="#"', $html);
    $html = preg_replace('/\s+style\s*=\s*("[^"]*"|\'[^\']*\')/i', '', $html);
    return $html;
}

function notesEnsureUploadDirectory(string $relativePath): string
{
    $directory = __DIR__ . '/' . trim($relativePath, '/');
    if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
        throw new RuntimeException('Upload directory could not be created.');
    }
    $htaccess = dirname($directory) . '/.htaccess';
    if (!is_file($htaccess)) {
        @file_put_contents($htaccess, "Options -Indexes\n<FilesMatch \"\\.(php|phtml|phar|php[0-9]*)$\">\nRequire all denied\n</FilesMatch>\n");
    }
    return $directory;
}

function notesStoreUpload(array $file, string $kind = 'attachment'): array
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        throw new RuntimeException('File upload failed. Please try again.');
    }
    $maxBytes = $kind === 'image' ? 5 * 1024 * 1024 : 15 * 1024 * 1024;
    if (($file['size'] ?? 0) <= 0 || $file['size'] > $maxBytes) {
        throw new RuntimeException($kind === 'image' ? 'Image size must be under 5 MB.' : 'Attachment size must be under 15 MB.');
    }

    $extension = strtolower(pathinfo((string)($file['name'] ?? ''), PATHINFO_EXTENSION));
    $mime = '';
    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        if ($finfo) {
            $mime = (string)finfo_file($finfo, $file['tmp_name']);
            finfo_close($finfo);
        }
    }

    $allowed = $kind === 'image'
        ? ['jpg' => ['image/jpeg'], 'jpeg' => ['image/jpeg'], 'png' => ['image/png'], 'webp' => ['image/webp'], 'gif' => ['image/gif']]
        : ['pdf' => ['application/pdf'], 'doc' => ['application/msword', 'application/vnd.ms-office', 'application/octet-stream'], 'docx' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/zip', 'application/octet-stream']];

    if (!isset($allowed[$extension]) || ($mime !== '' && !in_array($mime, $allowed[$extension], true))) {
        throw new RuntimeException($kind === 'image' ? 'Only JPG, PNG, WEBP and GIF images are allowed.' : 'Only PDF, DOC and DOCX files are allowed.');
    }

    $relative = $kind === 'image' ? 'uploads/notes/images' : 'uploads/notes/files';
    $directory = notesEnsureUploadDirectory($relative);
    $filename = bin2hex(random_bytes(16)) . '.' . $extension;
    if (!is_uploaded_file($file['tmp_name']) || !move_uploaded_file($file['tmp_name'], $directory . '/' . $filename)) {
        throw new RuntimeException('The uploaded file could not be saved.');
    }
    return ['url' => $relative . '/' . $filename, 'extension' => $extension];
}

$message = '';
$error = '';

$allowedStatuses = ['draft', 'published', 'archived'];
$allowedFileTypes = ['none', 'pdf', 'doc', 'docx', 'other'];

/*
|--------------------------------------------------------------------------
| Load note categories
|--------------------------------------------------------------------------
*/

try {
    $categoryStmt = $pdo->query("
        SELECT id, name
        FROM categories
        WHERE category_type = 'note'
          AND is_active = 1
        ORDER BY sort_order ASC, name ASC
    ");

    $categories = $categoryStmt->fetchAll(PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    $categories = [];
    $error = 'Category loading failed. Please check the categories table.';
}

/*
|--------------------------------------------------------------------------
| Handle form submissions
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $token = (string)($_POST['csrf_token'] ?? '');

        if (
            empty($_SESSION['notes_csrf_token']) ||
            !hash_equals($_SESSION['notes_csrf_token'], $token)
        ) {
            throw new RuntimeException('Invalid request token. Please refresh the page and try again.');
        }

        $action = (string)($_POST['action'] ?? '');

        if ($action === 'upload_inline_image') {
            header('Content-Type: application/json; charset=utf-8');
            $stored = notesStoreUpload($_FILES['inline_image'] ?? [], 'image');
            echo json_encode(['success' => true, 'url' => $stored['url']]);
            exit;
        }

        /*
        |--------------------------------------------------------------------------
        | Delete note
        |--------------------------------------------------------------------------
        */

        if ($action === 'delete') {
            $deleteId = (int)($_POST['note_id'] ?? 0);

            if ($deleteId <= 0) {
                throw new RuntimeException('Invalid Note ID.');
            }

            $stmt = $pdo->prepare("DELETE FROM notes WHERE id = ?");
            $stmt->execute([$deleteId]);

            header('Location: notes.php?deleted=1');
            exit;
        }

        /*
        |--------------------------------------------------------------------------
        | Save note
        |--------------------------------------------------------------------------
        */

        if ($action === 'save') {
            $noteId = (int)($_POST['note_id'] ?? 0);

            $title = trim((string)($_POST['title'] ?? ''));
            $summary = trim((string)($_POST['summary'] ?? ''));
            $content = notesSanitizeHtml((string)($_POST['content'] ?? ''));
            $fileUrl = trim((string)($_POST['file_url'] ?? ''));

            $categoryId = (int)($_POST['category_id'] ?? 0);
            $fileType = (string)($_POST['file_type'] ?? 'none');

            if (!empty($_FILES['attachment']['name'])) {
                $storedAttachment = notesStoreUpload($_FILES['attachment'], 'attachment');
                $fileUrl = $storedAttachment['url'];
                $fileType = $storedAttachment['extension'];
            }
            $status = (string)($_POST['status'] ?? 'draft');
            $publishedAtInput = trim((string)($_POST['published_at'] ?? ''));

            if ($title === '') {
                throw new RuntimeException('Note title is required.');
            }

            if (!in_array($status, $allowedStatuses, true)) {
                throw new RuntimeException('Invalid Note status.');
            }

            if (!in_array($fileType, $allowedFileTypes, true)) {
                throw new RuntimeException('Invalid file type.');
            }

            if (
                $fileUrl !== '' &&
                !filter_var($fileUrl, FILTER_VALIDATE_URL) &&
                !preg_match('#^uploads/notes/(files|images)/[a-f0-9]{32}\.(pdf|doc|docx|jpg|jpeg|png|webp|gif)$#i', $fileUrl)
            ) {
                throw new RuntimeException('Please enter a valid HTTP(S) URL or upload a supported file.');
            }

            $publishedAt = null;

            if ($publishedAtInput !== '') {
                $timestamp = strtotime($publishedAtInput);

                if ($timestamp === false) {
                    throw new RuntimeException('Invalid publication date.');
                }

                $publishedAt = date('Y-m-d H:i:s', $timestamp);
            }

            if ($status === 'published' && $publishedAt === null) {
                $publishedAt = date('Y-m-d H:i:s');
            }

            $categoryValue = $categoryId > 0 ? $categoryId : null;
            $summaryValue = $summary !== '' ? $summary : null;
            $contentValue = $content !== '' ? $content : null;
            $fileUrlValue = $fileUrl !== '' ? $fileUrl : null;

            if ($noteId > 0) {
                $stmt = $pdo->prepare("
                    UPDATE notes
                    SET category_id = ?,
                        title = ?,
                        summary = ?,
                        content = ?,
                        file_url = ?,
                        file_type = ?,
                        status = ?,
                        published_at = ?
                    WHERE id = ?
                ");

                $stmt->execute([
                    $categoryValue,
                    $title,
                    $summaryValue,
                    $contentValue,
                    $fileUrlValue,
                    $fileType,
                    $status,
                    $publishedAt,
                    $noteId
                ]);

            } else {
                $stmt = $pdo->prepare("
                    INSERT INTO notes (
                        category_id,
                        title,
                        summary,
                        content,
                        file_url,
                        file_type,
                        status,
                        published_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ");

                $stmt->execute([
                    $categoryValue,
                    $title,
                    $summaryValue,
                    $contentValue,
                    $fileUrlValue,
                    $fileType,
                    $status,
                    $publishedAt
                ]);
            }

            header('Location: notes.php?saved=1');
            exit;
        }

        throw new RuntimeException('Unknown action.');

    } catch (Throwable $e) {
        if (($_POST['action'] ?? '') === 'upload_inline_image') {
            http_response_code(400);
            header('Content-Type: application/json; charset=utf-8');
            echo json_encode(['success' => false, 'message' => $e->getMessage()]);
            exit;
        }
        $error = $e->getMessage();
    }
}

/*
|--------------------------------------------------------------------------
| Edit mode
|--------------------------------------------------------------------------
*/

$editId = isset($_GET['edit']) ? (int)$_GET['edit'] : 0;
$editingNote = null;

if ($editId > 0) {
    $stmt = $pdo->prepare("SELECT * FROM notes WHERE id = ? LIMIT 1");
    $stmt->execute([$editId]);
    $editingNote = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$editingNote) {
        $error = 'The requested Note was not found.';
        $editId = 0;
    }
}

/*
|--------------------------------------------------------------------------
| Search and filter
|--------------------------------------------------------------------------
*/

$search = trim((string)($_GET['search'] ?? ''));
$statusFilter = (string)($_GET['status'] ?? '');
$categoryFilter = (int)($_GET['category'] ?? 0);

$where = [];
$params = [];

if ($search !== '') {
    $where[] = "(n.title LIKE ? OR n.summary LIKE ? OR n.content LIKE ?)";
    $searchTerm = '%' . $search . '%';
    $params[] = $searchTerm;
    $params[] = $searchTerm;
    $params[] = $searchTerm;
}

if (in_array($statusFilter, $allowedStatuses, true)) {
    $where[] = "n.status = ?";
    $params[] = $statusFilter;
}

if ($categoryFilter > 0) {
    $where[] = "n.category_id = ?";
    $params[] = $categoryFilter;
}

$sql = "
    SELECT
        n.*,
        c.name AS category_name
    FROM notes n
    LEFT JOIN categories c ON c.id = n.category_id
";

if ($where) {
    $sql .= " WHERE " . implode(' AND ', $where);
}

$perPage = 20;
$currentPage = max(1, (int)($_GET['page'] ?? 1));
$countSql = "SELECT COUNT(*) FROM notes n LEFT JOIN categories c ON c.id = n.category_id";
if ($where) $countSql .= " WHERE " . implode(' AND ', $where);
$countStmt = $pdo->prepare($countSql);
$countStmt->execute($params);
$totalFilteredNotes = (int)$countStmt->fetchColumn();
$totalPages = max(1, (int)ceil($totalFilteredNotes / $perPage));
$currentPage = min($currentPage, $totalPages);
$offset = ($currentPage - 1) * $perPage;
$sql .= " ORDER BY n.id DESC LIMIT " . (int)$perPage . " OFFSET " . (int)$offset;
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$notes = $stmt->fetchAll(PDO::FETCH_ASSOC);

/*
|--------------------------------------------------------------------------
| Dashboard counts
|--------------------------------------------------------------------------
*/

$counts = [
    'total' => 0,
    'published' => 0,
    'draft' => 0,
    'archived' => 0
];

try {
    $countStmt = $pdo->query("
        SELECT
            COUNT(*) AS total,
            SUM(status = 'published') AS published,
            SUM(status = 'draft') AS draft,
            SUM(status = 'archived') AS archived
        FROM notes
    ");

    $countData = $countStmt->fetch(PDO::FETCH_ASSOC);

    if ($countData) {
        foreach ($counts as $key => $value) {
            $counts[$key] = (int)($countData[$key] ?? 0);
        }
    }
} catch (PDOException $e) {
    // The note list remains available if statistics cannot be loaded.
}

/*
|--------------------------------------------------------------------------
| Messages
|--------------------------------------------------------------------------
*/

if (isset($_GET['saved'])) {
    $message = 'Note successfully saved.';
}

if (isset($_GET['deleted'])) {
    $message = 'Note successfully deleted.';
}

/*
|--------------------------------------------------------------------------
| Form values
|--------------------------------------------------------------------------
*/

$formTitle = $editingNote['title'] ?? '';
$formSummary = $editingNote['summary'] ?? '';
$formContent = $editingNote['content'] ?? '';
$formFileUrl = $editingNote['file_url'] ?? '';
$formCategory = $editingNote['category_id'] ?? '';
$formFileType = $editingNote['file_type'] ?? 'none';
$formStatus = $editingNote['status'] ?? 'draft';
$formPublishedAt = notesDateInput($editingNote['published_at'] ?? null);

?>

<!DOCTYPE html>
<html lang="bn">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Notes Management - Fire Safety BD</title>


<style>
* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: #f5f5f7;
    color: #252525;
    font-family: Arial, Helvetica, sans-serif;
}

.topbar {
    background: #58101d;
    color: white;
    padding: 15px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 15px;
    flex-wrap: wrap;
}

.brand {
    display: flex;
    align-items: center;
    gap: 12px;
    color: white;
    text-decoration: none;
    cursor: pointer;
}

.brand:hover {
    opacity: .9;
}

.brand-logo {
    width: 48px;
    height: 48px;
    object-fit: contain;
    border-radius: 9px;
    background: white;
    padding: 3px;
}

.brand-name {
    font-size: 20px;
    font-weight: bold;
}

.brand-subtitle {
    font-size: 12px;
    color: #f3dce1;
    margin-top: 4px;
}

.nav-links {
    display: flex;
    align-items: center;
    gap: 9px;
    flex-wrap: wrap;
}

.nav-links a {
    color: white;
    text-decoration: none;
    padding: 9px 13px;
    border-radius: 6px;
    font-size: 14px;
}

.nav-links a:hover {
    background: #7b2636;
}

.container {
    max-width: 1250px;
    margin: 25px auto;
    padding: 0 18px;
}

.page-title {
    margin: 0 0 7px;
    color: #58101d;
    font-size: 25px;
}

.page-subtitle {
    color: #777;
    margin: 0 0 22px;
    font-size: 14px;
}

.stats {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
    margin-bottom: 22px;
}

.stat-card {
    background: white;
    border-radius: 9px;
    padding: 17px;
    box-shadow: 0 2px 10px rgba(0,0,0,.04);
    border-left: 4px solid #e87524;
}

.stat-label {
    color: #777;
    font-size: 13px;
}

.stat-number {
    color: #58101d;
    font-size: 25px;
    font-weight: bold;
    margin-top: 7px;
}

.card {
    background: white;
    border-radius: 10px;
    padding: 22px;
    margin-bottom: 22px;
    box-shadow: 0 2px 10px rgba(0,0,0,.05);
}

.card h2 {
    color: #58101d;
    font-size: 19px;
    margin: 0 0 18px;
}

.form-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
}

.form-group {
    margin-bottom: 14px;
}

.form-group.full {
    grid-column: 1 / -1;
}

label {
    display: block;
    font-size: 13px;
    font-weight: bold;
    margin-bottom: 7px;
}

input,
select,
textarea {
    width: 100%;
    padding: 11px 12px;
    border: 1px solid #d9d9df;
    border-radius: 6px;
    font-size: 14px;
    background: white;
}

textarea {
    min-height: 110px;
    resize: vertical;
}

.content-area {
    min-height: 220px;
}

.editor-help {
    display: block;
    margin-top: 7px;
    color: #777;
    font-size: 12px;
}
.preview-button {
    border: 1px solid #f1ddd6;
    background: #fff8f5;
    color: #791623;
    border-radius: 10px;
    padding: 8px 11px;
    font-weight: 800;
    cursor: pointer;
}
.note-preview-backdrop {
    position: fixed;
    inset: 0;
    z-index: 9999;
    display: none;
    align-items: center;
    justify-content: center;
    padding: 18px;
    background: rgba(35, 12, 16, .65);
}
.note-preview-backdrop.open { display: flex; }
.note-preview-dialog {
    width: min(900px, 100%);
    max-height: 90vh;
    overflow: auto;
    background: #fff;
    border-radius: 18px;
    padding: 24px;
    box-shadow: 0 20px 60px rgba(0,0,0,.25);
}
.note-preview-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    border-bottom: 1px solid #f1ddd6;
    padding-bottom: 14px;
    margin-bottom: 18px;
}
.note-preview-header h2 { margin: 0; color: #510d18; }
.note-preview-close {
    border: 0;
    border-radius: 10px;
    background: #f1e5e7;
    color: #510d18;
    padding: 8px 12px;
    cursor: pointer;
    font-weight: 800;
}
.note-preview-summary { color: #806d6d; margin-bottom: 18px; line-height: 1.6; }
.note-preview-content { line-height: 1.75; overflow-wrap: anywhere; }
.note-preview-content img { max-width: 100%; height: auto; border-radius: 8px; }
.note-preview-content table { width: 100%; min-width: 0; border-collapse: collapse; }
.note-preview-content th, .note-preview-content td { border: 1px solid #e7d7d2; padding: 8px; }
@media(max-width:600px) { .note-preview-dialog { padding: 16px; } }

input:focus,
select:focus,
textarea:focus {
    outline: none;
    border-color: #9b354b;
    box-shadow: 0 0 0 2px rgba(155,53,75,.1);
}

.btn {
    display: inline-block;
    border: 0;
    border-radius: 6px;
    padding: 11px 17px;
    background: #e87524;
    color: white;
    text-decoration: none;
    cursor: pointer;
    font-size: 14px;
    font-weight: bold;
}

.btn:hover {
    background: #cf5f13;
}

.btn-secondary {
    background: #58101d;
}

.btn-secondary:hover {
    background: #761c2d;
}

.btn-light {
    background: #eeeeef;
    color: #333;
}

.btn-light:hover {
    background: #dedee0;
}

.btn-danger {
    background: #b42332;
}

.btn-danger:hover {
    background: #8d1724;
}

.actions {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 17px;
}

.alert {
    padding: 12px 15px;
    border-radius: 7px;
    margin-bottom: 18px;
    font-size: 14px;
}

.success {
    color: #155724;
    background: #d4edda;
}

.danger {
    color: #721c24;
    background: #f8d7da;
}

.filters {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr auto;
    gap: 10px;
    margin-bottom: 17px;
}

.table-wrap {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
    min-width: 850px;
}

th,
td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #eeeeef;
    font-size: 13px;
    vertical-align: middle;
}

th {
    background: #faf5f6;
    color: #58101d;
}

.status {
    display: inline-block;
    border-radius: 20px;
    padding: 5px 10px;
    font-size: 11px;
    font-weight: bold;
    text-transform: capitalize;
}

.status-published {
    background: #d4edda;
    color: #155724;
}

.status-draft {
    background: #fff3cd;
    color: #856404;
}

.status-archived {
    background: #e2e3e5;
    color: #383d41;
}

.edit-link {
    color: #a34216;
    font-weight: bold;
    text-decoration: none;
}

.edit-link:hover {
    text-decoration: underline;
}

.delete-form {
    display: inline;
}

.delete-button {
    border: 0;
    background: none;
    color: #b42332;
    cursor: pointer;
    font-weight: bold;
    font-size: 13px;
    padding: 5px;
}

.delete-button:hover {
    text-decoration: underline;
}

.file-link {
    color: #8b3344;
    text-decoration: none;
}

.file-link:hover {
    text-decoration: underline;
}

.empty {
    color: #888;
    padding: 18px;
    text-align: center;
}

.note-title {
    font-weight: bold;
    color: #58101d;
}

.note-summary {
    color: #777;
    margin-top: 5px;
    max-width: 300px;
    line-height: 1.4;
}

@media (max-width: 800px) {
    .stats {
        grid-template-columns: repeat(2, 1fr);
    }

    .filters {
        grid-template-columns: 1fr 1fr;
    }
}

@media (max-width: 600px) {
    .topbar {
        padding: 13px;
    }

    .brand-name {
        font-size: 17px;
    }

    .brand-logo {
        width: 42px;
        height: 42px;
    }

    .nav-links {
        width: 100%;
    }

    .nav-links a {
        padding: 8px 10px;
        font-size: 12px;
    }

    .container {
        margin: 18px auto;
        padding: 0 12px;
    }

    .card {
        padding: 15px;
    }

    .form-grid {
        grid-template-columns: 1fr;
    }

    .form-group.full {
        grid-column: auto;
    }

    .filters {
        grid-template-columns: 1fr;
    }
}

/* Dashboard-matched Notes page */
body{background:#fff8f5;color:#30191b;font-family:Arial,"Noto Sans Bengali","SolaimanLipi",sans-serif}.app{min-height:100vh;display:flex}.sidebar{width:280px;flex:0 0 280px;background:linear-gradient(180deg,#450b15,#6a111f);color:#f9e9e7;padding:24px 16px;min-height:100vh}.brand{display:flex;align-items:center;gap:13px;padding:4px 9px 26px}.brand a{color:inherit;text-decoration:none!important}.logo{width:65px;height:65px;border:2px solid white;border-radius:13px;background:#510d18;object-fit:contain;display:block}.brand-name{font-size:20px;font-weight:800;color:white}.brand-sub{font-size:14px;color:#e0bfc2;margin-top:5px}.nav{display:grid;gap:5px}.nav a{display:flex;align-items:center;gap:13px;padding:13px 15px;border-radius:14px;font-size:16px;color:#f4dfe0;text-decoration:none}.nav a:hover{background:#ffffff12}.nav a.active{background:#ffa400;color:#29170b;font-weight:800}.nav .ico{width:22px;text-align:center;font-size:20px}.nav a.logout{margin-top:15px;border:1px solid #ffffff40;color:#ffd6d6}.main{flex:1;min-width:0;padding:32px}.topbar{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:28px;background:transparent;color:inherit;padding:0;box-shadow:none}.topline{display:flex;align-items:center;gap:12px}.page-title{font-size:32px;font-weight:900;margin:0 0 8px;color:#30191b}.subtitle{color:#8b7777;font-size:16px}.top-actions{display:flex;align-items:center;gap:14px}.stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px;margin-bottom:24px}.stat-card{background:white;border:1px solid #f1ddd6;border-radius:22px;padding:22px 20px;min-height:125px;box-shadow:none}.stat-label{color:#8b7777;font-size:15px}.stat-number{font-size:35px;font-weight:900;color:#781523;margin:16px 0 0}.card{background:white;border:1px solid #f1ddd6;border-radius:22px;padding:22px;margin-bottom:22px;box-shadow:none}.card h2{font-size:21px;font-weight:900;margin:0 0 19px;color:#510d18}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.form-group{margin:0;min-width:0}.form-group label{font-size:14px;color:#30191b;margin-bottom:7px}.form-group input,.form-group select,.form-group textarea{width:100%;min-height:48px;border:1px solid #f1ddd6;border-radius:12px;padding:12px 14px;font:inherit;background:#fff;color:#30191b}.form-group textarea{min-height:110px}.content-area{min-height:240px}.btn{display:inline-flex;align-items:center;justify-content:center;border:0;border-radius:14px;padding:13px 20px;background:#ffa400;color:#29170b;text-decoration:none;cursor:pointer;font:inherit;font-weight:800;white-space:nowrap}.btn-secondary{background:#510d18;color:#fff}.btn-light{background:#f1e5e7;color:#510d18}.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.alert{padding:13px 16px;border-radius:13px;margin:0 0 18px}.alert.success{color:#176b3b;background:#e1f4e8}.alert.danger{color:#8b2323;background:#ffe8e8}.filters{display:grid;grid-template-columns:minmax(180px,2fr) minmax(140px,1fr) minmax(140px,1fr) auto;gap:10px;margin-bottom:18px}.filters input,.filters select{width:100%;min-width:0;min-height:48px;border:1px solid #f1ddd6;border-radius:12px;padding:11px 13px;font:inherit;background:#fff}.table-wrap{overflow-x:auto;border:1px solid #f1e7e3;border-radius:14px}table{width:100%;border-collapse:collapse;min-width:850px}th,td{padding:14px 12px;text-align:left;border-bottom:1px solid #f5e7e2;font-size:13px;vertical-align:middle}th{background:#fff8f5;color:#510d18;font-weight:800;white-space:nowrap}.status{display:inline-block;border-radius:999px;padding:6px 11px;font-size:12px;font-weight:800}.status-published{background:#e1f4e8;color:#176b3b}.status-draft{background:#fff1d4;color:#88540a}.status-archived{background:#f1e9e9;color:#775d5d}.edit-link{display:inline-flex;color:#791623;font-weight:800;text-decoration:none;border:1px solid #f1ddd6;border-radius:10px;padding:8px 11px}.delete-button{border:0;background:#fff0f0;color:#a51f32;border-radius:10px;padding:9px 11px;font-weight:800}.notes-pagination{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-top:18px;color:#8b7777;font-size:13px}.notes-page-actions{display:flex;gap:8px}.notes-page-actions a,.notes-page-actions .disabled{padding:9px 13px;border:1px solid #f1ddd6;border-radius:10px;color:#791623;text-decoration:none;font-weight:800;background:white}.notes-page-actions .disabled{opacity:.45}.mobile-toggle{display:none;background:#510d18;color:white;border:0;border-radius:10px;padding:9px 12px;font-size:20px}
@media(max-width:1250px){.sidebar{width:245px;flex-basis:245px}.main{padding:24px}.stats{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:900px){.topbar{align-items:flex-start;flex-direction:column}}@media(max-width:640px){.app{display:block}.sidebar{display:none;width:100%;min-height:auto;padding:14px}.sidebar.open{display:block}.brand{padding-bottom:12px}.nav{grid-template-columns:repeat(2,minmax(0,1fr))}.nav a{font-size:14px;padding:10px}.main{padding:18px 14px 28px}.mobile-toggle{display:inline-block}.page-title{font-size:27px}.top-actions,.top-actions .btn{width:100%}.stats{gap:10px}.stat-card{padding:15px 13px;min-height:110px}.stat-number{font-size:28px}.card{padding:15px}.form-grid,.filters{grid-template-columns:1fr}.notes-pagination{align-items:flex-start;flex-direction:column}}

</style>
</head>

<body>

<div class="app"><aside class="sidebar" id="notesSidebar">
<div class="brand"><a href="admin/fire_safety_job_prep_dashboard.php"><img src="assets/fire-safety-bd-logo.png" alt="Fire Safety BD Logo" class="logo"></a><div><a href="admin/fire_safety_job_prep_dashboard.php"><div class="brand-name">Fire Safety BD</div><div class="brand-sub">অ্যাডমিন প্যানেল</div></a></div></div>
<nav class="nav" aria-label="Admin navigation">
<a href="admin/fire_safety_job_prep_dashboard.php"><span class="ico">▦</span> ড্যাশবোর্ড</a><a href="questions.php"><span class="ico">ⓘ</span> প্রশ্ন ব্যাংক</a><a href="model_tests.php"><span class="ico">☑</span> মডেল টেস্ট</a><a class="active" href="notes.php" aria-current="page"><span class="ico">◫</span> নোট</a><a href="job_circulars.php"><span class="ico">▣</span> চাকরির সার্কুলার</a><a href="admin/fire_safety_job_prep_dashboard.php?section=marketplace"><span class="ico">🛒</span> মার্কেটপ্লেস</a><a href="category_management.php"><span class="ico">⊞</span> ক্যাটাগরি</a><a href="admin/fire_safety_job_prep_dashboard.php?section=community"><span class="ico">▱</span> কমিউনিটি</a><a href="logout.php" class="logout"><span class="ico">↪</span> লগ আউট</a>
</nav></aside><main class="main"><div class="topbar"><div class="topline"><button class="mobile-toggle" type="button" onclick="document.getElementById('notesSidebar').classList.toggle('open')" aria-label="মেনু">☰</button><div><h1 class="page-title">নোট ব্যবস্থাপনা</h1><div class="subtitle">শিক্ষামূলক নোট তৈরি, সম্পাদনা ও প্রকাশ ব্যবস্থাপনা</div></div></div><div class="top-actions"><a class="btn" href="#noteEditor">＋ নতুন নোট তৈরি</a></div></div>

    <?php if ($message): ?>
        <div class="alert success"><?= nh($message) ?></div>
    <?php endif; ?>

    <?php if ($error): ?>
        <div class="alert danger"><?= nh($error) ?></div>
    <?php endif; ?>

    <section class="stats">

        <div class="stat-card">
            <div class="stat-label">Total Notes</div>
            <div class="stat-number"><?= $counts['total'] ?></div>
        </div>

        <div class="stat-card">
            <div class="stat-label">Published</div>
            <div class="stat-number"><?= $counts['published'] ?></div>
        </div>

        <div class="stat-card">
            <div class="stat-label">Draft</div>
            <div class="stat-number"><?= $counts['draft'] ?></div>
        </div>

        <div class="stat-card">
            <div class="stat-label">Archived</div>
            <div class="stat-number"><?= $counts['archived'] ?></div>
        </div>

    </section>

    <section class="card panel" id="noteEditor"><h2><?= $editingNote ? 'নোট সম্পাদনা' : 'নতুন নোট তৈরি' ?></h2>

        <form method="POST" enctype="multipart/form-data" action="notes.php<?= $editingNote ? '?edit=' . (int)$editingNote['id'] : '' ?>">

            <input type="hidden" name="action" value="save">
            <input type="hidden" name="csrf_token" value="<?= nh($_SESSION['notes_csrf_token']) ?>">
            <input type="hidden" name="note_id" value="<?= (int)($editingNote['id'] ?? 0) ?>">

            <div class="form-grid">

                <div class="form-group">
                    <label>Note Title *</label>
                    <input
                        type="text"
                        name="title"
                        required
                        maxlength="255"
                        value="<?= nh($formTitle) ?>"
                        placeholder="Enter note title"
                    >
                </div>

                <div class="form-group">
                    <label>Category</label>

                    <select name="category_id">
                        <option value="">Select Category</option>

                        <?php foreach ($categories as $category): ?>
                            <option
                                value="<?= (int)$category['id'] ?>"
                                <?= (string)$formCategory === (string)$category['id'] ? 'selected' : '' ?>
                            >
                                <?= nh($category['name']) ?>
                            </option>
                        <?php endforeach; ?>

                    </select>
                </div>

                <div class="form-group full">
                    <label>Short Summary</label>
                    <textarea
                        name="summary"
                        placeholder="Write a short summary..."
                    ><?= nh($formSummary) ?></textarea>
                </div>

                <div class="form-group full">
                    <label>Note Content</label>
                    <textarea name="content" id="notes-content" class="content-area"><?= nh($formContent) ?></textarea>
                    <small class="editor-help">Format text, add links, tables and images. Inline images: maximum 5 MB.</small>
                </div>

                <div class="form-group">
                    <label>Upload PDF / DOC / DOCX (maximum 15 MB)</label>
                    <input type="file" name="attachment" accept=".pdf,.doc,.docx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document">
                    <?php if (!empty($formFileUrl)): ?>
                        <small class="editor-help">Current file: <a href="<?= nh($formFileUrl) ?>" target="_blank" rel="noopener noreferrer">Open attachment</a>. Choose a new file to replace it, or leave empty to keep the current file.</small>
                    <?php endif; ?>
                </div>

                <div class="form-group">
                    <label>Or use an external File URL</label>
                    <input
                        type="url"
                        name="file_url"
                        value="<?= nh($formFileUrl) ?>"
                        placeholder="https://example.com/file.pdf"
                    >
                </div>

                <div class="form-group">
                    <label>File Type</label>

                    <select name="file_type">
                        <option value="none" <?= $formFileType === 'none' ? 'selected' : '' ?>>No File</option>
                        <option value="pdf" <?= $formFileType === 'pdf' ? 'selected' : '' ?>>PDF</option>
                        <option value="doc" <?= $formFileType === 'doc' ? 'selected' : '' ?>>DOC</option>
                        <option value="docx" <?= $formFileType === 'docx' ? 'selected' : '' ?>>DOCX</option>
                        <option value="other" <?= $formFileType === 'other' ? 'selected' : '' ?>>Other</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>Status</label>

                    <select name="status">
                        <option value="draft" <?= $formStatus === 'draft' ? 'selected' : '' ?>>Draft</option>
                        <option value="published" <?= $formStatus === 'published' ? 'selected' : '' ?>>Published</option>
                        <option value="archived" <?= $formStatus === 'archived' ? 'selected' : '' ?>>Archived</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>Published Date & Time</label>
                    <input
                        type="datetime-local"
                        name="published_at"
                        value="<?= nh($formPublishedAt) ?>"
                    >
                </div>

            </div>

            <div class="actions">

                <button type="submit" class="btn">
                    <?= $editingNote ? 'Update Note' : 'Save Note' ?>
                </button>

                <?php if ($editingNote): ?>
                    <a href="notes.php" class="btn btn-light">Cancel Edit</a>
                <?php endif; ?>

            </div>

        </form>

    </section>

    <section class="card panel"><h2>সকল নোট</h2>

        <form method="GET" action="notes.php" class="filters">

            <input
                type="text"
                name="search"
                value="<?= nh($search) ?>"
                placeholder="Search title, summary or content..."
            >

            <select name="category">
                <option value="">All Categories</option>

                <?php foreach ($categories as $category): ?>
                    <option
                        value="<?= (int)$category['id'] ?>"
                        <?= $categoryFilter === (int)$category['id'] ? 'selected' : '' ?>
                    >
                        <?= nh($category['name']) ?>
                    </option>
                <?php endforeach; ?>

            </select>

            <select name="status">
                <option value="">All Statuses</option>
                <option value="draft" <?= $statusFilter === 'draft' ? 'selected' : '' ?>>Draft</option>
                <option value="published" <?= $statusFilter === 'published' ? 'selected' : '' ?>>Published</option>
                <option value="archived" <?= $statusFilter === 'archived' ? 'selected' : '' ?>>Archived</option>
            </select>

            <button type="submit" class="btn btn-secondary">Search</button>

        </form>

        <div class="table-wrap">

            <table>

                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Note Details</th>
                        <th>Category</th>
                        <th>File</th>
                        <th>Status</th>
                        <th>Published Date</th>
                        <th>Actions</th>
                    </tr>
                </thead>

                <tbody>

                    <?php if (!$notes): ?>

                        <tr>
                            <td colspan="7" class="empty">
                                No notes found.
                            </td>
                        </tr>

                    <?php else: ?>

                        <?php foreach ($notes as $note): ?>

                            <tr>

                                <td><?= (int)$note['id'] ?></td>

                                <td>
                                    <div class="note-title">
                                        <?= nh($note['title']) ?>
                                    </div>

                                    <?php if (!empty($note['summary'])): ?>
                                        <div class="note-summary">
                                            <?= nh(mb_substr($note['summary'], 0, 130)) ?>
                                            <?= mb_strlen($note['summary']) > 130 ? '...' : '' ?>
                                        </div>
                                    <?php endif; ?>
                                </td>

                                <td>
                                    <?= nh($note['category_name'] ?? '—') ?>
                                </td>

                                <td>
                                    <?php if (!empty($note['file_url'])): ?>
                                        <a
                                            href="<?= nh($note['file_url']) ?>"
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            class="file-link"
                                        >
                                            <?= nh(strtoupper($note['file_type'])) ?> View
                                        </a>
                                    <?php else: ?>
                                        —
                                    <?php endif; ?>
                                </td>

                                <td>
                                    <span class="status status-<?= nh($note['status']) ?>">
                                        <?= nh($note['status']) ?>
                                    </span>
                                </td>

                                <td>
                                    <?= $note['published_at']
                                        ? nh(date('d M Y, h:i A', strtotime($note['published_at'])))
                                        : '—'
                                    ?>
                                </td>

                                <td>
                                    <button
                                        type="button"
                                        class="preview-button"
                                        data-title="<?= nh($note['title']) ?>"
                                        data-summary="<?= nh($note['summary'] ?? '') ?>"
                                        data-content="<?= nh(base64_encode(notesSanitizeHtml((string)($note['content'] ?? '')))) ?>"
                                    >Preview</button>
                                    <a
                                        href="notes.php?edit=<?= (int)$note['id'] ?>"
                                        class="edit-link"
                                    >
                                        Edit
                                    </a>

                                    <form
                                        method="POST"
                                        action="notes.php"
                                        class="delete-form"
                                        onsubmit="return confirm('Are you sure you want to delete this note?');"
                                    >
                                        <input type="hidden" name="action" value="delete">
                                        <input type="hidden" name="csrf_token" value="<?= nh($_SESSION['notes_csrf_token']) ?>">
                                        <input type="hidden" name="note_id" value="<?= (int)$note['id'] ?>">

                                        <button type="submit" class="delete-button">
                                            Delete
                                        </button>
                                    </form>
                                </td>

                            </tr>

                        <?php endforeach; ?>

                    <?php endif; ?>

                </tbody>

            </table>

</div>
<div class="notes-pagination"><span>মোট <?= (int)$totalFilteredNotes ?>টি নোট · পৃষ্ঠা <?= (int)$currentPage ?> / <?= (int)$totalPages ?></span><div class="notes-page-actions"><?php $pageQuery=$_GET; $pageQuery['page']=max(1,$currentPage-1); ?><?php if($currentPage>1): ?><a href="notes.php?<?= nh(http_build_query($pageQuery)) ?>">← আগের</a><?php else: ?><span class="disabled">← আগের</span><?php endif; ?><?php $pageQuery['page']=min($totalPages,$currentPage+1); ?><?php if($currentPage<$totalPages): ?><a href="notes.php?<?= nh(http_build_query($pageQuery)) ?>">পরের →</a><?php else: ?><span class="disabled">পরের →</span><?php endif; ?></div></div>
</section>
</main>
</div>

<div class="note-preview-backdrop" id="notePreviewModal" role="dialog" aria-modal="true" aria-labelledby="notePreviewTitle">
    <div class="note-preview-dialog">
        <div class="note-preview-header">
            <h2 id="notePreviewTitle">Note Preview</h2>
            <button type="button" class="note-preview-close" id="notePreviewClose">Close ✕</button>
        </div>
        <div class="note-preview-summary" id="notePreviewSummary"></div>
        <div class="note-preview-content" id="notePreviewContent"></div>
    </div>
</div>

<script src="https://cdn.tiny.cloud/1/no-api-key/tinymce/6/tinymce.min.js" referrerpolicy="origin"></script>
<script>
document.addEventListener('DOMContentLoaded', function () {
    const contentField = document.getElementById('notes-content');
    const form = contentField ? contentField.closest('form') : null;
    if (!contentField || !form || typeof tinymce === 'undefined') return;

    tinymce.init({
        selector: '#notes-content',
        height: 420,
        menubar: 'edit view insert format table',
        plugins: 'lists link image table code wordcount',
        toolbar: 'undo redo | blocks | bold italic underline | forecolor backcolor | alignleft aligncenter alignright | bullist numlist | link image table | removeformat | code',
        branding: false,
        promotion: false,
        convert_urls: false,
        images_upload_handler: function (blobInfo) {
            return new Promise(function (resolve, reject) {
                const data = new FormData();
                data.append('action', 'upload_inline_image');
                data.append('csrf_token', form.querySelector('[name="csrf_token"]').value);
                data.append('inline_image', blobInfo.blob(), blobInfo.filename());
                fetch('notes.php', { method: 'POST', body: data, credentials: 'same-origin' })
                    .then(function (response) {
                        return response.json().then(function (result) {
                            if (!response.ok || !result.success) throw new Error(result.message || 'Image upload failed.');
                            resolve(result.url);
                        });
                    })
                    .catch(function (error) { reject(error.message || 'Image upload failed.'); });
            });
        },
        setup: function (editor) {
            editor.on('change input undo redo', function () { editor.save(); });
        }
    });

    form.addEventListener('submit', function () {
        tinymce.triggerSave();
    });
});
</script>

<script>
(function () {
    const modal = document.getElementById('notePreviewModal');
    const title = document.getElementById('notePreviewTitle');
    const summary = document.getElementById('notePreviewSummary');
    const content = document.getElementById('notePreviewContent');
    const close = document.getElementById('notePreviewClose');
    if (!modal || !title || !summary || !content || !close) return;

    function closePreview() {
        modal.classList.remove('open');
        content.innerHTML = '';
    }

    document.querySelectorAll('.preview-button').forEach(function (button) {
        button.addEventListener('click', function () {
            title.textContent = button.dataset.title || 'Untitled note';
            summary.textContent = button.dataset.summary || '';
            try {
                const binary = atob(button.dataset.content || '');
                const bytes = Uint8Array.from(binary, function (char) { return char.charCodeAt(0); });
                const html = new TextDecoder('utf-8').decode(bytes);
                content.innerHTML = html;
            } catch (error) {
                content.textContent = 'Preview could not be loaded.';
            }
            modal.classList.add('open');
            close.focus();
        });
    });

    close.addEventListener('click', closePreview);
    modal.addEventListener('click', function (event) {
        if (event.target === modal) closePreview();
    });
    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && modal.classList.contains('open')) closePreview();
    });
})();
</script>
</body>
</html></body>
</html>
