<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: dashboard.php');
    exit;
}
require_csrf();

$folderId = (int)($_POST['folder_id'] ?? 0);
$folder   = folder_meta($folderId);
if (!$folder || !folder_access($folderId, $user)['edit']) {
    http_response_code(403);
    exit('You don\'t have upload access to that folder.');
}

if (empty($_FILES['files']['name'][0])) {
    $_SESSION['flash'] = 'No files were selected.';
    header('Location: dashboard.php?folder=' . $folderId);
    exit;
}

$finfo    = new finfo(FILEINFO_MIME_TYPE);
$ok       = 0;
$versioned = 0;
$skipped  = [];
$okNames  = [];

foreach ($_FILES['files']['name'] as $i => $origName) {
    $tmp  = $_FILES['files']['tmp_name'][$i];
    $err  = $_FILES['files']['error'][$i];
    $size = (int)$_FILES['files']['size'][$i];

    if ($err !== UPLOAD_ERR_OK || !is_uploaded_file($tmp)) {
        $skipped[] = $origName . ' (upload error)';
        continue;
    }
    if ($size > MAX_UPLOAD_BYTES || $size === 0) {
        $skipped[] = $origName . ' (too large or empty)';
        continue;
    }

    $ext = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
    if (!isset(ALLOWED_TYPES[$ext])) {
        $skipped[] = $origName . ' (file type not allowed)';
        continue;
    }
    $mime = $finfo->file($tmp) ?: 'application/octet-stream';
    $mimeOk = false;
    foreach (ALLOWED_TYPES[$ext] as $allowed) {
        if (stripos($mime, $allowed) === 0) { $mimeOk = true; break; }
    }
    if (!$mimeOk && in_array($ext, ['docx','xlsx','pptx'], true)
        && in_array($mime, ['application/zip','application/octet-stream'], true)) {
        $mimeOk = true;
    }
    if (!$mimeOk) {
        $skipped[] = $origName . ' (content does not match file type)';
        continue;
    }

    $stored = bin2hex(random_bytes(20)) . '.' . $ext;
    $dest   = rtrim(STORAGE_DIR, '/') . '/' . $stored;
    if (!is_dir(STORAGE_DIR)) {
        mkdir(STORAGE_DIR, 0755, true);
    }
    if (!move_uploaded_file($tmp, $dest)) {
        $skipped[] = $origName . ' (could not save file)';
        continue;
    }

    $display = preg_replace('/[\\x00-\\x1F\\/\\\\]/u', '', basename($origName));
    $display = mb_substr($display, 0, 255);

    // ---------- versioning: same name in same folder = new version ----------
    $existing = db()->prepare('SELECT * FROM documents WHERE folder_id = ? AND display_name = ? LIMIT 1');
    $existing->execute([$folderId, $display]);
    $prev = $existing->fetch();

    if ($prev) {
        // archive the current file as a version, then update the record in place
        db()->prepare(
            'INSERT INTO document_versions (document_id, stored_name, mime_type, file_ext, size_bytes, uploaded_by, created_at)
             VALUES (?,?,?,?,?,?,?)'
        )->execute([
            $prev['id'], $prev['stored_name'], $prev['mime_type'], $prev['file_ext'],
            $prev['size_bytes'], $prev['uploaded_by'], $prev['updated_at'],
        ]);
        db()->prepare(
            'UPDATE documents SET stored_name=?, mime_type=?, file_ext=?, size_bytes=?, uploaded_by=? WHERE id=?'
        )->execute([$stored, $mime, $ext, $size, $user['id'], $prev['id']]);
        log_activity($user['id'], 'upload_version', $display);
        $versioned++;
    } else {
        db()->prepare(
            'INSERT INTO documents (folder_id, display_name, stored_name, mime_type, file_ext, size_bytes, uploaded_by)
             VALUES (?,?,?,?,?,?,?)'
        )->execute([$folderId, $display, $stored, $mime, $ext, $size, $user['id']]);
        log_activity($user['id'], 'upload', $display);
    }
    $ok++;
    $okNames[] = $display;
}

// ---------- notify opted-in users (best effort) ----------
if ($okNames) {
    notify_upload($folderId, $folder['name'], $okNames, $user);
}

$msg = $ok . ($ok === 1 ? ' file uploaded.' : ' files uploaded.');
if ($versioned) {
    $msg .= ' ' . $versioned . ($versioned === 1 ? ' replaced an existing file (old copy kept as a version).' : ' replaced existing files (old copies kept as versions).');
}
if ($skipped) {
    $msg .= ' Skipped: ' . implode('; ', array_slice($skipped, 0, 3));
    if (count($skipped) > 3) $msg .= ' and ' . (count($skipped) - 3) . ' more';
    $msg .= '.';
}
$_SESSION['flash'] = $msg;
header('Location: dashboard.php?folder=' . $folderId);
exit;
