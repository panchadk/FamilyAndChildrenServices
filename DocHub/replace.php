<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: dashboard.php');
    exit;
}
require_csrf();

$id = (int)($_POST['id'] ?? 0);
$stmt = db()->prepare('SELECT * FROM documents WHERE id = ?');
$stmt->execute([$id]);
$doc = $stmt->fetch();

if (!$doc || !folder_access((int)$doc['folder_id'], $user)['edit']) {
    http_response_code(403);
    exit('You don\'t have edit access to this document.');
}

if (empty($_FILES['file']['name']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK
    || !is_uploaded_file($_FILES['file']['tmp_name'])) {
    $_SESSION['flash'] = 'No file was received — try again.';
    header('Location: view.php?id=' . $id);
    exit;
}

$tmp  = $_FILES['file']['tmp_name'];
$size = (int)$_FILES['file']['size'];
$orig = $_FILES['file']['name'];

if ($size > MAX_UPLOAD_BYTES || $size === 0) {
    $_SESSION['flash'] = 'File is too large (50 MB max) or empty.';
    header('Location: view.php?id=' . $id);
    exit;
}

// New version must keep the same file type as the document
$ext = strtolower(pathinfo($orig, PATHINFO_EXTENSION));
if ($ext !== strtolower($doc['file_ext'])) {
    $_SESSION['flash'] = 'The new version must be a .' . $doc['file_ext']
                       . ' file to replace "' . $doc['display_name'] . '". To change the format, upload it as a new document instead.';
    header('Location: view.php?id=' . $id);
    exit;
}
if (!isset(ALLOWED_TYPES[$ext])) {
    $_SESSION['flash'] = 'That file type isn\'t allowed.';
    header('Location: view.php?id=' . $id);
    exit;
}

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime  = $finfo->file($tmp) ?: 'application/octet-stream';
$mimeOk = false;
foreach (ALLOWED_TYPES[$ext] as $allowed) {
    if (stripos($mime, $allowed) === 0) { $mimeOk = true; break; }
}
if (!$mimeOk && in_array($ext, ['docx','xlsx','pptx'], true)
    && in_array($mime, ['application/zip','application/octet-stream'], true)) {
    $mimeOk = true;
}
if (!$mimeOk) {
    $_SESSION['flash'] = 'The file\'s content doesn\'t match its type — replacement rejected.';
    header('Location: view.php?id=' . $id);
    exit;
}

$stored = bin2hex(random_bytes(20)) . '.' . $ext;
$dest   = rtrim(STORAGE_DIR, '/') . '/' . $stored;
if (!move_uploaded_file($tmp, $dest)) {
    $_SESSION['flash'] = 'The file could not be saved — try again.';
    header('Location: view.php?id=' . $id);
    exit;
}

$pdo = db();
$pdo->beginTransaction();
try {
    // current file → history
    $pdo->prepare(
        'INSERT INTO document_versions (document_id, stored_name, mime_type, file_ext, size_bytes, uploaded_by, created_at)
         VALUES (?,?,?,?,?,?,?)'
    )->execute([
        $doc['id'], $doc['stored_name'], $doc['mime_type'], $doc['file_ext'],
        $doc['size_bytes'], $doc['uploaded_by'], $doc['updated_at'],
    ]);
    // new file → current
    $pdo->prepare(
        'UPDATE documents SET stored_name=?, mime_type=?, size_bytes=?, uploaded_by=? WHERE id=?'
    )->execute([$stored, $mime, $size, $user['id'], $doc['id']]);
    $pdo->commit();
    log_activity($user['id'], 'replace_version', $doc['display_name']);
    $_SESSION['flash'] = 'New version of "' . $doc['display_name'] . '" uploaded — previous copy kept in history.';
} catch (Throwable $e) {
    $pdo->rollBack();
    @unlink($dest);
    $_SESSION['flash'] = 'Replacing failed — please try again.';
}
header('Location: view.php?id=' . $id);
exit;
