<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

$id  = (int)($_GET['id'] ?? 0);
$ver = (int)($_GET['ver'] ?? 0);   // optional: download an old version

$stmt = db()->prepare('SELECT * FROM documents WHERE id = ?');
$stmt->execute([$id]);
$doc = $stmt->fetch();

if (!$doc) {
    http_response_code(404);
    exit('Document not found.');
}
if (!folder_access((int)$doc['folder_id'], $user)['view']) {
    http_response_code(403);
    exit('You don\'t have access to this document.');
}

// Which physical file to serve
$storedName = $doc['stored_name'];
$mimeType   = $doc['mime_type'];
$fileName   = $doc['display_name'];

if ($ver > 0) {
    $vs = db()->prepare('SELECT * FROM document_versions WHERE id = ? AND document_id = ?');
    $vs->execute([$ver, $id]);
    $version = $vs->fetch();
    if (!$version) {
        http_response_code(404);
        exit('Version not found.');
    }
    $storedName = $version['stored_name'];
    $mimeType   = $version['mime_type'];
    $fileName   = pathinfo($doc['display_name'], PATHINFO_FILENAME)
                . ' (version ' . date('Y-m-d Hi', strtotime($version['created_at'])) . ').'
                . $version['file_ext'];
}

$path = rtrim(STORAGE_DIR, '/') . '/' . $storedName;
if (basename($storedName) !== $storedName || !is_file($path)) {
    http_response_code(404);
    exit('File is missing from storage.');
}

log_activity($user['id'], 'download', $fileName);

$inline = isset($_GET['view'])
       && (str_starts_with($mimeType, 'image/') || $mimeType === 'application/pdf');

$disposition = $inline ? 'inline' : 'attachment';
$safeName    = str_replace(['"', "\r", "\n"], '', $fileName);

header('Content-Type: ' . $mimeType);
header('Content-Length: ' . filesize($path));
header('Content-Disposition: ' . $disposition . '; filename="' . $safeName . '"');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: private, max-age=0');

readfile($path);
exit;
