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

// Remove version files from disk first
$vers = db()->prepare('SELECT stored_name FROM document_versions WHERE document_id = ?');
$vers->execute([$id]);
foreach ($vers->fetchAll() as $v) {
    $vp = rtrim(STORAGE_DIR, '/') . '/' . $v['stored_name'];
    if (basename($v['stored_name']) === $v['stored_name'] && is_file($vp)) {
        @unlink($vp);
    }
}

// Remove the current file
$path = rtrim(STORAGE_DIR, '/') . '/' . $doc['stored_name'];
if (basename($doc['stored_name']) === $doc['stored_name'] && is_file($path)) {
    @unlink($path);
}

// DB rows (document_versions cascades on FK)
db()->prepare('DELETE FROM documents WHERE id = ?')->execute([$id]);
log_activity($user['id'], 'delete', $doc['display_name']);
$_SESSION['flash'] = '"' . $doc['display_name'] . '" and its versions were deleted.';
header('Location: dashboard.php?folder=' . (int)$doc['folder_id']);
exit;
