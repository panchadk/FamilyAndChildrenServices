<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: dashboard.php');
    exit;
}
require_csrf();

$id   = (int)($_POST['id'] ?? 0);
$name = trim($_POST['new_name'] ?? '');
$name = preg_replace('/[\\x00-\\x1F\\/\\\\]/u', '', $name);
$name = mb_substr($name, 0, 255);

$stmt = db()->prepare('SELECT id, folder_id, display_name, file_ext FROM documents WHERE id = ?');
$stmt->execute([$id]);
$doc = $stmt->fetch();

if (!$doc || !folder_access((int)$doc['folder_id'], $user)['edit']) {
    http_response_code(403);
    exit('You don\'t have edit access to this document.');
}

if ($name !== '') {
    $ext = '.' . $doc['file_ext'];
    if (!str_ends_with(strtolower($name), strtolower($ext))) {
        $name .= $ext;
    }
    db()->prepare('UPDATE documents SET display_name = ? WHERE id = ?')->execute([$name, $id]);
    log_activity($user['id'], 'rename', $doc['display_name'] . ' → ' . $name);
    $_SESSION['flash'] = 'Renamed to "' . $name . '".';
} else {
    $_SESSION['flash'] = 'Rename didn\'t go through — check the new name and try again.';
}
header('Location: dashboard.php?folder=' . (int)$doc['folder_id']);
exit;
