<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: dashboard.php');
    exit;
}
require_csrf();

$ids = array_map('intval', (array)($_POST['ids'] ?? []));
$ids = array_values(array_filter(array_unique($ids)));

if (!$ids) {
    $_SESSION['flash'] = 'Select at least one document to download.';
    header('Location: dashboard.php');
    exit;
}
if (count($ids) > 200) {
    $_SESSION['flash'] = 'Bulk download is limited to 200 documents at a time.';
    header('Location: dashboard.php');
    exit;
}

$in = implode(',', array_fill(0, count($ids), '?'));
$stmt = db()->prepare(
    "SELECT d.*, f.name AS folder_name FROM documents d
       JOIN folders f ON f.id = d.folder_id
      WHERE d.id IN ($in)"
);
$stmt->execute($ids);
$docs = $stmt->fetchAll();

// Keep only documents the user may view; cap total size at 500 MB
$maxTotal = 500 * 1024 * 1024;
$total    = 0;
$allowed  = [];
foreach ($docs as $d) {
    if (!folder_access((int)$d['folder_id'], $user)['view']) continue;
    $total += (int)$d['size_bytes'];
    if ($total > $maxTotal) {
        $_SESSION['flash'] = 'Selection exceeds the 500 MB bulk-download limit — pick fewer files.';
        header('Location: dashboard.php');
        exit;
    }
    $allowed[] = $d;
}
if (!$allowed) {
    $_SESSION['flash'] = 'None of the selected documents are accessible.';
    header('Location: dashboard.php');
    exit;
}

if (!class_exists('ZipArchive')) {
    $_SESSION['flash'] = 'ZIP support is not enabled on the server (enable the "zip" PHP extension in cPanel → Select PHP Version).';
    header('Location: dashboard.php');
    exit;
}

$tmpZip = tempnam(sys_get_temp_dir(), 'dochub');
$zip = new ZipArchive();
if ($zip->open($tmpZip, ZipArchive::OVERWRITE) !== true) {
    $_SESSION['flash'] = 'Could not create the ZIP archive.';
    header('Location: dashboard.php');
    exit;
}

$added = 0;
$seen  = [];
foreach ($allowed as $d) {
    $path = rtrim(STORAGE_DIR, '/') . '/' . $d['stored_name'];
    if (basename($d['stored_name']) !== $d['stored_name'] || !is_file($path)) continue;

    // folder-name/display-name inside the zip; dedupe collisions
    $entry = preg_replace('/[\\x00-\\x1F]/u', '', $d['folder_name'] . '/' . $d['display_name']);
    $base  = $entry; $k = 1;
    while (isset($seen[$entry])) {
        $dot   = strrpos($base, '.');
        $entry = $dot === false ? $base . ' (' . ++$k . ')'
               : substr($base, 0, $dot) . ' (' . ++$k . ')' . substr($base, $dot);
    }
    $seen[$entry] = true;

    if ($zip->addFile($path, $entry)) {
        $added++;
    }
}
$zip->close();

if (!$added) {
    @unlink($tmpZip);
    $_SESSION['flash'] = 'No files could be added to the ZIP.';
    header('Location: dashboard.php');
    exit;
}

log_activity($user['id'], 'bulk_download', $added . ' file(s)');

$zipName = 'dochub-' . date('Ymd-Hi') . '.zip';
header('Content-Type: application/zip');
header('Content-Length: ' . filesize($tmpZip));
header('Content-Disposition: attachment; filename="' . $zipName . '"');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: private, max-age=0');
readfile($tmpZip);
@unlink($tmpZip);
exit;
